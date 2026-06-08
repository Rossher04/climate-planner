from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    ActivityViewSet,
    ChangePasswordView,
    ClimateRecordViewSet,
    CurrentWeatherView,
    LocationViewSet,
    MeView,
    PasswordRecoveryView,
    PasswordResetView,
    RegisterView,
    StatisticalSummaryViewSet,
)

router = DefaultRouter()
router.register('locations', LocationViewSet, basename='location')
router.register('activities', ActivityViewSet, basename='activity')
router.register('climate-records', ClimateRecordViewSet, basename='climate-record')
router.register('statistics', StatisticalSummaryViewSet, basename='statistics')

urlpatterns = [
    path('', include(router.urls)),
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/password-recovery/', PasswordRecoveryView.as_view(), name='password_recovery'),
    path('auth/password-reset/', PasswordResetView.as_view(), name='password_reset'),
    path('auth/change-password/', ChangePasswordView.as_view(), name='change_password'),
    path('users/me/', MeView.as_view(), name='me'),
    path('weather/current/', CurrentWeatherView.as_view(), name='current_weather'),
]
