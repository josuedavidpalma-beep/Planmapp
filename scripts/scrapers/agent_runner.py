import os
import logging
from scout_core import get_top_places, get_known_events, fetch_raw_text_about_place, process_with_gemini, safe_insert_event

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def run_agent_for_city(city: str):
    logging.info(f"========== INICIANDO AGENTE SCOUT: {city.upper()} ==========")
    
    known_events = get_known_events(city)
    logging.info(f"🧠 Memoria cargada: {len(known_events)} eventos futuros conocidos.")
    
    top_places = get_top_places(city)
    logging.info(f"🎯 Encontrados {len(top_places)} comercios TOP (>4.0 estrellas) para escanear.")
    
    if not top_places:
        logging.warning(f"No hay comercios top en {city}. Abortando ciudad.")
        return
        
    for place in top_places:
        logging.info(f"🔍 Evaluando: {place['name']}")
        
        # 1. Scrape surface data
        raw_text = fetch_raw_text_about_place(place['name'], city)
        
        # 2. IA Processing
        found_events = process_with_gemini(raw_text, place, known_events)
        
        if found_events:
            logging.info(f"✨ ¡Gemini encontró {len(found_events)} novedades en {place['name']}!")
            for e in found_events:
                safe_insert_event(city, place, e)
        else:
            logging.info(f"💤 Ninguna novedad relevante encontrada en {place['name']}.")

if __name__ == "__main__":
    # La variable CITY se pasara desde GitHub Actions (Matrix Job)
    target_city = os.environ.get("TARGET_CITY")
    
    if target_city:
        run_agent_for_city(target_city)
    else:
        # Fallback local testing
        run_agent_for_city("Barranquilla")
