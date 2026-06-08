#!/usr/bin/env bash
# Script de build para Render (backend Django de Climate Planner).
# Render lo ejecuta en cada despliegue.
set -o errexit

pip install -r requirements.txt
python manage.py collectstatic --no-input
python manage.py migrate
