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
CITIES = ["Bogotá", "Medellín", "Cali", "Barranquilla", "Cartagena", "Santa Marta"]

CATEGORIES = [
    {"key": "food",     "label": "Gastronomía",  "query_hint": "restaurantes especiales, happy hour, 2x1 comida, cenas románticas"},
    {"key": "party",    "label": "Rumba",         "query_hint": "bares de moda, fiestas, eventos nocturnos, música en vivo"},
    {"key": "culture",  "label": "Cultura",       "query_hint": "museos, exposiciones, teatro, cine, festivales culturales"},
    {"key": "outdoors", "label": "Aire libre",    "query_hint": "senderismo, playas, parques, deportes acuáticos, naturaleza"},
]

# Imágenes de respaldo por categoría (Unsplash)
FALLBACK_IMAGES = {
    "food":     "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&q=80&w=800",
    "party":    "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&q=80&w=800",
    "culture":  "https://images.unsplash.com/photo-1533174072545-e8d4aa97edf9?auto=format&fit=crop&q=80&w=800",
    "outdoors": "https://images.unsplash.com/photo-1502086223501-681a91cc44e7?auto=format&fit=crop&q=80&w=800",
    "music":    "https://images.unsplash.com/photo-1540039155732-d674d6e3f0be?auto=format&fit=crop&q=80&w=800",
    "other":    "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&q=80&w=800",
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
    model = genai.GenerativeModel("gemini-1.5-flash")

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

Devuelve ÚNICAMENTE un JSON array válido (sin markdown, sin explicación):
[
  {{
    "title": "Nombre del evento/lugar",
    "description": "Descripción atractiva de máximo 120 caracteres",
    "date_start": "YYYY-MM-DD o null",
    "location_name": "Nombre del lugar o barrio",
    "address": "Dirección si está disponible o null",
    "category": "{category['key']}",
    "source_url": "URL del resultado",
    "image_url": null
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
    except Exception as e:
        print(f"  [PLACES] Error geocodificando '{query}': {e}")
        return None


# ─── Paso 4: Upsert a Supabase ────────────────────────────────────────────────
def upsert_event(supabase: Client, event: dict, city: str, category: dict, geo: dict | None):
    """Inserta o actualiza un evento en Supabase usando source_url como clave única."""
    if not event.get("title") or not event.get("source_url"):
        return

    # Construir imagen final (Places > Fallback de Unsplash)
    image_url = (
        (geo.get("google_image_url") if geo else None)
        or event.get("image_url")
        or FALLBACK_IMAGES.get(category["key"], FALLBACK_IMAGES["other"])
    )

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
        "contact_info":     "",
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

            time.sleep(3)  # Pausa entre categorías

        time.sleep(5)  # Pausa entre ciudades

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
    model = genai.GenerativeModel("gemini-1.5-flash")

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