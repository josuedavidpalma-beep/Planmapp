
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

        // 1. Multi-category Tavily Searches for better coverage
        const today = new Date().toISOString().split('T')[0];
        
        const queries = [
            `site:eventbrite.co OR site:tuboleta.com OR site:joinnus.com Colombia (concierto OR festival OR taller) eventos destacados hoy proximos dias`,
            `(site:cuponatic.com.co OR site:atrapalo.com.co) Colombia (2x1 OR descuento OR "happy hour" OR restaurante) promociones activas hoy`,
            `("planes recomendados" OR "que hacer en" OR "restaurantes virales") (Bogotá OR Medellín OR Barranquilla OR Cartagena) (tiktok OR instagram) spot viral`
        ];

        let allSearchResults = [];
        for (const query of queries) {
            const searchResponse = await fetch("https://api.tavily.com/search", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    api_key: tavilyKey,
                    query: query,
                    search_depth: "advanced",
                    include_images: true,
                    max_results: 15
                }),
            });
            if (searchResponse.ok) {
                const data = await searchResponse.json();
                allSearchResults = allSearchResults.concat(data.results || []);
            }
        }

        if (allSearchResults.length === 0) throw new Error("All Tavily searches failed.");

        // 2. Extracts with Gemini using User's Optimized Prompt
        const prompt = `
            Actúa como un analista de eventos locales en Colombia. Escanea los resultados provistos buscando actividades para hoy y los próximos 30 días (${today}).
            Prioriza lugares que sean tendencia en redes sociales (Spot Virales), eventos oficiales, o que ofrezcan descuentos directos (2x1, % OFF).

            Resultados de Búsqueda:
            ${JSON.stringify(allSearchResults.slice(0, 40))}
            
            Requerimientos para cada evento/promo:
            - Extrae la información en el formato estricto JSON solicitado.
            - "Tipo de oferta" / vibe_tag: Clasificar en "2x1", "% Descuento", "Entrada Gratuita", "Lanzamiento", "Viral", "Concierto", o "Cultura".
            - FECHAS: Asigna la fecha en 'date'. Si es una promoción recurrente (Ej: "Miércoles de 2x1"), calcula la fecha del PRÓXIMO miércoles.
            - La 'description' es el contexto. Suena comercial y emocionante. Si el lugar es un 'Spot Viral', menciónalo.
            - 'promo_highlights' (máx 15 chars). Ej: "Combo $18k", "2x1 Martes".
            - OBLIGATORIO: Extraer el enlace directo para Comprar Entradas, Reservar, o el link oficial del Instagram/Lugar ('reservation_link').
            
            Formato de salida (JSON):
            {
                "events": [
                    {
                        "event_name": "Nombre de Artista, Festival o Restaurante",
                        "description": "Descripción del ambiente (contexto)",
                        "promo_highlights": "2x1 / Viral",
                        "date": "YYYY-MM-DD",
                        "venue_name": "Nombre comercial o recinto",
                        "address": "Dirección exacta",
                        "city": "Filtra por: Barranquilla, Medellín, Bogotá, Cali, Cartagena o Santa Marta",
                        "reservation_link": "URL directa de compra o redes sociales",
                        "contact_phone": "+57...",
                        "price_range": "Ej: $18.000 / Gratis",
                        "image_url": "URL original si existe",
                        "vibe_tag": "Ej: Viral",
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
