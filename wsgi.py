"""
wsgi.py — Entry point de producción para Gunicorn en Render
El servidor Flask está definido en scripts/daily_events/scrape_events.py
"""
import sys
import os

# Asegura que el directorio raíz esté en el path de Python
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from scripts.daily_events.scrape_events import app  # noqa: F401

if __name__ == "__main__":
    app.run()
