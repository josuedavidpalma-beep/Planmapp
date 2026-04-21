
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

        // 1. Tavily Search optimized for Spontaneous (Plan Ya) results
        const today = new Date().toISOString().split('T')[0];
        const searchResponse = await fetch("https://api.tavily.com/search", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                api_key: tavilyKey,
                query: `eventos promociones Barranquilla (site:instagram.com OR site:tiktok.com OR Tuboleta OR Taquilla Live OR Eventbrite OR Mallplaza OR Buenavista OR Viva) hoy entradas descuentos`,
                search_depth: "advanced",
                include_images: true,
                max_results: 20
            }),
        });

        if (!searchResponse.ok) {
            const tavilyErr = await searchResponse.text();
            throw new Error(`Tavily Search failed: ${tavilyErr}`);
        }
        const searchData = await searchResponse.json();
        
        // 2. Extracts with Gemini (Acting as Categorizer)
        const prompt = `
            Contexto: Eres un experto en extracción y categorización de eventos para Planmapp.
            Fecha Actual: ${today} (Excluye cualquier evento que ya haya pasado o esté marcado como AGOTADO/SOLD OUT).
            
            Analiza los siguientes resultados de búsqueda y extrae una lista de eventos REALES y VIGENTES en Barranquilla o el Atlántico.
            
            Resultados de Búsqueda:
            ${JSON.stringify(searchData.results)}
            
             Requerimientos para cada evento:
            - EXTRAE LA MAYOR CANTIDAD POSIBLE DE EVENTOS. No omitas ninguno que sea válido.
            - Solo eventos que ocurran HOY (${today}) o en el futuro cercano.
            - DETECCIÓN DE VIRALIDAD: Prioriza publicaciones ruidosas (crecimiento rápido de interacciones, o contenido con intención de compra como "¿Precios?", "¡Vamos!"). Si es irrelevante, ignóralo.
            - DEBES encontrar el contacto real y el enlace directo (URL a Instagram, TikTok, Ticketera u origen de la promoción).
            - Asigna un 'vibe_tag' entre: ["Feria", "Festival", "Concierto", "Gastronomía", "Descuento Retail", "Evento Cultural"].
            - Genera un 'visual_keyword': Un término de búsqueda en INGLÉS corto y preciso para Unsplash (ej: "night club neon", "luxury steakhouse", "beach sunset").
            - La 'description' debe ser atractiva y persuasiva.
            - DEBES extraer el campo 'promo_highlights' estrictamente (máx 12 chars). Ej: "2x1", "Happy Hour", "30% OFF", "Free Entry", "Cover $0". Si no hay promo, deja vacío.
            - IMPORTANTE: Si un evento dice "SOLD OUT", "Entradas Agotadas" o "Aforo Completo", IGNÓRALO.
            
            Formato de salida (JSON):
            {
                "events": [
                    {
                        "event_name": "Nombre",
                        "description": "Descripción",
                        "promo_highlights": "2x1",
                        "date": "YYYY-MM-DD",
                        "venue_name": "Lugar",
                        "address": "Dirección",
                        "city": "Barranquilla",
                        "reservation_link": "URL",
                        "contact_phone": "+57...",
                        "price_range": "Ej: $50.000",
                        "image_url": "URL original si existe",
                        "vibe_tag": "Vibe",
                        "status": "active"
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
