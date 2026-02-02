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

TARGET_URL = "https://www.idartes.gov.co/es/agenda"

# Mapping categories to default images (Fallback)
DEFAULT_IMAGES = {
    "music": "https://images.unsplash.com/photo-1514525253440-b393452e8d26?auto=format&fit=crop&q=80&w=800",
    "food": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&q=80&w=800",
    "culture": "https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?auto=format&fit=crop&q=80&w=800",
    "outdoors": "https://images.unsplash.com/photo-1501555088652-021faa106b9b?auto=format&fit=crop&q=80&w=800",
    "party": "https://images.unsplash.com/photo-1566737236500-c8ac43014a67?auto=format&fit=crop&q=80&w=800",
    "other": "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&q=80&w=800"
}

def fetch_page_content(url):
    try:
        headers = {'User-Agent': 'Mozilla/5.0'}
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        return response.text
    except Exception as e:
        print(f"Error fetching URL {url}: {e}")
        return None

def extract_event_links(html_content):
    soup = BeautifulSoup(html_content, 'html.parser')
    links = set()
    
    # Logic for Idartes: Find links that look like event pages
    # Usually: /es/agenda/category/slug
    for a in soup.find_all('a', href=True):
        href = a['href']
        if '/es/agenda/' in href and not any(x in href for x in ['type:', 'ctg:', 'page=', '?']):
            full_url = "https://www.idartes.gov.co" + href if href.startswith('/') else href
            links.add(full_url)
            
    return list(links)[:10] # Limit to top 10 to avoid timeouts

def extract_event_details_with_gemini(html_content, source_url):
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

    prompt = f"""
    You are an event extraction agent. Extract details for a SINGLE event from the text below.
    
    Return a STRICT JSON object with these keys:
    - title: String
    - description: String (Max 3 lines, Spanish)
    - date: String (Start Date YYYY-MM-DD. If range, use start date. If "Permanent" use today)
    - end_date: String (End Date YYYY-MM-DD. If one day, same as date. If permanent, put date + 1 year)
    - location: String (Venue Name)
    - address: String (Physical Address if found, else null)
    - category: String ("music", "culture", "outdoors", "party", "food", "other")
    - image_url: String (Find a URL ending in jpg/png in text if possible, else null)
    - contact_info: String (Phone or Email if found, else null)

    If the text is not about an event, return null.

    Source Text:
    {text_content}
    """

    try:
        response = model.generate_content(prompt)
        cleaned_text = response.text.replace('```json', '').replace('```', '').strip()
        event_data = json.loads(cleaned_text)
        if event_data:
            event_data['source_url'] = source_url
            if not event_data.get('category'): event_data['category'] = 'other'
            if not event_data.get('image_url'): 
                event_data['image_url'] = DEFAULT_IMAGES.get(event_data['category'], DEFAULT_IMAGES['other'])
                
        return event_data
    except Exception as e:
        print(f"Error parsing detail with Gemini: {e}")
        return None

def upload_to_supabase(event_data):
    if not SUPABASE_URL or not SUPABASE_KEY: return

    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    # Check expiry
    today = datetime.now().strftime("%Y-%m-%d")
    end_date = event_data.get('end_date') or event_data.get('date')
    if end_date and end_date < today:
        print(f"Skipping expired event: {event_data['title']}")
        return

    try:
        data = {
            "title": event_data.get('title'),
            "description": event_data.get('description'),
            "date": event_data.get('date'),
            "end_date": end_date,
            "location": event_data.get('location'),
            "address": event_data.get('address'),
            "category": event_data.get('category'),
            "image_url": event_data.get('image_url'),
            "source_url": event_data.get('source_url'),
            "contact_info": event_data.get('contact_info'),
            "created_at": datetime.utcnow().isoformat()
        }

        # Upsert
        existing = supabase.table('events').select("*").eq('title', data['title']).execute()
        if not existing.data:
            supabase.table('events').insert(data).execute()
            print(f"Uploaded: {data['title']}")
        else:
            print(f"Skipped (Duplicate): {data['title']}")
            
    except Exception as e:
        print(f"Error uploading {event_data.get('title')}: {e}")

def main():
    print("Starting Idartes Scraper...")
    main_html = fetch_page_content(TARGET_URL)
    if not main_html: return

    links = extract_event_links(main_html)
    print(f"Found {len(links)} potential event links.")
    
    count = 0
    for link in links:
        print(f"Scraping detailed view: {link}")
        detail_html = fetch_page_content(link)
        if detail_html:
            event = extract_event_details_with_gemini(detail_html, link)
            if event:
                upload_to_supabase(event)
                count += 1
            time.sleep(1) # Be polite
            
    print(f"Finished. Processed {count} events.")
    
    # Failsafe if 0
    if count == 0:
        print("Injecting fallback event...")
        fallback = {
            "title": "Agenda Cultural Bogotá (Idartes)",
            "description": "Explora la programación oficial de Idartes. No pudimos extraer eventos específicos, pero visita el sitio oficial.",
            "date": datetime.now().strftime("%Y-%m-%d"),
            "end_date": datetime.now().strftime("%Y-%m-%d"),
            "location": "Bogotá D.C.",
            "address": "Calle 8 # 8-52 (Ejemplo)",
            "category": "culture",
            "image_url": DEFAULT_IMAGES['culture'],
            "source_url": TARGET_URL,
            "contact_info": "contactenos@idartes.gov.co"
        }
        upload_to_supabase(fallback)

if __name__ == "__main__":
    main()
