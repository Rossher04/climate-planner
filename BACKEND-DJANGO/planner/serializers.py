from django.contrib.auth import get_user_model
from rest_framework import serializers

from .models import Activity, ClimateRecord, Location, StatisticalSummary, UserProfile


User = get_user_model()


class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = ['phone', 'temporary_password_required']


class UserSerializer(serializers.ModelSerializer):
    profile = UserProfileSerializer(read_only=True)
    phone = serializers.CharField(
        source='profile.phone',
        required=False,
        allow_blank=True,
    )

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'phone', 'profile']
        read_only_fields = ['id', 'username']

    def update(self, instance, validated_data):
        profile_data = validated_data.pop('profile', None)
        instance = super().update(instance, validated_data)
        if profile_data is not None and 'phone' in profile_data:
            profile, _ = UserProfile.objects.get_or_create(user=instance)
            profile.phone = profile_data['phone']
            profile.save(update_fields=['phone', 'updated_at'])
        return instance


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'password']
        read_only_fields = ['id']

    def create(self, validated_data):
        password = validated_data.pop('password')
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        UserProfile.objects.create(user=user)
        return user


class LocationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Location
        fields = [
            'id',
            'name',
            'description',
            'latitude',
            'longitude',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class ActivitySerializer(serializers.ModelSerializer):
    location_name = serializers.CharField(source='location.name', read_only=True)
    temperature = serializers.SerializerMethodField()
    rain_probability = serializers.SerializerMethodField()
    weather_source = serializers.SerializerMethodField()
    realization_probability = serializers.DecimalField(
        source='statistical_summary.realization_probability',
        max_digits=5,
        decimal_places=2,
        read_only=True,
    )
    recommendation = serializers.CharField(
        source='statistical_summary.recommendation',
        read_only=True,
    )
    # Resumen estadistico completo (Bayes + tendencia central + regresion) para
    # que Flutter consuma datos reales en lugar de recalcularlos.
    statistics = serializers.SerializerMethodField()

    class Meta:
        model = Activity
        fields = [
            'id',
            'location',
            'location_name',
            'title',
            'description',
            'date',
            'start_time',
            'end_time',
            'activity_type',
            'desired_conditions',
            'status',
            'temperature',
            'rain_probability',
            'weather_source',
            'realization_probability',
            'recommendation',
            'statistics',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'id',
            'location_name',
            'temperature',
            'rain_probability',
            'weather_source',
            'realization_probability',
            'recommendation',
            'statistics',
            'created_at',
            'updated_at',
        ]

    def get_statistics(self, obj):
        summary = getattr(obj, 'statistical_summary', None)
        if summary is None:
            return None
        return {
            'mean_temperature': float(summary.mean_temperature),
            'median_temperature': float(summary.median_temperature),
            'mode_temperature': float(summary.mode_temperature),
            'temperature_series': summary.temperature_series or [],
            'regression_slope': float(summary.regression_slope),
            'regression_intercept': float(summary.regression_intercept),
            'trend': summary.trend,
            'bayes_rain_probability': float(summary.bayes_rain_probability),
            'realization_probability': float(summary.realization_probability),
            'recommendation': summary.recommendation,
        }

    def validate_location(self, location):
        request = self.context['request']
        if location.owner != request.user:
            raise serializers.ValidationError('La ubicacion no pertenece al usuario.')
        return location

    def validate(self, attrs):
        instance = self.instance
        location = attrs.get('location', getattr(instance, 'location', None))
        date = attrs.get('date', getattr(instance, 'date', None))
        start_time = attrs.get('start_time', getattr(instance, 'start_time', None))
        end_time = attrs.get('end_time', getattr(instance, 'end_time', None))

        if end_time and start_time and end_time <= start_time:
            raise serializers.ValidationError(
                {'end_time': 'La hora final debe ser mayor que la inicial.'}
            )

        if location and date and start_time and end_time:
            overlaps = Activity.objects.filter(
                owner=self.context['request'].user,
                location=location,
                date=date,
                start_time__lt=end_time,
                end_time__gt=start_time,
            )
            if instance:
                overlaps = overlaps.exclude(pk=instance.pk)
            if overlaps.exists():
                raise serializers.ValidationError(
                    'La actividad se cruza con otra en la misma ubicacion.'
                )

        return attrs

    def get_latest_climate(self, obj):
        if hasattr(obj, '_latest_climate_cache'):
            return obj._latest_climate_cache
        obj._latest_climate_cache = obj.climate_records.order_by('-created_at').first()
        return obj._latest_climate_cache

    def get_temperature(self, obj):
        climate = self.get_latest_climate(obj)
        return climate.temperature if climate else None

    def get_rain_probability(self, obj):
        climate = self.get_latest_climate(obj)
        return climate.rain_probability if climate else None

    def get_weather_source(self, obj):
        climate = self.get_latest_climate(obj)
        return climate.weather_source if climate else ''


class ClimateRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model = ClimateRecord
        fields = [
            'id',
            'activity',
            'date',
            'temperature',
            'rain_probability',
            'humidity',
            'weather_source',
            'raw_data',
            'created_at',
        ]
        read_only_fields = ['id', 'created_at']


class StatisticalSummarySerializer(serializers.ModelSerializer):
    class Meta:
        model = StatisticalSummary
        fields = [
            'id',
            'activity',
            'mean_temperature',
            'median_temperature',
            'mode_temperature',
            'regression_slope',
            'regression_intercept',
            'trend',
            'bayes_rain_probability',
            'realization_probability',
            'recommendation',
            'calculated_at',
        ]
        read_only_fields = ['id', 'calculated_at']


class PasswordRecoverySerializer(serializers.Serializer):
    email = serializers.EmailField()


class PasswordResetSerializer(serializers.Serializer):
    token = serializers.CharField()
    new_password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True, min_length=8)

    def validate(self, attrs):
        if attrs['new_password'] != attrs['password_confirm']:
            raise serializers.ValidationError(
                {'password_confirm': 'Las contraseñas no coinciden.'}
            )
        return attrs


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True, min_length=8)

    def validate(self, attrs):
        if attrs['new_password'] != attrs['password_confirm']:
            raise serializers.ValidationError(
                {'password_confirm': 'Las contraseñas no coinciden.'}
            )
        return attrs
