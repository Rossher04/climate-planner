from django.contrib.auth import get_user_model
from rest_framework import generics, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView

from .authentication import EmailOrUsernameTokenObtainPairSerializer
from .models import Activity, ClimateRecord, Location, StatisticalSummary
from .serializers import (
    ActivitySerializer,
    ChangePasswordSerializer,
    ClimateRecordSerializer,
    LocationSerializer,
    PasswordRecoverySerializer,
    PasswordResetSerializer,
    RegisterSerializer,
    StatisticalSummarySerializer,
    UserSerializer,
)
from .services import (
    analyze_activity,
    complete_password_reset,
    fetch_current_weather,
    request_password_recovery,
)


User = get_user_model()


class EmailOrUsernameTokenObtainPairView(TokenObtainPairView):
    serializer_class = EmailOrUsernameTokenObtainPairSerializer


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]


class MeView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer

    def get_object(self):
        return self.request.user


class ChangePasswordView(generics.GenericAPIView):
    serializer_class = ChangePasswordSerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = request.user
        if not user.check_password(serializer.validated_data['old_password']):
            return Response(
                {'old_password': 'Contraseña incorrecta.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.set_password(serializer.validated_data['new_password'])
        user.save()

        if hasattr(user, 'profile'):
            user.profile.temporary_password_required = False
            user.profile.save()

        return Response({'success': True, 'message': 'Contraseña actualizada correctamente'})


class PasswordRecoveryView(generics.CreateAPIView):
    serializer_class = PasswordRecoverySerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        result = request_password_recovery(
            serializer.validated_data['email'],
            username=serializer.validated_data.get('username'),
        )

        if result['success']:
            return Response(result, status=status.HTTP_200_OK)
        else:
            return Response(result, status=status.HTTP_404_NOT_FOUND)


class PasswordResetView(generics.CreateAPIView):
    serializer_class = PasswordResetSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            user = User.objects.get(profile__password_reset_token=serializer.validated_data['token'])
        except User.DoesNotExist:
            return Response(
                {'error': 'Token inválido.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        result = complete_password_reset(
            user,
            serializer.validated_data['token'],
            serializer.validated_data['new_password'],
        )

        if result['success']:
            return Response(result, status=status.HTTP_200_OK)
        else:
            return Response(result, status=status.HTTP_400_BAD_REQUEST)


class CurrentWeatherView(APIView):
    """Devuelve el clima actual real (OpenWeatherMap) para lat/lon dadas."""

    def get(self, request):
        lat = request.query_params.get('lat')
        lon = request.query_params.get('lon')
        if lat is None or lon is None:
            return Response(
                {'error': 'Se requieren los parametros lat y lon.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            data = fetch_current_weather(lat, lon)
        except Exception:
            data = None

        if not data or data.get('temperature') is None:
            return Response(
                {'error': 'No se pudo obtener el clima actual.'},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        return Response(data)


class LocationViewSet(viewsets.ModelViewSet):
    serializer_class = LocationSerializer

    def get_queryset(self):
        return Location.objects.filter(owner=self.request.user)

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)


class ActivityViewSet(viewsets.ModelViewSet):
    serializer_class = ActivitySerializer

    def get_queryset(self):
        queryset = Activity.objects.filter(owner=self.request.user).select_related(
            'location',
            'statistical_summary',
        )
        status_value = self.request.query_params.get('status')
        if status_value:
            queryset = queryset.filter(status=status_value)
        return queryset

    def perform_create(self, serializer):
        activity = serializer.save(owner=self.request.user)
        analyze_activity(activity)

    def perform_update(self, serializer):
        # Si cambian fecha, ubicacion, tipo, etc., el clima y la estadistica
        # quedarian obsoletos. Recalculamos contra el pronostico real para que
        # los datos persistidos sigan siendo verdaderos tras la edicion.
        activity = serializer.save()
        analyze_activity(activity)

    @action(detail=False, methods=['get'])
    def pending(self, request):
        queryset = self.get_queryset().filter(status=Activity.ActivityStatus.PENDING)
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def finish(self, request, pk=None):
        activity = self.get_object()
        activity.status = Activity.ActivityStatus.FINISHED
        activity.save(update_fields=['status', 'updated_at'])
        return Response(self.get_serializer(activity).data)


class ClimateRecordViewSet(viewsets.ModelViewSet):
    serializer_class = ClimateRecordSerializer

    def get_queryset(self):
        return ClimateRecord.objects.filter(activity__owner=self.request.user)


class StatisticalSummaryViewSet(viewsets.ModelViewSet):
    serializer_class = StatisticalSummarySerializer

    def get_queryset(self):
        return StatisticalSummary.objects.filter(activity__owner=self.request.user)
