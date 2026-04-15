
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const tavilyKey = Deno.env.get('TAVILY_API_KEY');
        const geminiKey = Deno.env.get('GEMINI_API_KEY');
        const supabaseUrl = Deno.env.get('SUPABASE_URL');
        const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

        if (!tavilyKey || !geminiKey) throw new Error("API Keys not set");
        const supabase = createClient(supabaseUrl!, supabaseServiceRoleKey!);

        // 1. Tavily Search
        const searchResponse = await fetch("https://api.tavily.com/search", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                api_key: tavilyKey,
                query: "eventos próximos en Barranquilla y Atlántico contacto reservas boletas 2026",
                search_depth: "advanced",
                include_images: true,
                max_results: 10
            }),
        });

        if (!searchResponse.ok) {
            const tavilyErr = await searchResponse.text();
            throw new Error(`Tavily Search failed: ${tavilyErr}`);
        }
        const searchData = await searchResponse.json();
        
        // 2. Extracts with Gemini
        const prompt = `
            Contexto: Eres un experto en extracción de datos de eventos para Planmapp.
            Analiza los siguientes resultados de búsqueda y extrae una lista de eventos reales en Barranquilla o el Atlántico.
            
            Resultados de Búsqueda:
            ${JSON.stringify(searchData.results)}
            
             Requerimientos para cada evento:
            - Solo eventos que ocurran pronto.
            - DEBES encontrar el contacto real: Teléfono (WhatsApp preferiblemente) y link de acción (Reserva, Ticketera, Menú o Web oficial).
            - Asigna un 'vibe_tag' entre: ["Rumba/Party", "Chill/Café", "Comida/Gastro", "Aventura/Outdoor", "Cine/Cultura"].
            - Genera un 'visual_keyword': Un término de búsqueda en INGLÉS corto y preciso para Unsplash que represente la imagen ideal del evento (ej: "night club neon", "luxury steakhouse", "beach sunset", "cinema theater seats"). Se lo más específico posible.
            - La 'description' debe ser atractiva.
            - DEBES extraer un campo 'promo_highlights': DEBE SER MUY CORTO (máximo 15 caracteres) para que quepa en un símbolo o insignia. Ejemplos: "2x1", "30% OFF", "Happy Hour", "Entrada Libre", "Cóctel Gratis", "Cover $0". Si ves cualquier beneficio por mínimo que sea, extráelo. Si no hay nada, deja vacío.
            
            Formato de salida (JSON):
            {
                "events": [
                    {
                        "event_name": "Nombre",
                        "description": "Descripción persuasiva",
                        "promo_highlights": "Resumen MUY CORTO de promo (ej: 2x1)",
                        "date": "YYYY-MM-DD",
                        "venue_name": "Lugar",
                        "address": "Dirección",
                        "city": "Barranquilla",
                        "reservation_link": "URL",
                        "contact_phone": "+57...",
                        "price_range": "Ej: $50.000",
                        "image_url": "URL de imagen original si existe",
                        "vibe_tag": "Vibe",
                        "visual_keyword": "unsplash search term",
                        "primary_source": "Nombre del sitio fuente"
                    }
                ]
            }
            RETORNA ÚNICAMENTE EL JSON.
        `;

        const geminiResponse = await fetch(`https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=${geminiKey}`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                contents: [{ parts: [{ text: prompt }] }],
            }),
        });

        if (!geminiResponse.ok) {
            const geminiErr = await geminiResponse.text();
            throw new Error(`Gemini Extraction failed: ${geminiErr}`);
        }

        const geminiData = await geminiResponse.json();
        let textResult = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
        
        // Robust JSON extraction
        const jsonMatch = textResult.match(/\{[\s\S]*\}/);
        if (!jsonMatch) throw new Error("Could not find JSON in Gemini output");
        const extracted = JSON.parse(jsonMatch[0]);

        // 3. Link Validation & Upsert
        const results = [];
        console.log(`Extracted ${extracted.events?.length || 0} events from Gemini.`);

        for (const event of (extracted.events || [])) {
            // Upsert
            const { data, error } = await supabase
                .from('local_events')
                .upsert(event, { onConflict: 'event_name, date, city' })
                .select();
                
            if (error) {
                console.error(`Error upserting ${event.event_name}:`, error);
            } else if (data) {
                results.push(data[0]);
            }
        }

        return new Response(JSON.stringify({ status: 'ok', discovered: results.length }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        });

    } catch (error) {
        console.error("Scraper Error:", error);
        return new Response(JSON.stringify({ 
            error: error.message,
            stack: error.stack,
            type: "internal_error"
        }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        });
    }
});
