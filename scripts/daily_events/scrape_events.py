import os
import requests
from bs4 import BeautifulSoup
import google.generativeai as genai
from supabase import create_client, Client
from datetime import datetime, timedelta
import json
import time
from flask import Flask, jsonify
import threading

# --- CONFIGURATION ---
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")

# --- SOURCE DICTIONARY (Mejorado: Ciudades del backup + Enlaces de Main) ---
SOURCE_DICTIONARY = {
    "Nacional": {
        "primary": "https://www.eventbrite.co/d/colombia/events/",
        "secondary": "https://www.tuboleta.com"
    },
    "Barranquilla": {
        "primary": "https://baqucultura.com/calendario/", 
        "secondary": "https://www.elheraldo.co/entretenimiento" 
    },
    "Cartagena": {
        "primary": "https://www.donde.com.co/es/cartagena/agenda",
        "secondary": "https://www.eluniversal.com.co/cultural"
    },
    "Santa Marta": {
        "primary": "https://www.santamarta.gov.co/agenda-eventos",
        "secondary": "https://www.hoydiariodelmagdalena.com.co/category/sociales/"
    },
    "Cali": {
        "primary": "https://www.cali.gov.co/cultura/publicaciones/154517/agenda-cultural-de-cali/",
        "secondary": "https://elpais.com.co/entretenimiento"
    },
    "Medellín": {
        "primary": "https://www.medellin.gov.co/es/eventos/",
        "secondary": None
    }
}

CATEGORY_IMAGES = {
    "music": ["https://images.unsplash.com/photo-1540039155732-d674d6e3f0be?auto=format&fit=crop&q=80&w=800"],
    "culture": ["https://images.unsplash.com/photo-1533174072545-e8d4aa97edf9?auto=format&fit=crop&q=80&w=800"],
    "food": ["https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&q=80&w=800"],
    "party": ["https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&q=80&w=800"],
    "outdoors": ["https://images.unsplash.com/photo-1502086223501-681a91cc44e7?auto=format&fit=crop&q=80&w=800"],
    "other": ["https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&q=80&w=800"]
}

def fetch_page_content(url):
    try:
        headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'}
        verify_ssl = False if any(x in url for x in ["donde.com.co", "hoydiariodelmagdalena", "santamarta.gov.co"]) else True
        response = requests.get(url, headers=headers, timeout=20, verify=verify_ssl)
        if response.status_code == 404: return None
        return response.text
    except Exception as e:
        print(f"Error fetching URL {url}: {e}")
        return None

def extract_content_with_gemini(html_content, source_url, city_name):
    if not GEMINI_API_KEY: return []
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel('gemini-1.5-flash')
    
    soup = BeautifulSoup(html_content, 'html.parser')
    for script in soup(["script", "style", "nav", "footer"]): script.extract()
    text_content = soup.get_text(separator=' ', strip=True)[:30000]

    prompt = f"""
    Eres un agente experto en encontrar PLANES y PROMOCIONES en {city_name}.
    Prioridad: 2x1, Happy Hour, Descuentos, Comida y Fútbol (solo como plan en bares).
    Ignora: Noticias de crímenes, política o resultados deportivos.
    Return STRICT JSON ARRAY (max 5). 
    Fields: title, date_start, location_name, description, category, image_url, event_link.
    Source: {text_content}
    """

    try:
        response = model.generate_content(prompt)
        cleaned_text = response.text.replace('```json', '').replace('```', '').strip()
        events = json.loads(cleaned_text)
        valid_events = []
        for e in events:
            import random
            cat = e.get('category', 'other')
            valid_events.append({
                "title": e.get('title'),
                "description": e.get('description'),
                "date": e.get('date_start') or datetime.now().strftime("%Y-%m-%d"),
                "location": e.get('location_name'),
                "category": cat,
                "image_url": e.get('image_url') or random.choice(CATEGORY_IMAGES.get(cat, CATEGORY_IMAGES['other'])),
                "source_url": e.get('event_link') or source_url,
                "city": city_name,
                "address": e.get('location_name'),
                "contact_info": ""
            })
        return valid_events
    except Exception as e:
        print(f"Error Gemini: {e}")
        return []

def upload_to_supabase(event_data):
    if not SUPABASE_URL or not SUPABASE_KEY: return
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    try:
        existing = supabase.table('events').select("*").eq('title', event_data['title']).execute()
        if not existing.data:
            supabase.table('events').insert(event_data).execute()
            print(f"Subido: {event_data['title']}")
    except Exception as e: print(f"Error Supabase: {e}")

def process_city(city_name, urls):
    print(f"\n--- Buscando en {city_name} ---")
    html = fetch_page_content(urls['primary'])
    if html:
        events = extract_content_with_gemini(html, urls['primary'], city_name)
        for e in events: upload_to_supabase(e)
        return len(events)
    return 0

def main_scrape():
    for city, urls in SOURCE_DICTIONARY.items():
        if city == "Nacional": continue
        process_city(city, urls)
        time.sleep(5) # Evita bloqueos de API

# --- WEB SERVICE (De tu Backup para Render) ---
app = Flask(__name__)
scrape_lock = threading.Lock()

@app.route('/')
def home(): return jsonify({"status": "online"}), 200

@app.route('/scrape', methods=['GET', 'POST'])
def trigger_scrape():
    if not scrape_lock.acquire(blocking=False): return jsonify({"status": "busy"}), 409
    def run():
        try: main_scrape()
        finally: scrape_lock.release()
    threading.Thread(target=run).start()
    return jsonify({"status": "started"}), 202

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    app.run(host="0.0.0.0", port=port)