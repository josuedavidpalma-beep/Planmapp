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

# --- SOURCE DICTIONARY ---
SOURCE_DICTIONARY = {
    "Nacional": {
        "primary": "https://www.eventbrite.co/d/colombia/events/",
        "secondary": "https://www.tuboleta.com"
    },
    "Barranquilla": {
        "primary": "https://baqucultura.com/",
        "secondary": "https://www.elheraldo.co/entretenimiento"
    },
    "Cartagena": {
        "primary": "https://www.donde.com.co/es/cartagena/agenda",
        "secondary": "https://www.eluniversal.com.co/cultural"
    },
    "Santa Marta": {
        "primary": "https://www.santamarta.gov.co/agenda-eventos",
        "secondary": "https://www.hoydiariodelmagdalena.com.co/"
    },
    "Riohacha": {
        "primary": "https://www.laguajira.gov.co/atencion-al-ciudadano/agenda-de-eventos",
        "secondary": None # No secondary provided
    },
    "Cali": {
        "primary": "https://www.cali.gov.co/cultura/publicaciones/154517/agenda-cultural-de-cali/",
        "secondary": "https://elpais.com.co/entretenimiento"
    },
    "Medellín": {
        "primary": "https://www.medellin.gov.co/es/eventos/",
        "secondary": None
    },
    "Pereira": {
        "primary": "https://www.pereira.gov.co/agenda-cultural",
        "secondary": "https://www.eldiario.com.co/seccion/sociales/"
    },
    "Bogotá": {
        "primary": "https://www.idartes.gov.co/es/agenda",
        "secondary": None
    }
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
        
        if response.status_code == 404:
            print(f"[ALERT] 404 Not Found for {url}. The structure might have changed.")
            return None
            
        response.raise_for_status()
        return response.text
    except Exception as e:
        print(f"Error fetching URL {url}: {e}")
        return None

def extract_content_with_gemini(html_content, source_url, city_name, is_national_fallback=False):
    if not GEMINI_API_KEY:
        print("Error: GEMINI_API_KEY not set.")
        return None

    genai.configure(api_key=GEMINI_API_KEY)
    try:
        model = genai.GenerativeModel('gemini-1.5-flash-latest')
    except:
        model = genai.GenerativeModel('gemini-pro')

    soup = BeautifulSoup(html_content, 'html.parser')
    text_content = soup.get_text(separator=' ', strip=True)[:20000]

    instruction = f"Extract events for {city_name}."
    if is_national_fallback:
        instruction = f"Extract only events specifically located in {city_name}. Ignore others."

    prompt = f"""
    You are an event extraction agent. {instruction}
    
    Return a STRICT JSON ARRAY of objects (min 1, max 5 most relevant).
    Field Mapping:
    - title: (String) Name of event
    - date_start: (String) ISO 8601 or YYYY-MM-DD HH:MM
    - city: (String) "{city_name}"
    - location_name: (String) Venue name
    - description: (String) Brief summary (Max 3 lines, Spanish)
    - category: (String) One of: "music", "culture", "outdoors", "party", "food", "other"
    - image_url: (String) URL to poster image. If none found, return null.
    - event_link: (String) Detailed link to the event.
    
    Source Text:
    {text_content}
    """

    try:
        response = model.generate_content(prompt)
        cleaned_text = response.text.replace('```json', '').replace('```', '').strip()
        
        # Handle potential single object vs list
        if cleaned_text.startswith('{'):
            cleaned_text = f"[{cleaned_text}]"
            
        events = json.loads(cleaned_text)
        
        valid_events = []
        for e in events:
            # Map Python dict keys to Supabase columns (normalization)
            normalized = {
                "title": e.get('title'),
                "description": e.get('description'),
                "date": e.get('date_start'), # Mapped date_start -> date
                "location": e.get('location_name'), # Mapped location_name -> location
                "category": e.get('category', 'other'),
                "image_url": e.get('image_url') if e.get('image_url') else DEFAULT_IMAGES.get(e.get('category'), DEFAULT_IMAGES['other']),
                "source_url": e.get('event_link', source_url), # Mapped event_link -> source_url
                "city": city_name,
                "address": e.get('location_name'), # Default address to location name if missing
                "contact_info": "" 
            }
            valid_events.append(normalized)
            
        return valid_events
    except Exception as e:
        print(f"Error parsing with Gemini: {e}")
        return []

def upload_to_supabase(event_data):
    if not SUPABASE_URL or not SUPABASE_KEY: return

    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    # Fallback date if missing
    if not event_data.get('date'):
         event_data['date'] = datetime.now().strftime("%Y-%m-%d")

    try:
        data = {
            "title": event_data.get('title'),
            "description": event_data.get('description'),
            "date": event_data.get('date'),
            "end_date": event_data.get('date'), # Default end same as start
            "location": event_data.get('location'),
            "address": event_data.get('address'),
            "category": event_data.get('category').lower() if event_data.get('category') else 'other',
            "image_url": event_data.get('image_url'),
            "source_url": event_data.get('source_url'),
            "contact_info": event_data.get('contact_info'),
            "city": event_data.get('city'),
            "created_at": datetime.utcnow().isoformat()
        }

        # Check dupes
        existing = supabase.table('events').select("*").eq('title', data['title']).execute()
        if not existing.data:
            supabase.table('events').insert(data).execute()
            print(f"Uploaded: {data['title']} ({data['city']})")
        else:
            print(f"Skipped (Duplicate): {data['title']}")
            
    except Exception as e:
        print(f"Error uploading {event_data.get('title')}: {e}")

def process_city(city_name, urls):
    print(f"\n--- Processing {city_name} ---")
    events_found = 0
    
    # 1. Try Primary
    if urls.get('primary'):
        print(f"Trying Primary: {urls['primary']}")
        html = fetch_page_content(urls['primary'])
        if html:
            events = extract_content_with_gemini(html, urls['primary'], city_name)
            if events:
                print(f"Found {len(events)} events from Primary.")
                for e in events:
                    upload_to_supabase(e)
                    events_found += 1
    
    # 2. Try Secondary if needed (or minimal results)
    if events_found < 3 and urls.get('secondary'):
        print(f"Trying Secondary: {urls['secondary']}")
        html = fetch_page_content(urls['secondary'])
        if html:
            events = extract_content_with_gemini(html, urls['secondary'], city_name)
            if events:
                 print(f"Found {len(events)} events from Secondary.")
                 for e in events:
                    upload_to_supabase(e)
                    events_found += 1

    # 3. Fallback to National if 0 events found
    if events_found == 0:
        print(f"No events found locally. Falling back to National Sources for {city_name}...")
        
        # Try Eventbrite (National Primary)
        nat_url = NATIONAL_SOURCES['primary'] # e.g. Eventbrite
        # Note: In a real scraper, we might construct a search query URL like eventbrite.co/d/{city}/events
        # For now, we scrape the main national page and ask Gemini to filter by City Name.
        
        html = fetch_page_content(nat_url)
        if html:
            events = extract_content_with_gemini(html, nat_url, city_name, is_national_fallback=True)
            if events:
                 print(f"Found {len(events)} events from National Source.")
                 for e in events:
                    upload_to_supabase(e)
                    events_found += 1
    
    return events_found

def main():
    print("Starting Multi-City Scraper with Source Dictionary...")
    total_processed = 0
    
    for city_name, urls in SOURCE_DICTIONARY.items():
        if city_name == "Nacional": continue # Skip config entry
        
        count = process_city(city_name, urls)
        total_processed += count

    print(f"\nFinished. Total events processed: {total_processed}")

if __name__ == "__main__":
    main()
