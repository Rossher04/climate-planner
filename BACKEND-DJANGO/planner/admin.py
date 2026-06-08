from django.contrib import admin

from .models import Activity, ClimateRecord, Location, StatisticalSummary, UserProfile


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ['user', 'phone', 'temporary_password_required', 'updated_at']
    search_fields = ['user__username', 'user__email', 'phone']


@admin.register(Location)
class LocationAdmin(admin.ModelAdmin):
    list_display = ['name', 'owner', 'latitude', 'longitude', 'updated_at']
    list_filter = ['created_at']
    search_fields = ['name', 'owner__username']


@admin.register(Activity)
class ActivityAdmin(admin.ModelAdmin):
    list_display = ['title', 'owner', 'location', 'date', 'start_time', 'status']
    list_filter = ['activity_type', 'status', 'date']
    search_fields = ['title', 'owner__username', 'location__name']


@admin.register(ClimateRecord)
class ClimateRecordAdmin(admin.ModelAdmin):
    list_display = [
        'activity',
        'date',
        'temperature',
        'rain_probability',
        'weather_source',
    ]
    list_filter = ['weather_source', 'date']


@admin.register(StatisticalSummary)
class StatisticalSummaryAdmin(admin.ModelAdmin):
    list_display = [
        'activity',
        'realization_probability',
        'recommendation',
        'trend',
        'calculated_at',
    ]
    list_filter = ['recommendation', 'trend']
