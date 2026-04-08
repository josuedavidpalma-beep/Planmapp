import os
import requests
from bs4 import BeautifulSoup
import google.generativeai as genai
from supabase import create_client, Client
from datetime import datetime, timedelta
import json
import time

# --- CONFIGURATION ---
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")

# --- SOURCE DICTIONARY (Optimizado para Planes y Ofertas) ---
SOURCE_DICTIONARY = {
    "Nacional": {
        "primary": "https://www.eventbrite.co/d/colombia/events/",
        "secondary": "https://www.tuboleta.com"
    },
    "Barranquilla": {
        "primary": "https://baqucultura.com/calendario/", # Calendario directo
        "secondary": "https://www.elheraldo.co/entretenimiento" 
    },
    "Cartagena": {
        "primary": "https://www.donde.com.co/es/cartagena/agenda",
        "secondary": "https://www.eluniversal.com.co/cultural"
    },
    "Santa Marta": {
        "primary": "https://www.santamarta.gov.co/agenda-eventos",
        "secondary": "https://www.hoydiariodelmagdalena.com.co/category/sociales/"
    }
    # Puedes añadir más ciudades siguiendo este formato
}

NATIONAL_SOURCES = SOURCE_DICTIONARY["Nacional"]
DEFAULT_IMAGES = {
    "music": "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&q=80&w=800",
    "culture": "https://images.unsplash.com/photo-1533174072545-e8d4aa97edf9?auto=format&fit=crop&q=80&w=800",
    "food": "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&q=80&w=800",
    "party": "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&q=80&w=800",
    "outdoors": "https://images.unsplash.com/photo-1502086223501-681a91cc44e7?auto=format&fit=crop&q=80&w=800",
    "other": "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&q=80&w=800"
}

def fetch_page_content(url):
    try:
        headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'}
        response = requests.get(url, headers=headers, timeout=15)
        if response.status_code == 404: return None
        response.raise_for_status()
        return response.text
    except Exception as e:
        print(f"Error fetching URL {url}: {e}")
        return None

def extract_content_with_gemini(html_content, source_url, city_name, is_national_fallback=False):
    if not GEMINI_API_KEY: return None

    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel('gemini-1.5-flash')

    soup = BeautifulSoup(html_content, 'html.parser')
    # Limpiamos el HTML para que Gemini no se confunda con código basura
    text_content = soup.get_text(separator=' ', strip=True)[:20000]

    # --- EL "CEREBRO": NUEVAS INSTRUCCIONES ENFOCADAS EN OFERTAS ---
    prompt = f"""
    Eres un agente experto en encontrar PLANES, EVENTOS y PROMOCIONES en {city_name}.
    Tu objetivo es encontrar dónde la gente puede salir a divertirse o ahorrar dinero.

    CRITERIOS DE SELECCIÓN (Prioridad Alta):
    1. PROMOCIONES: Busca "2x1", "Happy Hour", "Descuento", "Oferta", "Cortesía".
    2. COMIDA: Busca lanzamientos de hamburguesas, festivales gastronómicos, catas.
    3. CULTURA/FIESTA: Conciertos, teatro, ferias, fiestas en discotecas.

    REGLAS DE EXCLUSIÓN (IGNORAR):
    - NO extraigas noticias de fútbol (partidos, fichajes).
    - NO extraigas noticias de política, crímenes o sucesos judiciales.
    - NO extraigas noticias generales que no sean un plan para asistir.

    Return a STRICT JSON ARRAY of objects (max 8 relevant).
    Field Mapping:
    - title: (String) Nombre del plan u oferta.
    - date_start: (String) ISO 8601 o YYYY-MM-DD. Si no hay fecha, usa hoy.
    - city: (String) "{city_name}"
    - location_name: (String) Nombre del establecimiento o sitio.
    - description: (String) Resumen breve destacando la oferta (Ej: "2x1 en Margaritas toda la noche").
    - category: (String) One of: "music", "culture", "outdoors", "party", "food", "other"
    - image_url: (String) URL de la imagen si existe.
    - event_link: (String) Link directo.

    Source Text:
    {text_content}
    """

    try:
        response = model.generate_content(prompt)
        cleaned_text = response.text.replace('```json', '').replace('```', '').strip()
        if cleaned_text.startswith('{'): cleaned_text = f"[{cleaned_text}]"
        events = json.loads(cleaned_text)
        
        valid_events = []
        for e in events:
            normalized = {
                "title": e.get('title'),
                "description": e.get('description'),
                "date": e.get('date_start'),
                "location": e.get('location_name'),
                "category": e.get('category', 'other'),
                "image_url": e.get('image_url') if e.get('image_url') else DEFAULT_IMAGES.get(e.get('category'), DEFAULT_IMAGES['other']),
                "source_url": e.get('event_link', source_url),
                "city": city_name,
                "address": e.get('location_name'),
                "contact_info": "" 
            }
            valid_events.append(normalized)
        return valid_events
    except Exception as e:
        print(f"Error parsing with Gemini: {e}")
        return []

# --- EL RESTO DEL CÓDIGO (SUBIDA A SUPABASE) SE MANTIENE IGUAL ---
def upload_to_supabase(event_data):
    if not SUPABASE_URL or not SUPABASE_KEY: return
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    if not event_data.get('date'):
         event_data['date'] = datetime.now().strftime("%Y-%m-%d")

    try:
        data = {
            "title": event_data.get('title'),
            "description": event_data.get('description'),
            "date": event_data.get('date'),
            "end_date": event_data.get('date'),
            "location": event_data.get('location'),
            "address": event_data.get('address'),
            "category": event_data.get('category').lower() if event_data.get('category') else 'other',
            "image_url": event_data.get('image_url'),
            "source_url": event_data.get('source_url'),
            "contact_info": event_data.get('contact_info'),
            "city": event_data.get('city'),
            "created_at": datetime.utcnow().isoformat()
        }
        existing = supabase.table('events').select("*").eq('title', data['title']).execute()
        if not existing.data:
            supabase.table('events').insert(data).execute()
            print(f"Uploaded: {data['title']} ({data['city']})")
        else:
            print(f"Skipped (Duplicate): {data['title']}")
    except Exception as e:
        print(f"Error uploading {event_data.get('title')}: {e}")

def process_city(city_name, urls):
    print(f"\n--- Buscando Planes en {city_name} ---")
    events_found = 0
    if urls.get('primary'):
        html = fetch_page_content(urls['primary'])
        if html:
            events = extract_content_with_gemini(html, urls['primary'], city_name)
            if events:
                for e in events:
                    upload_to_supabase(e)
                    events_found += 1
    return events_found

def main():
    total_processed = 0
    for city_name, urls in SOURCE_DICTIONARY.items():
        if city_name == "Nacional": continue
        count = process_city(city_name, urls)
        total_processed += count
    print(f"\nProceso finalizado. Total planes encontrados: {total_processed}")

if __name__ == "__main__":
    main()
