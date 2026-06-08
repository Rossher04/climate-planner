from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models


class UserProfile(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='profile',
    )
    phone = models.CharField(max_length=25, blank=True)
    temporary_password_required = models.BooleanField(default=False)
    password_reset_token = models.CharField(max_length=64, blank=True, null=True, unique=True)
    password_reset_expires = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.user.username


class Location(models.Model):
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='locations',
    )
    name = models.CharField(max_length=120)
    description = models.TextField(blank=True)
    latitude = models.DecimalField(max_digits=10, decimal_places=7)
    longitude = models.DecimalField(max_digits=10, decimal_places=7)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']
        constraints = [
            models.UniqueConstraint(
                fields=['owner', 'name'],
                name='unique_location_name_per_user',
            ),
        ]

    def __str__(self):
        return self.name


class Activity(models.Model):
    class ActivityType(models.TextChoices):
        OUTDOOR = 'outdoor', 'Aire libre'
        INDOOR = 'indoor', 'Interior'

    class ActivityStatus(models.TextChoices):
        PENDING = 'pending', 'Pendiente'
        FINISHED = 'finished', 'Finalizada'
        RESCHEDULED = 'rescheduled', 'Reagendada'
        CANCELLED = 'cancelled', 'Cancelada'

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='activities',
    )
    location = models.ForeignKey(
        Location,
        on_delete=models.CASCADE,
        related_name='activities',
    )
    title = models.CharField(max_length=140)
    description = models.TextField(blank=True)
    date = models.DateField()
    start_time = models.TimeField()
    end_time = models.TimeField()
    activity_type = models.CharField(
        max_length=20,
        choices=ActivityType.choices,
        default=ActivityType.OUTDOOR,
    )
    desired_conditions = models.JSONField(default=list, blank=True)
    status = models.CharField(
        max_length=20,
        choices=ActivityStatus.choices,
        default=ActivityStatus.PENDING,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['date', 'start_time']
        indexes = [
            models.Index(fields=['owner', 'date']),
            models.Index(fields=['location', 'date']),
            models.Index(fields=['status']),
        ]

    def clean(self):
        if self.end_time <= self.start_time:
            raise ValidationError('La hora final debe ser mayor que la inicial.')

    def __str__(self):
        return f'{self.title} - {self.date}'


class ClimateRecord(models.Model):
    activity = models.ForeignKey(
        Activity,
        on_delete=models.CASCADE,
        related_name='climate_records',
    )
    date = models.DateField()
    temperature = models.DecimalField(max_digits=5, decimal_places=2)
    rain_probability = models.DecimalField(max_digits=5, decimal_places=2)
    humidity = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    weather_source = models.CharField(max_length=80, default='OpenWeatherMap')
    raw_data = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date']
        indexes = [
            models.Index(fields=['activity', 'date']),
        ]

    def __str__(self):
        return f'Clima {self.activity.title} - {self.date}'


class StatisticalSummary(models.Model):
    class Trend(models.TextChoices):
        WARMING = 'warming', 'Calentamiento'
        COOLING = 'cooling', 'Enfriamiento'
        STABLE = 'stable', 'Estable'

    class Recommendation(models.TextChoices):
        DO = 'do', 'Realizar'
        REVIEW = 'review', 'Revisar'
        POSTPONE = 'postpone', 'Posponer'

    activity = models.OneToOneField(
        Activity,
        on_delete=models.CASCADE,
        related_name='statistical_summary',
    )
    mean_temperature = models.DecimalField(max_digits=5, decimal_places=2)
    median_temperature = models.DecimalField(max_digits=5, decimal_places=2)
    mode_temperature = models.DecimalField(max_digits=5, decimal_places=2)
    # Serie con la temperatura MAXIMA diaria de los 7 DIAS ANTERIORES (datos
    # observados reales del lugar del evento, via Open-Meteo). Es la base de
    # media, mediana, moda y regresion lineal; se persiste para graficarla.
    temperature_series = models.JSONField(default=list, blank=True)
    regression_slope = models.DecimalField(max_digits=8, decimal_places=4)
    regression_intercept = models.DecimalField(max_digits=8, decimal_places=4)
    trend = models.CharField(max_length=20, choices=Trend.choices)
    bayes_rain_probability = models.DecimalField(max_digits=5, decimal_places=2)
    realization_probability = models.DecimalField(max_digits=5, decimal_places=2)
    recommendation = models.CharField(
        max_length=20,
        choices=Recommendation.choices,
        default=Recommendation.REVIEW,
    )
    calculated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'Estadistica {self.activity.title}'
