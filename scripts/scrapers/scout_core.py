import os
import json
import logging
import requests
from bs4 import BeautifulSoup
import google.generativeai as genai
from supabase import create_client, Client
from datetime import datetime
from urllib.parse import quote_plus

# Setup Logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Environment Variables (Set in GitHub Actions Secrets)
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

if not SUPABASE_URL or not SUPABASE_KEY or not GEMINI_API_KEY:
    logging.warning("⚠️ Ignorando inicialización de BD. Faltan variables de entorno.")

# Initialize Clients
try:
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel('gemini-2.5-flash')
except Exception as e:
    logging.error(f"Error al inicializar clientes: {e}")

def get_top_places(city: str) -> list:
    """Fetch 4.0+ star places for a given city from cached_places."""
    logging.info(f"🔍 Buscando comercios TOP en {city}...")
    try:
        response = supabase.table('cached_places').select('*').eq('city', city).gte('rating', 4.0).execute()
        return response.data
    except Exception as e:
        logging.error(f"Error fetching top places: {e}")
        return []

def get_known_events(city: str) -> list:
    """Fetch future events for a city to instruct the AI to ignore them."""
    today = datetime.now().strftime("%Y-%m-%d")
    logging.info(f"🔍 Descargando memoria de eventos futuros desde {today}...")
    try:
        response = supabase.table('local_events').select('event_name, date').eq('city', city).gte('date', today).execute()
        return response.data
    except Exception as e:
        logging.error(f"Error fetching known events: {e}")
        return []

def fetch_raw_text_about_place(place_name: str, city: str) -> str:
    """
    Realiza una busqueda superficial en internet para conseguir html de paginas oficiales.
    Nota: En una v2 usaremos la API oficial de Google Custom Search o SerpAPI.
    Aqui hacemos Request basico con un user-agent de navegador.
    """
    query = quote_plus(f"{place_name} {city} promociones eventos colombia")
    search_url = f"https://html.duckduckgo.com/html/?q={query}"
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }
    try:
        res = requests.get(search_url, headers=headers, timeout=10)
        res.raise_for_status()
        soup = BeautifulSoup(res.text, 'html.parser')
        
        # Extraemos solo el texto de los resultados de busqueda
        text_content = ' '.join([a.text for a in soup.find_all('a', class_='result__snippet')])
        return text_content
    except Exception as e:
        logging.error(f"Error parseando {place_name}: {e}")
        return ""

def process_with_gemini(raw_text: str, place: dict, known_events: list) -> list:
    """Send text to Gemini 2.5 Flash to extract JSON events."""
    if not raw_text or len(raw_text) < 20: return []
    
    known_events_str = ", ".join([e.get('event_name', '') for e in known_events])
    
    prompt = f"""
    Actúa como un agente extractor de eventos, promociones y clasificador de lugares para Planmapp. 
    Analiza este texto crudo (resultados de búsqueda en internet del local '{place['name']}' en {place.get('city', '')}).
    
    Extrae PROMOCIONES ACTIVAS O EVENTOS FUTUROS (ej. '2x1 los Jueves', 'Música en vivo este viernes', 'Descuento 20%').
    
    Instrucción de Clasificación y Deduplicación para PlanMaps:
    - Identificador Único (UID): Usa el Nombre exacto del Lugar para evitar duplicados.
    
    - Lógica de Etiquetado Exclusivo (campo vibe_tag DEBE SER EXACTAMENTE UNA DE ESTAS ETIXQUETAS):
      1. Preventa: Si venden boletas anticipadas para fechas específicas (Conciertos/Festivales).
      2. Gastronomía: Restaurantes y cafés.
      3. Vida Nocturna: Bares, discotecas. El "Validador de Contexto": Si en la info deduce que cierra después de las 2:00 AM, etiquétalo como "Vida Nocturna" aunque vendan comida.
      4. Bienestar & Deporte: Actividad física, gimnasios, spas.
      5. Cultura & Ocio: Exposiciones, teatro, cines.
      6. Aventura: Parques, caminatas, planes de naturaleza al aire libre.
      
    - Filtrado Geográfico: Valida que corresponda a {place.get('city', '')}.
    
    REGLA 1: Ignora descripciones genéricas como 'hamburguesas deliciosas'. Solo extrae OFERTAS o EVENTOS con temporalidad.
    REGLA 2: Ignora estos eventos que ya tenemos en memoria: [{known_events_str}].
    
    Devuelve estrictamente un arreglo JSON, sin backticks ni markdown, con este esquema exacto para cada evento encontrado:
    [
      {{
        "event_name": "Event/Promo title (eg. 2x1 en Cócteles)",
        "description": "Una breve descripcion atractiva...",
        "promo_highlights": "Resumen de promo (Ej. 2x1)",
        "date": "YYYY-MM-DD",
        "end_date": "YYYY-MM-DD",
        "price_range": "$$",
        "vibe_tag": "Gastronomía"
      }}
    ]
    Si no encuentras ofertas relevantes o claras, devuelve un arreglo vacío [].
    
    TEXTO CRUDO DEL LUGAR:
    {raw_text}
    """
    
    try:
        response = model.generate_content(prompt)
        text_resp = response.text.replace("```json", "").replace("```", "").strip()
        data = json.loads(text_resp)
        return data if isinstance(data, list) else []
    except Exception as e:
        logging.error(f"Gemini API Error para {place['name']}: {e}")
        return []

def safe_insert_event(city: str, place: dict, event: dict):
    """Inserts into local_events ignoring duplicates due to the DB constraints."""
    
    payload = {
        "event_name": f"{place['name']} - {event.get('event_name', 'Promo')}",
        "description": event.get('description'),
        "promo_highlights": event.get('promo_highlights'),
        "date": event.get('date'),
        "end_date": event.get('end_date'),
        "venue_name": place['name'],
        "address": place.get('address'),
        "price_range": event.get('price_range'),
        "primary_source": "Planmapp Smart Scout (AI)",
        "image_url": place.get('photo_reference', ''), # Re-use Maps 360 Photo
        "city": city,
        "vibe_tag": event.get('vibe_tag', 'Oferta'),
        "latitude": place.get('latitude'),
        "longitude": place.get('longitude'),
        "place_id": place.get('place_id')
    }
    
    try:
        supabase.table("local_events").insert(payload).execute()
        logging.info(f"✅ Inyectado exitosamente: {payload['event_name']}")
    except Exception as e:
        # Supabase duplicate error usually raises an exception. We ignore it safely.
        if 'duplicate key value violates unique constraint' in str(e):
            logging.info(f"🔄 Ya existe en BD (Evitado): {payload['event_name']}")
        else:
            logging.error(f"❌ Fallo al insertar {payload['event_name']}: {e}")
