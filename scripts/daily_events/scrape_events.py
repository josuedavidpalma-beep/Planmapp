import os
import requests
from bs4 import BeautifulSoup
import google.generativeai as genai
from supabase import create_client, Client
from datetime import datetime
import json

# --- CONFIGURATION ---
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")

# Target URL (Example: SpanishDict example or an actual event site like Atrápalo)
# Note: In a real scenario, you'd target a dynamic event list. 
# For this demo, we'll simulate extracting from a text-heavy page or a known event list.
TARGET_URL = "https://www.atrapalo.com.co/entradas/bogota/" 
# Fallback/Test URL from prompt context: "https://www.spanishdict.com/translate/ejemplo" (as requested, though less useful for real events)

# Mapping categories to default images
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
        headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'}
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        return response.text
    except Exception as e:
        print(f"Error fetching URL: {e}")
        return None

def extract_events_with_gemini(html_content):
    if not GEMINI_API_KEY:
        print("Error: GEMINI_API_KEY not set.")
        return []

    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel('gemini-1.5-flash')

    # Truncate HTML to avoid token limits if extremely large, focused on body
    soup = BeautifulSoup(html_content, 'html.parser')
    text_content = soup.get_text(separator=' ', strip=True)[:30000] # Limit context

    prompt = f"""
    You are an event extraction agent. Process the following text content from a web page listing events in Colombia (Bogotá/Barranquilla, etc.).
    Extract up to 5 distinct events. 
    
    Return a STRICT JSON array where each object has these keys:
    - title: String (Event name)
    - description: String (Short summary, max 2 sentences)
    - date: String (YYYY-MM-DD or "Próximamente")
    - location: String (City/Venue)
    - category: String (One of: "music", "food", "culture", "outdoors", "party", "other")
    - source_url: String (The source URL provided below)
    - image_search_term: String (A generic search term for this event to find an image, e.g. "Jazz concert", "Burger festival")

    If no clear events are found, return an empty array [].
    
    Source Text:
    {text_content}
    """

    try:
        response = model.generate_content(prompt)
        cleaned_text = response.text.replace('```json', '').replace('```', '').strip()
        events = json.loads(cleaned_text)
        return events
    except Exception as e:
        print(f"Error parsing with Gemini: {e}")
        return []

def assign_image(event):
    # In a real production script, you might use Google Custom Search API here.
    # For this cost-effective version, we use the category default.
    category = event.get('category', 'other').lower()
    return DEFAULT_IMAGES.get(category, DEFAULT_IMAGES['other'])

def upload_to_supabase(events):
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("Error: Supabase credentials not set.")
        return

    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    count = 0
    for event in events:
        data = {
            "title": event.get('title'),
            "description": event.get('description'),
            "date": event.get('date'),
            "location": event.get('location'),
            "category": event.get('category'),
            "source_url": TARGET_URL,
            "image_url": assign_image(event),
            "created_at": datetime.utcnow().isoformat()
        }
        
        # Upsert based on title and date to avoid duplicates (assuming unique constraint or just insert)
        # Using title as a simple duplicate check for this demo
        try:
            # Check if exists
            existing = supabase.table('events').select("*").eq('title', data['title']).execute()
            if not existing.data:
                supabase.table('events').insert(data).execute()
                print(f"Uploaded: {data['title']}")
                count += 1
            else:
                print(f"Skipped (Duplicate): {data['title']}")
        except Exception as e:
            print(f"Error uploading {data['title']}: {e}")
            
    print(f"Successfully processed {count} new events.")

def main():
    print("Starting Event Scraper...")
    html = fetch_page_content(TARGET_URL)
    if html:
        print("Content fetched. analyzing with Gemini...")
        events = extract_events_with_gemini(html)
        print(f"Found {len(events)} events.")
        if events:
            upload_to_supabase(events)
        else:
            print("No events found to upload.")
    else:
        print("Failed to fetch content.")

if __name__ == "__main__":
    main()
