from django.contrib.auth import get_user_model
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer


class EmailOrUsernameTokenObtainPairSerializer(TokenObtainPairSerializer):
    def validate(self, attrs):
        username = attrs.get(self.username_field)
        if username and '@' in username:
            User = get_user_model()
            user = User.objects.filter(email__iexact=username).first()
            if user:
                attrs[self.username_field] = user.get_username()
        return super().validate(attrs)
