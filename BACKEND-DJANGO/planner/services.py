import json
import secrets
import statistics
import string
import urllib.parse
import urllib.request
from datetime import datetime, timedelta
from decimal import Decimal

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.mail import send_mail
from django.utils import timezone

from .models import Activity, ClimateRecord, StatisticalSummary, UserProfile

User = get_user_model()


def analyze_activity(activity):
    weather = fetch_weather(activity)
    temperatures = weather['temperatures']
    rain_probability = Decimal(str(weather['rain_probability']))

    climate_record = ClimateRecord.objects.create(
        activity=activity,
        date=activity.date,
        temperature=Decimal(str(weather['temperature'])),
        rain_probability=rain_probability,
        humidity=Decimal(str(weather['humidity'])) if weather.get('humidity') is not None else None,
        weather_source=weather['source'],
        raw_data=weather['raw_data'],
    )

    mean_temperature = Decimal(str(round(statistics.mean(temperatures), 2)))
    median_temperature = Decimal(str(round(statistics.median(temperatures), 2)))
    mode_temperature = Decimal(str(round(calculate_mode(temperatures), 2)))
    slope, intercept = linear_regression(temperatures)
    bayes_rain_probability = calculate_bayes_rain_probability(float(rain_probability))
    realization_probability = calculate_realization_probability(
        activity=activity,
        rain_probability=bayes_rain_probability,
    )

    StatisticalSummary.objects.update_or_create(
        activity=activity,
        defaults={
            'mean_temperature': mean_temperature,
            'median_temperature': median_temperature,
            'mode_temperature': mode_temperature,
            'temperature_series': [round(float(t), 2) for t in temperatures],
            'regression_slope': Decimal(str(round(slope, 4))),
            'regression_intercept': Decimal(str(round(intercept, 4))),
            'trend': trend_for_slope(slope),
            'bayes_rain_probability': Decimal(str(round(bayes_rain_probability, 2))),
            'realization_probability': Decimal(str(round(realization_probability, 2))),
            'recommendation': recommendation_for(realization_probability),
        },
    )

    return climate_record


def fetch_weather(activity):
    # Fuente primaria: Open-Meteo (gratis, sin API key). En una sola llamada da
    # los 7 DIAS ANTERIORES reales (serie que exige el enunciado para media,
    # mediana, moda y regresion) y el pronostico del evento. Si falla, se intenta
    # OpenWeather y, como ultimo recurso, el respaldo local.
    try:
        return fetch_openmeteo(activity)
    except Exception:
        pass
    if settings.OPENWEATHER_API_KEY:
        try:
            return fetch_openweather(activity)
        except Exception:
            pass
    return fallback_weather(activity)


def fetch_openmeteo(activity):
    """Clima del evento + serie de los 7 dias ANTERIORES, via Open-Meteo.

    - 'temperatures': temperatura MAXIMA diaria REAL de los 7 dias anteriores a
      hoy en el lugar del evento (datos observados). Es la serie exigida por el
      enunciado para media, mediana, moda y regresion lineal.
    - 'temperature'/'rain_probability'/'humidity': pronostico del corte horario
      mas cercano a la fecha+hora del evento. Si el evento queda fuera del
      horizonte de pronostico (16 dias) se marca como estimacion.
    """
    location = activity.location
    params = urllib.parse.urlencode(
        {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'daily': 'temperature_2m_max',
            'hourly': 'temperature_2m,precipitation_probability,relative_humidity_2m',
            'past_days': 7,
            'forecast_days': 16,
            'timezone': 'auto',
        }
    )
    url = f'https://api.open-meteo.com/v1/forecast?{params}'

    with urllib.request.urlopen(url, timeout=8) as response:
        payload = json.loads(response.read().decode('utf-8'))

    # --- Serie de las MAXIMAS diarias de los 7 dias ANTERIORES a hoy (reales) ---
    daily = payload.get('daily', {})
    days = daily.get('time', [])
    maxima = daily.get('temperature_2m_max', [])
    today = timezone.localdate().isoformat()
    previous = [(day, value) for day, value in zip(days, maxima) if day < today and value is not None]
    previous = previous[-7:]
    temperatures = [round(float(value), 2) for _, value in previous]
    if not temperatures:
        temperatures = [24.0]

    # --- Pronostico del corte horario mas cercano a la fecha+hora del evento ---
    hourly = payload.get('hourly', {})
    times = hourly.get('time', [])
    temps_h = hourly.get('temperature_2m', [])
    pops_h = hourly.get('precipitation_probability', [])
    hums_h = hourly.get('relative_humidity_2m', [])

    target = datetime.combine(activity.date, activity.start_time)
    best_i = None
    best_diff = None
    for i, text in enumerate(times):
        try:
            slot = datetime.strptime(text, '%Y-%m-%dT%H:%M')
        except (ValueError, TypeError):
            continue
        diff = abs((slot - target).total_seconds())
        if best_diff is None or diff < best_diff:
            best_diff = diff
            best_i = i

    def value_at(series):
        if best_i is not None and best_i < len(series) and series[best_i] is not None:
            return float(series[best_i])
        return None

    event_temp = value_at(temps_h)
    event_pop = value_at(pops_h)
    event_hum = value_at(hums_h)

    last_forecast_date = days[-1] if days else today
    in_range = activity.date.isoformat() <= last_forecast_date
    source = 'Open-Meteo' if in_range else 'Open-Meteo (estimado, fuera de rango de pronóstico)'

    return {
        'temperature': round(event_temp, 2) if event_temp is not None else temperatures[-1],
        'humidity': round(event_hum, 2) if event_hum is not None else None,
        'rain_probability': round(event_pop, 2) if event_pop is not None else 0.0,
        'temperatures': temperatures,
        'source': source,
        'out_of_range': not in_range,
        'raw_data': {
            'previous_7_days': previous,
            'event_slot': times[best_i] if best_i is not None else None,
        },
    }


def fetch_current_weather(lat, lon):
    """Clima actual REAL de OpenWeatherMap para unas coordenadas.

    Se usa para mostrar la temperatura del lugar donde esta el usuario en el
    encabezado de la app. Devuelve None si no hay API key o si falla la llamada.
    """
    if not settings.OPENWEATHER_API_KEY:
        return None

    params = urllib.parse.urlencode(
        {
            'lat': lat,
            'lon': lon,
            'appid': settings.OPENWEATHER_API_KEY,
            'units': 'metric',
            'lang': 'es',
        }
    )
    url = f'https://api.openweathermap.org/data/2.5/weather?{params}'

    with urllib.request.urlopen(url, timeout=8) as response:
        payload = json.loads(response.read().decode('utf-8'))

    main = payload.get('main', {})
    weather = (payload.get('weather') or [{}])[0]
    temp = main.get('temp')

    return {
        'temperature': round(float(temp), 1) if temp is not None else None,
        'feels_like': round(float(main['feels_like']), 1) if main.get('feels_like') is not None else None,
        'humidity': main.get('humidity'),
        'description': weather.get('description', ''),
        'city': payload.get('name', ''),
        'source': 'OpenWeatherMap',
    }


def fetch_openweather(activity):
    location = activity.location
    params = urllib.parse.urlencode(
        {
            'lat': location.latitude,
            'lon': location.longitude,
            'appid': settings.OPENWEATHER_API_KEY,
            'units': 'metric',
            'lang': 'es',
        }
    )
    url = f'https://api.openweathermap.org/data/2.5/forecast?{params}'

    with urllib.request.urlopen(url, timeout=8) as response:
        payload = json.loads(response.read().decode('utf-8'))

    items = payload.get('list', [])
    if not items:
        raise ValueError('OpenWeatherMap no devolvio pronosticos.')

    selected, in_range = nearest_forecast(items, activity)
    main = selected.get('main', {})
    rain_probability = round(float(selected.get('pop', 0)) * 100, 2)
    temperatures = extract_temperature_series(items)

    # Si la fecha de la actividad esta fuera de la ventana de 5 dias del
    # pronostico, los datos son una estimacion (corte intermedio), no el clima
    # real de ese dia. Lo reflejamos en la fuente para que la app lo muestre.
    source = 'OpenWeatherMap' if in_range else 'OpenWeatherMap (estimado, fuera de rango de 5 días)'

    return {
        'temperature': float(main.get('temp', temperatures[0])),
        'humidity': main.get('humidity'),
        'rain_probability': rain_probability,
        'temperatures': temperatures,
        'source': source,
        'out_of_range': not in_range,
        'raw_data': selected,
    }


def nearest_forecast(items, activity):
    """Selecciona el corte de pronostico de la HORA mas cercana a la actividad.

    OpenWeather entrega cortes cada 3h. Se elige el corte cuyo timestamp este
    mas proximo a la fecha+hora de inicio de la actividad, para que la
    temperatura y la probabilidad de lluvia correspondan al momento real del
    evento y no a un corte arbitrario del dia (p. ej. un almuerzo de las 11:30
    ya no hereda la lluvia de las 21:00).

    Devuelve una tupla (corte, in_range):
    - in_range=True  -> existe pronostico para la fecha exacta de la actividad
      (esta dentro de la ventana de 5 dias de OpenWeather).
    - in_range=False -> la fecha cae fuera de esa ventana; se elige el corte mas
      cercano en el tiempo como estimacion y el llamador lo marca como aproximado.
    """
    target = datetime.combine(activity.date, activity.start_time)

    same_day = [item for item in items if item.get('dt_txt', '').startswith(activity.date.isoformat())]
    in_range = bool(same_day)
    candidates = same_day or items

    def time_distance(item):
        try:
            slot = datetime.strptime(item['dt_txt'], '%Y-%m-%d %H:%M:%S')
        except (KeyError, ValueError, TypeError):
            return float('inf')
        return abs((slot - target).total_seconds())

    return min(candidates, key=time_distance), in_range


def extract_temperature_series(items):
    """Serie de temperaturas con el PROMEDIO diario real de cada dia disponible.

    OpenWeather (plan gratuito) entrega ~40 cortes de 3h repartidos en 5-6 dias
    de calendario. Para cada dia se promedian todos sus cortes, de modo que el
    valor representa la temperatura media de ese dia (no el primer corte, que
    suele caer de madrugada y sesgaba la serie hacia el minimo).

    IMPORTANTE: la serie contiene UNICAMENTE los dias reales devueltos por la
    API. No se rellenan dias inexistentes con duplicados, porque ese relleno
    distorsionaba la moda y la regresion lineal. Asi la estadistica se calcula
    solo sobre datos reales.
    """
    sums = {}
    counts = {}
    order = []
    for item in items:
        date_text = item.get('dt_txt', '')[:10]
        temp = item.get('main', {}).get('temp')
        if not date_text or temp is None:
            continue
        if date_text not in sums:
            sums[date_text] = 0.0
            counts[date_text] = 0
            order.append(date_text)
        sums[date_text] += float(temp)
        counts[date_text] += 1

    series = [round(sums[date_text] / counts[date_text], 2) for date_text in order[:7]]

    if not series:
        series = [24.0]

    return series


def fallback_weather(activity):
    if activity.activity_type == Activity.ActivityType.INDOOR:
        rain_probability = 35.0
        temperature = 24.0
    elif 'parque' in activity.location.name.lower():
        rain_probability = 72.0
        temperature = 23.0
    else:
        rain_probability = 32.0
        temperature = 25.0

    temperatures = [temperature - 2, temperature, temperature - 1, temperature + 1, temperature, temperature + 2, temperature + 3]

    return {
        'temperature': temperature,
        'humidity': 70.0,
        'rain_probability': rain_probability,
        'temperatures': temperatures,
        'source': 'Respaldo local',
        'raw_data': {'fallback': True},
    }


def calculate_mode(values):
    """Moda de la serie de temperaturas.

    Las temperaturas son valores continuos que casi nunca se repiten de forma
    exacta, por lo que una moda "cruda" no tendria significado (devolveria un
    valor arbitrario). Para obtener una moda interpretable se agrupan las
    temperaturas al grado mas cercano (binning) y se devuelve la temperatura
    que mas dias se repite en la semana. Ante un empate se devuelve el valor
    mas bajo, de forma determinista y reproducible.
    """
    if not values:
        return 0.0
    counts = {}
    for value in values:
        bucket = round(value)
        counts[bucket] = counts.get(bucket, 0) + 1
    best = sorted(counts.items(), key=lambda item: (-item[1], item[0]))[0][0]
    return float(best)


def linear_regression(values):
    points = [(index + 1, value) for index, value in enumerate(values)]
    n = len(points)
    sum_x = sum(point[0] for point in points)
    sum_y = sum(point[1] for point in points)
    sum_xy = sum(point[0] * point[1] for point in points)
    sum_xx = sum(point[0] ** 2 for point in points)
    denominator = n * sum_xx - sum_x**2
    if denominator == 0:
        return 0.0, values[0]
    slope = (n * sum_xy - sum_x * sum_y) / denominator
    intercept = (sum_y - slope * sum_x) / n
    return slope, intercept


# --- Parametros del modelo bayesiano de lluvia -------------------------------
# La probabilidad de precipitacion del pronostico (pop de OpenWeather) actua
# como probabilidad a priori P(lluvia). Sobre ese prior se aplica el Teorema de
# Bayes condicionando en el evento "el sistema de alerta de lluvia se activa",
# caracterizado por dos parametros de fiabilidad DOCUMENTADOS del sistema:
#   ALERT_SENSITIVITY = P(alerta | llueve)     -> verdaderos positivos (acierto)
#   ALERT_FALSE_ALARM = P(alerta | no llueve)  -> falsos positivos (falsa alarma)
# Son parametros de fiabilidad asumidos para el sistema de alerta (sensibilidad
# 85%, tasa de falsa alarma 25%). No se estiman de datos historicos porque el
# modelo todavia no almacena el resultado real observado (llovio / no llovio)
# de cada actividad; cuando se registre ese resultado podran recalcularse.
ALERT_SENSITIVITY = 0.85   # P(alerta | lluvia)
ALERT_FALSE_ALARM = 0.25   # P(alerta | no lluvia)


def calculate_bayes_rain_probability(api_rain_probability):
    """Probabilidad de lluvia ajustada con el Teorema de Bayes.

    Aplica:
        P(lluvia | alerta) = P(alerta | lluvia) * P(lluvia)
                             ---------------------------------------------------
                             P(alerta | lluvia)*P(lluvia) + P(alerta|no lluvia)*P(no lluvia)

    donde P(lluvia) es la probabilidad a priori del pronostico (pop). El
    denominador es la probabilidad total de que la alerta se active (regla de
    la probabilidad total). Recibe y devuelve el valor en porcentaje (0-100).

    Ejemplo: con pop=20% -> P(lluvia)=0.20
        P(alerta) = 0.85*0.20 + 0.25*0.80 = 0.37
        P(lluvia|alerta) = (0.85*0.20) / 0.37 = 0.4595 -> 45.95%
    """
    p_rain = api_rain_probability / 100
    p_no_rain = 1 - p_rain
    p_alert = (ALERT_SENSITIVITY * p_rain) + (ALERT_FALSE_ALARM * p_no_rain)
    if p_alert == 0:
        return api_rain_probability
    return ((ALERT_SENSITIVITY * p_rain) / p_alert) * 100


def calculate_realization_probability(activity, rain_probability):
    # Indicador de Probabilidad de Realizacion SEGUN EL TIPO de actividad y el
    # clima (rubrica de Programacion de Dispositivos Moviles, modulo Pendientes):
    #   - Aire libre: depende totalmente del clima -> complemento de la lluvia.
    #   - Interior: la lluvia afecta poco (bajo techo) -> se atenua su impacto
    #     (x0.25) con un piso del 70%.
    if activity.activity_type == Activity.ActivityType.INDOOR:
        return max(70, 100 - (rain_probability * 0.25))
    return max(0, 100 - rain_probability)


def trend_for_slope(slope):
    if slope > 0.05:
        return StatisticalSummary.Trend.WARMING
    if slope < -0.05:
        return StatisticalSummary.Trend.COOLING
    return StatisticalSummary.Trend.STABLE


def recommendation_for(realization_probability):
    if realization_probability >= 75:
        return StatisticalSummary.Recommendation.DO
    if realization_probability >= 50:
        return StatisticalSummary.Recommendation.REVIEW
    return StatisticalSummary.Recommendation.POSTPONE


def generate_temporary_password(length=12):
    chars = string.ascii_letters + string.digits
    return ''.join(secrets.choice(chars) for _ in range(length))


def generate_reset_token():
    return secrets.token_urlsafe(48)


def request_password_recovery(email):
    # filter().first() en vez de get(): evita el error 500 si hubiera dos
    # usuarios con el mismo correo, y la busqueda es insensible a mayusculas.
    user = User.objects.filter(email__iexact=email).first()
    if user is None:
        return {'success': False, 'error': 'Usuario no encontrado'}

    profile, _ = UserProfile.objects.get_or_create(user=user)
    temp_password = generate_temporary_password()
    reset_token = generate_reset_token()

    profile.password_reset_token = reset_token
    profile.password_reset_expires = timezone.now() + timedelta(hours=24)
    profile.temporary_password_required = True
    profile.save()

    user.set_password(temp_password)
    user.save()

    # IMPORTANTE: en Render (plan free) los puertos SMTP estan bloqueados, por lo
    # que un envio real colgaria el worker (timeout -> 500). Por eso solo se
    # intenta enviar con el backend de CONSOLA (desarrollo local) y la contrasena
    # temporal se DEVUELVE para mostrarla en la app (modo academico). Para correo
    # real se integraria una API HTTP de email (p. ej. Resend/SendGrid).
    try:
        if 'console' in (settings.EMAIL_BACKEND or ''):
            send_password_recovery_email(user, temp_password, reset_token)
    except Exception:
        pass

    return {
        'success': True,
        'reset_token': reset_token,
        'temporary_password': temp_password,
        'message': 'Verifica tu correo y define tu nueva contraseña.',
    }


def send_password_recovery_email(user, temp_password, reset_token):
    subject = 'Recuperación de contraseña - Climate Planner'
    message = f'''
Hola {user.first_name or user.username},

Hemos recibido una solicitud para recuperar tu contraseña en Climate Planner.

Tu contraseña temporal es: {temp_password}

⚠️  Esta contraseña temporal debe ser cambiada al iniciar sesión.

Si no solicitaste la recuperación de contraseña, ignora este correo.

---
Climate Planner
Planificador Inteligente de Actividades
    '''

    try:
        send_mail(
            subject,
            message,
            settings.DEFAULT_FROM_EMAIL,
            [user.email],
            fail_silently=False,
        )
    except Exception as e:
        print(f'Error enviando correo de recuperación: {e}')


def validate_password_reset_token(user, token):
    profile = user.profile
    if not profile.password_reset_token:
        return False
    if profile.password_reset_token != token:
        return False
    if profile.password_reset_expires is None:
        return False
    if timezone.now() > profile.password_reset_expires:
        return False
    return True


def complete_password_reset(user, token, new_password):
    if not validate_password_reset_token(user, token):
        return {'success': False, 'error': 'Token inválido o expirado'}

    user.set_password(new_password)
    user.save()

    profile = user.profile
    profile.password_reset_token = None
    profile.password_reset_expires = None
    profile.temporary_password_required = False
    profile.save()

    return {'success': True, 'message': 'Contraseña actualizada correctamente'}
