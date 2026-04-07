import os
import requests
from bs4 import BeautifulSoup
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
        "primary": "https://www.barranquilla.gov.co/eventos",
        "secondary": "https://www.elheraldo.co/entretenimiento"
    },
    "Cartagena": {
        "primary": "https://www.cartagena.gov.co/eventos",
        "secondary": "https://www.eluniversal.com.co/cultural"
    },
    "Santa Marta": {
        "primary": "https://www.santamarta.gov.co/sala-prensa/noticias",
        "secondary": "https://santamartacultural.com"
    },
    "Riohacha": {
        "primary": "https://www.laguajira.gov.co/atencion-al-ciudadano/agenda-de-eventos",
        "secondary": None
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
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
            'Sec-Fetch-Dest': 'document',
            'Sec-Fetch-Mode': 'navigate',
            'Sec-Fetch-Site': 'none'
        }
        # Disable SSL verification for known problematic sites
        verify_ssl = True
        if "donde.com.co" in url or "hoydiariodelmagdalena" in url or "santamarta.gov.co" in url:
            verify_ssl = False
        
        response = requests.get(url, headers=headers, timeout=20, verify=verify_ssl)
        
        # Check for 404 or common error titles in HTML
        if response.status_code == 404:
            print(f"[ALERT] 404 Not Found for {url}.")
            return None
            
        content = response.text
        if "404 Not Found" in content or "Página no encontrada" in content:
            print(f"[ALERT] Error-like content detected in {url}. Skipping Gemini.")
            return None

        response.raise_for_status()
        return content
    except Exception as e:
        print(f"Error fetching URL {url}: {e}")
        return None

def extract_content_with_gemini(html_content, source_url, city_name, is_national_fallback=False):
    if not GEMINI_API_KEY:
        print("Error: GEMINI_API_KEY not set.")
        return None

    from urllib.parse import urljoin
    soup = BeautifulSoup(html_content, 'html.parser')
    
    # Remove useless elements
    for script in soup(["script", "style", "nav", "footer", "header"]):
        script.extract()
        
    # Append URLs to links and images
    for a in soup.find_all('a', href=True):
        href = a['href']
        if href.startswith('http'):
            if a.string: a.string = f"{a.string} (URL: {href})"
        elif href.startswith('/'):
            if a.string: a.string = f"{a.string} (URL: {urljoin(source_url, href)})"
            
    for img in soup.find_all('img', src=True):
        src = img['src']
        if src.startswith('http'):
            img.replace_with(f" [Image: {src}] ")
        elif src.startswith('/'):
            img.replace_with(f" [Image: {urljoin(source_url, src)}] ")

    text_content = soup.get_text(separator=' ', strip=True)[:45000] # Increased context limit for Gemini Flash

    instruction = f"Extract events for {city_name}."
    if is_national_fallback:
        instruction = f"Extract only events specifically located in {city_name}. Ignore others."

    prompt = f"""
    You are an event extraction agent. {instruction}
    
    CRITICAL: If the text says '404', 'Not Found', 'Página no encontrada' or seems to be an error page, return an empty array [].
    
    Return a STRICT JSON ARRAY of objects (min 1, max 2 most relevant).
    Field Mapping:
    - title: (String) Name of event
    - start_date: (String) ISO YYYY-MM-DD or Date description
    - end_date: (String, Optional) YYYY-MM-DD (or null)
    - city: (String) "{city_name}"
    - address: (String, Optional) Complete physical address
    - location_name: (String) Venue name
    - description: (String) Brief summary (Max 3 lines, Spanish)
    - category: (String) One of: "music", "culture", "outdoors", "party", "food", "other"
    - image_url: (String) Absolute URL to poster image starting with http. Extracted from [Image: ...] tags next to the event. If none, return null.
    - source_url: (String) Absolute URL to the event page or registration. Extracted from (URL: ...) tags.
    - contact_info: (String, Optional) Phone, email, or instagram handle.
    
    Source Text:
    {text_content}
    """

    try:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={GEMINI_API_KEY}"
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "safetySettings": [
                {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
                {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"}
            ]
        }
        
        json_data = {}
        max_retries = 3
        base_delay = 5
        
        for attempt in range(max_retries):
            try:
                http_response = requests.post(url, json=payload, headers={"Content-Type": "application/json"})
                if http_response.status_code == 429:
                    # Parse retryDelay from Google JSON or fallback to Exponential Backoff
                    retry_delay_str = http_response.json().get('error', {}).get('details', [{}])[0].get('retryDelay', '')
                    if retry_delay_str and retry_delay_str.endswith('s'):
                        wait_time = float(retry_delay_str[:-1]) + 2
                    else:
                        wait_time = base_delay * (2 ** attempt)
                        
                    print(f"[429 Rate Limit] Gemini API Limit reached. Backoff {wait_time}s... (Attempt {attempt+1}/{max_retries})")
                    time.sleep(wait_time)
                    continue
                    
                if http_response.status_code != 200:
                    print(f"Error HTTP {http_response.status_code}: {http_response.text}")
                    return []
                    
                json_data = http_response.json()
                break # Success!
                
            except Exception as e:
                print(f"Exception during Gemini Request: {e}")
                if attempt == max_retries - 1: return []
                time.sleep(base_delay)
        else:
            print("Max API retries exceeded for Gemini.")
            return []

        raw_text = json_data.get('candidates', [{}])[0].get('content', {}).get('parts', [{}])[0].get('text', '')
        
        cleaned_text = raw_text.replace('```json', '').replace('```', '').strip()
        
        # Handle potential single object vs list
        if cleaned_text.startswith('{'):
            cleaned_text = f"[{cleaned_text}]"
            
        events = json.loads(cleaned_text)
        
        valid_events = []
        for e in events:
            import urllib.parse
            title = e.get('title', 'diversion')
            encoded_title = urllib.parse.quote(f"Cartel espectacular para evento de {title} en {city_name} Colombia")
            pollinations_url = f"https://image.pollinations.ai/prompt/{encoded_title}?width=800&height=600&nologo=true"

            # Map Python dict keys to Supabase columns (normalization)
            normalized = {
                "title": e.get('title'),
                "description": e.get('description'),
                "date": e.get('start_date'), 
                "end_date": e.get('end_date'),
                "location": e.get('location_name'),
                "address": e.get('address'),
                "category": e.get('category', 'other'),
                "image_url": e.get('image_url') or pollinations_url,
                "source_url": e.get('source_url') or source_url, 
                "city": city_name,
                "contact_info": e.get('contact_info')
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
    combined_html = ""
    
    # 1. Fetch Primary & Secondary and Batch them together
    if urls.get('primary'):
        print(f"Fetching Primary: {urls['primary']}")
        html = fetch_page_content(urls['primary'])
        if html: combined_html += f"\n--- Source: {urls['primary']} ---\n{html}"
    
    if urls.get('secondary'):
        print(f"Fetching Secondary: {urls['secondary']}")
        html = fetch_page_content(urls['secondary'])
        if html: combined_html += f"\n--- Source: {urls['secondary']} ---\n{html}"
        
    # 2. Extract context via Gemini using Batch Payload (1 request instead of 2)
    if combined_html:
        source_url = urls.get('primary') or urls.get('secondary')
        events = extract_content_with_gemini(combined_html, source_url, city_name)
        if events:
            print(f"Found {len(events)} events from Local sources in batched request.")
            for e in events:
                upload_to_supabase(e)
                events_found += 1
                if events_found >= 4: break # Max limit per batch to avoid flooding

    # 3. Fallback to National if 0 events found
    if events_found == 0:
        print(f"No events found locally. Falling back to National Sources for {city_name}...")
        
        # Try Eventbrite (National Primary) dynamically mapped to the specific City
        # Eventbrite uses hyphenation for spaces in URLs
        formatted_city = city_name.lower().replace(' ', '-')
        nat_url = f"https://www.eventbrite.co/d/colombia--{formatted_city}/events/"
        
        print(f"Querying custom National Fallback: {nat_url}")
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
        
        # Free Tier Rate Limiting Prevention
        print(f"Waiting 15 seconds to respect Gemini API rate limits...")
        time.sleep(15)

    print(f"\nFinished. Total events processed: {total_processed}")

from flask import Flask, jsonify
import threading

app = Flask(__name__)
scrape_lock = threading.Lock()

@app.route('/')
def home():
    return jsonify({
        "status": "online",
        "message": "PlanMaps Scraper Web Service is running."
    }), 200

@app.route('/scrape', methods=['GET', 'POST'])
def trigger_scrape():
    # Attempt to acquire lock without blocking to prevent concurrent scraping crashes
    if not scrape_lock.acquire(blocking=False):
        return jsonify({
            "status": "conflict",
            "message": "Scraper is already running. Please wait for it to finish."
        }), 409

    def run_with_lock():
        try:
            main()
        finally:
            scrape_lock.release()

    # Run the scraper in a background thread to prevent HTTP timeouts
    thread = threading.Thread(target=run_with_lock)
    thread.start()
    return jsonify({
        "status": "started",
        "message": "Scraping process triggered in the background. Concurrency locked."
    }), 202

if __name__ == "__main__":
    # If run locally or on Render, check for PORT env variable
    port = int(os.environ.get("PORT", 10000))
    app.run(host="0.0.0.0", port=port)
