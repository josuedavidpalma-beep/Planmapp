"""
PLANMAPP RESEARCH AGENT v2.0
==============================
Motor: Tavily (búsqueda web) + Gemini 1.5 Flash (extracción/limpieza) + Google Places (geocoding)
Cron: Diario a las 10:00 UTC (05:00 Colombia)
Fuentes: Web abierta via Tavily – busca eventos, restaurantes, cultura y rumba por ciudad
"""

import os
import json
import time
import threading
import random
from datetime import datetime, timedelta

import google.generativeai as genai
from supabase import create_client, Client
from flask import Flask, jsonify, request
try:
    from flask_cors import CORS
except ImportError:
    # If not installed yet, just a dummy no-op
    pass

# ─── Librerías opcionales (no fallan si no están instaladas) ──────────────────
try:
    from tavily import TavilyClient
    HAS_TAVILY = True
except ImportError:
    HAS_TAVILY = False
    print("⚠️  tavily-python no instalado. Instala: pip install tavily-python")

try:
    import requests as _requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False

# ─── Configuración ─────────────────────────────────────────────────────────────
TAVILY_API_KEY        = os.environ.get("TAVILY_API_KEY")
GEMINI_API_KEY        = os.environ.get("GEMINI_API_KEY")
SUPABASE_URL          = os.environ.get("SUPABASE_URL")
SUPABASE_KEY          = os.environ.get("SUPABASE_KEY")          # service_role key
GOOGLE_PLACES_API_KEY = os.environ.get("GOOGLE_PLACES_API_KEY")

# ─── Ciudades y categorías objetivo ────────────────────────────────────────────
CITIES = ["Bogotá", "Medellín", "Cali", "Barranquilla", "Cartagena", "Santa Marta", "Bucaramanga", "Pereira", "Manizales", "Armenia", "Villavicencio", "Cúcuta"]

CATEGORIES = [
    {"key": "food", "label": "Restaurantes y Cenas", "query_hint": "restaurantes especiales, cenas románticas, comida internacional, gastronomía local"},
    {"key": "food", "label": "Promos y Comida Rápida", "query_hint": "happy hour comida, 2x1 en comida, hamburguesería, pizzería, tacos"},
    {"key": "food", "label": "Cafés y Brunch", "query_hint": "cafeterías de especialidad, brunch de fin de semana, postres"},
    {"key": "party", "label": "Rumba y Bares", "query_hint": "bares de moda, fiestas, discotecas, eventos nocturnos"},
    {"key": "party", "label": "Conciertos", "query_hint": "conciertos de música, música en vivo, festivales de música, toques de bandas"},
    {"key": "party", "label": "Cervecerías y Pubs", "query_hint": "cerveza artesanal, pubs, bares deportivos, happy hour licores"},
    {"key": "culture", "label": "Arte y Museos", "query_hint": "museos, galerías de arte, exposiciones, recorridos históricos"},
    {"key": "culture", "label": "Teatro y Comedia", "query_hint": "obras de teatro, stand up comedy, monólogos, shows en vivo"},
    {"key": "culture", "label": "Cine y Festivales", "query_hint": "cine independiente, festivales de cine, ferias culturales"},
    {"key": "outdoors", "label": "Naturaleza", "query_hint": "senderismo, caminatas, parques naturales"},
    {"key": "outdoors", "label": "Deportes Extremos y Agua", "query_hint": "deportes acuáticos, playas, cuatrimotos, parapente"},
    {"key": "outdoors", "label": "Pueblear y Paseos", "query_hint": "pueblitos cercanos, escapadas de fin de semana, miradores turísticos"},
]

# ─── Imágenes de Respaldo por Categoría (Unsplash Premium) ───────────────────
# Usamos URLs absolutas para evitar la API deprecada source.unsplash.com
import random
FALLBACK_IMAGES = {
    "food": [
        "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1544148103-0773bf10d330?auto=format&fit=crop&w=800&q=80",
    ],
    "party": [
        "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1545128485-c400e7702796?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=800&q=80",
    ],
    "culture": [
        "https://images.unsplash.com/photo-1536440136628-849c177e76a1?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1518998053401-b25431cb0272?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1582555172866-f73bb12a2ab3?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?auto=format&fit=crop&w=800&q=80",
    ],
    "outdoors": [
        "https://images.unsplash.com/photo-1501504905252-473c47e087f8?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1519331379826-f947873d63bd?auto=format&fit=crop&w=800&q=80",
    ]
}

# ─── Paso 1: Búsqueda con Tavily ───────────────────────────────────────────────
def search_with_tavily(city: str, category: dict) -> list[dict]:
    """Usa Tavily para buscar eventos/lugares reales en la web."""
    if not HAS_TAVILY or not TAVILY_API_KEY:
        print(f"  [TAVILY] API Key no configurada. Saltando.")
        return []

    client = TavilyClient(api_key=TAVILY_API_KEY)
    today = datetime.now().strftime("%B %Y")  # ej. "April 2026"
    query = (
        f"planes y eventos {category['label']} en {city} Colombia {today}. "
        f"{category['query_hint']}"
    )
    print(f"  [TAVILY] Buscando: {query[:80]}...")
    try:
        response = client.search(
            query=query,
            search_depth="advanced",
            max_results=7,
            include_raw_content=False,
        )
        return response.get("results", [])
    except Exception as e:
        print(f"  [TAVILY] Error: {e}")
        return []


# ─── Paso 2: Extracción con Gemini ─────────────────────────────────────────────
def extract_events_with_gemini(results: list[dict], city: str, category: dict) -> list[dict]:
    """Usa Gemini para limpiar los snippets de Tavily y extraer eventos estructurados."""
    if not GEMINI_API_KEY or not results:
        return []

    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel("gemini-2.5-flash")

    # Formatear los snippets de Tavily para el prompt
    snippets_text = ""
    for i, r in enumerate(results):
        snippets_text += f"\n--- Resultado {i+1} ---\n"
        snippets_text += f"URL: {r.get('url', '')}\n"
        snippets_text += f"Título: {r.get('title', '')}\n"
        snippets_text += f"Contenido: {r.get('content', '')[:500]}\n"

    today_str = datetime.now().strftime("%Y-%m-%d")
    prompt = f"""
Eres un agente experto en planes y eventos para la app Planmapp en Colombia.
Analiza los siguientes resultados de búsqueda sobre la categoría "{category['label']}" en {city}.

INSTRUCCIONES:
- Extrae máximo 4 eventos/planes/lugares reales y concretos
- Si hay Happy Hour, 2x1, descuentos o promociones: priorízalos
- Ignora noticias de política, crímenes o deportes puros
- Si el evento ya pasó (antes de {today_str}), ignóralo
- Si no hay fecha clara, usa null para date_start

Escribe un reporte estilo periodístico atractivo detallando "Cuándo", "Dónde", "Qué promociones existen", costo si se menciona, y si se requiere reserva.
Devuelve ÚNICAMENTE un JSON array válido (sin markdown, sin explicación):
[
  {{
    "title": "Nombre del evento/lugar",
    "description": "Párrafo completo descriptivo: ¿De qué trata? ¿A qué hora? ¿Qué promos hay (2x1, happy hour)?",
    "date_start": "YYYY-MM-DD o null",
    "location_name": "Nombre exacto del lugar o teatro",
    "address": "Dirección si está disponible o null",
    "category": "{category['key']}",
    "source_url": "URL del resultado",
    "image_url": null,
    "contact_info": "Número de teléfono o web encontrado en el texto (o null)"
  }}
]

Resultados a analizar:
{snippets_text}
"""

    try:
        response = model.generate_content(prompt)
        raw = response.text.strip()
        # Limpiar posibles bloques de código markdown
        if raw.startswith("```"):
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        events = json.loads(raw.strip())
        if not isinstance(events, list):
            return []
        return events
    except Exception as e:
        print(f"  [GEMINI] Error al extraer: {e}")
        return []


# ─── Paso 3: Geocodificación con Google Places ─────────────────────────────────
def geocode_with_google_places(location_name: str, address: str, city: str) -> dict | None:
    """Busca coordenadas, rating y foto con Google Places Text Search."""
    if not GOOGLE_PLACES_API_KEY or not HAS_REQUESTS:
        return None

    query = f"{address or location_name}, {city}, Colombia"
    url = "https://maps.googleapis.com/maps/api/place/textsearch/json"
    params = {
        "query": query,
        "key": GOOGLE_PLACES_API_KEY,
        "language": "es",
        "region": "co",
    }

    try:
        resp = _requests.get(url, params=params, timeout=10)
        data = resp.json()
        if data.get("status") != "OK" or not data.get("results"):
            return None

        place = data["results"][0]
        loc = place.get("geometry", {}).get("location", {})
        photo_ref = None
        if place.get("photos"):
            photo_ref = place["photos"][0].get("photo_reference")

        image_url = None
        if photo_ref:
            image_url = (
                f"https://maps.googleapis.com/maps/api/place/photo"
                f"?maxwidth=800&photo_reference={photo_ref}&key={GOOGLE_PLACES_API_KEY}"
            )

        return {
            "google_place_id": place.get("place_id"),
            "latitude": loc.get("lat"),
            "longitude": loc.get("lng"),
            "rating_google": place.get("rating"),
            "user_ratings_total": place.get("user_ratings_total"),
            "google_image_url": image_url,
        }
        
        # Second Query: Get Details (Phone/Website) using Place ID. Non-blocking if fails.
        try:
            d_url = "https://maps.googleapis.com/maps/api/place/details/json"
            d_params = {
                "place_id": place.get("place_id"),
                "fields": "formatted_phone_number,website",
                "key": GOOGLE_PLACES_API_KEY,
                "language": "es"
            }
            d_resp = _requests.get(d_url, params=d_params, timeout=5)
            d_data = d_resp.json()
            if d_data.get("status") == "OK":
                res = d_data.get("result", {})
                contact = res.get("formatted_phone_number")
                if not contact:
                    contact = res.get("website")
                if contact:
                    ret["contact_info"] = contact
        except Exception:
            pass # Ignore details fail

        return ret
    except Exception as e:
        print(f"  [PLACES] Error geocodificando '{query}': {e}")
        return None


# ─── Paso 4: Upsert a Supabase ────────────────────────────────────────────────
def upsert_event(supabase: Client, event: dict, city: str, category: dict, geo: dict | None):
    """Inserta o actualiza un evento en Supabase usando source_url como clave única."""
    if not event.get("title") or not event.get("source_url"):
        return

    # Determinación Inteligente de Imagen
    # 1. Foto original (si existe)
    image_url = event.get("image_url")
    
    # 2. Foto de Google Places (mayor calidad si es un local)
    if geo and geo.get("google_image_url"):
        image_url = geo.get("google_image_url")
        
    # 3. Inyección Automática de Galería Unsplash según la categoría
    if not image_url or len(str(image_url).strip()) < 5:
        cat_key = category["key"]
        if cat_key in FALLBACK_IMAGES:
            image_url = random.choice(FALLBACK_IMAGES[cat_key])

    record = {
        "title":            event["title"],
        "description":      event.get("description"),
        "date":             event.get("date_start"),
        "location":         event.get("location_name"),
        "address":          event.get("address"),
        "category":         category["key"],
        "image_url":        image_url,
        "source_url":       event["source_url"],
        "city":             city,
        "contact_info":     geo.get("contact_info") if geo and geo.get("contact_info") else event.get("contact_info"),
        # Campos de geocodificación (null si no hay Places)
        "google_place_id":      geo.get("google_place_id") if geo else None,
        "latitude":             geo.get("latitude") if geo else None,
        "longitude":            geo.get("longitude") if geo else None,
        "rating_google":        geo.get("rating_google") if geo else None,
        "user_ratings_total":   geo.get("user_ratings_total") if geo else None,
    }

    try:
        supabase.table("events").upsert(record, on_conflict="source_url").execute()
        print(f"  ✅ Guardado: {event['title'][:60]}")
    except Exception as e:
        print(f"  ❌ Error Supabase: {e}")


# ─── Proceso principal ────────────────────────────────────────────────────────
def run_research_agent():
    """Itera ciudades × categorías, busca, extrae, geocodifica y guarda."""
    print(f"\n{'='*60}")
    print(f"🔍 PLANMAPP RESEARCH AGENT — {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print(f"{'='*60}")

    if not SUPABASE_URL or not SUPABASE_KEY:
        print("❌ SUPABASE_URL o SUPABASE_KEY no configuradas. Abortando.")
        return

    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
    total_saved = 0

    for city in CITIES:
        print(f"\n📍 Ciudad: {city}")
        for category in CATEGORIES:
            print(f"  🏷️  Categoría: {category['label']}")

            # 1. Búsqueda Tavily
            results = search_with_tavily(city, category)
            if not results:
                print(f"  ⚠️  Sin resultados de Tavily.")
                time.sleep(2)
                continue

            # 2. Extracción Gemini
            events = extract_events_with_gemini(results, city, category)
            print(f"  📦 {len(events)} eventos extraídos")

            # 3. Para cada evento: geocodificar y guardar
            for event in events:
                # Geocodificación Google Places (opcional: no bloquea si falla)
                geo = geocode_with_google_places(
                    event.get("location_name", ""),
                    event.get("address", ""),
                    city,
                )
                upsert_event(supabase, event, city, category, geo)
                total_saved += 1
                time.sleep(0.5)  # Rate limiting suave

            # 🛡️ THROTTLING DE SEGURIDAD (ANTI-429):
            # Gemini Free Tier soporta máximo 15 requests/minuto (1 req cada 4 segs).
            # Al dormir 7 segundos por ciclo de categoría garantizamos ~8 Peticiones por Minuto.
            print("  ⏳ [Throttling] Esperando 7 segundos para enfriar la API...")
            time.sleep(7)  

        print("  ⏳ [Throttling] Pausa de 10 segundos entre ciudades...")
        time.sleep(10)  

    print(f"\n✅ Proceso completado. Total eventos procesados: {total_saved}")
    print(f"{'='*60}\n")


app = Flask(__name__)
try:
    CORS(app)
except NameError:
    pass
scrape_lock = threading.Lock()


@app.route("/")
def health():
    return jsonify({"status": "online", "service": "Planmapp Research Agent v2.0"}), 200


@app.route("/scrape", methods=["GET", "POST"])
def trigger_scrape():
    """Endpoint para invocar el agente manualmente desde Render o externa."""
    if not scrape_lock.acquire(blocking=False):
        return jsonify({"status": "busy", "message": "Ya hay un scrape en curso"}), 409

    def _run():
        try:
            run_research_agent()
        finally:
            scrape_lock.release()

    threading.Thread(target=_run, daemon=True).start()
    return jsonify({"status": "started", "message": "Research Agent iniciado en background"}), 202


@app.route("/status", methods=["GET"])
def status():
    is_running = not scrape_lock.acquire(blocking=False)
    if not is_running:
        scrape_lock.release()
    return jsonify({"running": is_running}), 200


@app.route("/chat_agent", methods=["POST"])
def chat_agent():
    """
    Asistente Social IA: Recibe contexto de chat y UUIDs.
    Retorna la mejor sugerencia de plan de la BD basada en los perfiles del grupo.
    """
    if not SUPABASE_URL or not SUPABASE_KEY or not GEMINI_API_KEY:
        return jsonify({"error": "Faltan API keys en el backend"}), 500

    data = request.json or {}
    plan_id = data.get("plan_id")
    city = data.get("city", "Bogotá")

    if not plan_id:
        return jsonify({"error": "Falta plan_id"}), 400

    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    # 0. Obtener miembros del plan y últimos mensajes
    try:
        plan_res = supabase.table("plans").select("members").eq("id", plan_id).single().execute()
        members = plan_res.data.get("members", [])
        
        msgs_res = supabase.table("messages").select("content, profiles(nickname)").eq("plan_id", plan_id).order("created_at", desc=True).limit(15).execute()
        # Invertir para que estén en orden cronológico
        message_context = [{"sender": m.get("profiles", {}).get("nickname", "Alguien"), "text": m.get("content")} for m in reversed(msgs_res.data)]
    except Exception as e:
        return jsonify({"error": f"Error fetch BD: {e}"}), 500

    if not members:
        return jsonify({"error": "No hay miembros en el plan"}), 400

    # 1. Obtener perfiles del grupo
    try:
        profiles_res = supabase.table("profiles").select("nickname, interests, budget_level, preferences").in_("id", members).execute()
        profiles = profiles_res.data
    except Exception as e:
        return jsonify({"error": f"Error fetch perfiles: {e}"}), 500

    # 2. Obtener eventos recientes en la ciudad (max 50 para que Gemini procese bien)
    try:
        events_res = supabase.table("events").select("*").eq("city", city).order("created_at", desc=True).limit(50).execute()
        events = events_res.data
    except Exception as e:
        return jsonify({"error": f"Error fetch eventos: {e}"}), 500

    if not events:
        return jsonify({"error": "No hay eventos en la cartelera para esta ciudad"}), 404

    # 3. Preparar Prompt para Gemini
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel("gemini-2.5-flash")

    prompt = f"""
Eres '@planmapp', el Asistente Social Inteligente en un grupo de chat de amigos.
Tu misión es analizar el contexto de su conversación y sus perfiles, para seleccionar el SÚPER MEJOR PLAN dentro de una lista de eventos disponibles.

# PERFILES DEL GRUPO:
{json.dumps(profiles, ensure_ascii=False)}

# ÚLTIMOS MENSAJES DEL CHAT:
{json.dumps(message_context, ensure_ascii=False)}

# CARTELERA DE EVENTOS DISPONIBLES EN {city} HOY:
{json.dumps(events, ensure_ascii=False)}

INSTRUCCIONES:
1. Encuentra los intereses comunes del grupo (majority logic).
2. Lee el chat para ver qué tienen ganas de hacer hoy.
3. Elige SOLO 1 evento de la Cartelera (el que tenga el ID exacto).
4. Redacta un mensaje amable, cool, conciso, de máximo 3 líneas como asistente recomendando el plan.

RESPONDE SOLAMENTE UN JSON VÁLIDO SIN MARKDOWN:
{{
  "rationale": "Tu mensaje genial para el grupo justificando la decisión basándote en que a todos les gusta X o lo que leíste en chat",
  "suggested_event_id": "EL_ID_EXACTO_DEL_EVENTO_ELEGIDO"
}}
"""
    try:
        response = model.generate_content(prompt)
        raw = response.text.strip()
        if raw.startswith("```"):
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        
        parsed = json.loads(raw.strip())
        
        # Encontrar el evento completo de vuelta
        selected_id = parsed.get("suggested_event_id")
        selected_event = next((e for e in events if str(e.get("id")) == str(selected_id)), None)

        return jsonify({
            "rationale": parsed.get("rationale", "¡Este plan está buenísimo para ustedes!"),
            "event": selected_event
        }), 200
    except Exception as e:
        return jsonify({"error": f"Error AI Processing: {e}"}), 500


# ─── Entry point ──────────────────────────────────────────────────────────────
if __name__ == "__main__":
    # Si se llama directamente (GitHub Actions cron), corre el agente y sale
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--once":
        run_research_agent()
    else:
        # Modo servidor Render
        port = int(os.environ.get("PORT", 10000))
        print(f"🚀 Iniciando servidor en puerto {port}")
        app.run(host="0.0.0.0", port=port)