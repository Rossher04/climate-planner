from datetime import date, time

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand

from planner.models import Activity, Location, UserProfile
from planner.services import analyze_activity


class Command(BaseCommand):
    help = 'Crea datos demo para Climate.'

    def handle(self, *args, **options):
        User = get_user_model()
        user, created = User.objects.get_or_create(
            username='estudiante',
            defaults={
                'email': 'estudiante@universidad.edu',
                'first_name': 'Estudiante',
                'last_name': 'Climate',
            },
        )
        if created:
            user.set_password('Climate2026!')
            user.save()
        UserProfile.objects.get_or_create(user=user)

        location, _ = Location.objects.get_or_create(
            owner=user,
            name='Cancha zona 3',
            defaults={
                'description': 'Ubicacion demo para actividades al aire libre.',
                'latitude': 14.8421000,
                'longitude': -91.5210000,
            },
        )

        activity, _ = Activity.objects.get_or_create(
            owner=user,
            location=location,
            title='Partido de futbol',
            date=date(2026, 5, 28),
            start_time=time(16, 0),
            defaults={
                'end_time': time(18, 0),
                'activity_type': Activity.ActivityType.OUTDOOR,
                'desired_conditions': ['sin lluvia', 'temperatura moderada'],
            },
        )

        if not activity.climate_records.exists() or not hasattr(activity, 'statistical_summary'):
            analyze_activity(activity)

        self.stdout.write(self.style.SUCCESS('Datos demo creados.'))
