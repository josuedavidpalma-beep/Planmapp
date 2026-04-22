
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

        // 1. Tavily Search optimized for Aggregation (Master, Tickets, AND Local Business Promos)
        const today = new Date().toISOString().split('T')[0];
        const searchResponse = await fetch("https://api.tavily.com/search", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                api_key: tavilyKey,
                query: `(Restaurantes locales Barranquilla promociones fijos 2x1 happy hour dias de la semana descuento) OR (Burger Master OR Conciertos TuBoleta Taquilla Live) Barranquilla hoy enlaces Instagram`,
                search_depth: "advanced",
                include_images: true,
                max_results: 30
            }),
        });

        if (!searchResponse.ok) {
            const tavilyErr = await searchResponse.text();
            throw new Error(`Tavily Search failed: ${tavilyErr}`);
        }
        const searchData = await searchResponse.json();
        
        // 2. Extracts with Gemini (Acting as Transactional & Local Deals Aggregator)
        const prompt = `
            Contexto: Eres un "Master Aggregator" para la aplicación social Planmapp.
            Fecha Actual: ${today} (Excluye cualquier evento que ya haya pasado permanentemente).
            
            Analiza los siguientes resultados de búsqueda y extrae una lista de eventos Y PROMOCIONES DE NEGOCIOS REALES en Barranquilla o el Atlántico. 
            Queremos que Planmapp no solo sea directorio, sino un conector directo a compras y además el experto en descuentos locales (Ej: "Precios especiales en Phortos los martes").
            
            Resultados de Búsqueda:
            ${JSON.stringify(searchData.results)}
            
             Requerimientos para cada evento/promo:
            - EXTRAE la información de promociones fijas o "Happy Hours" de restaurantes y locales. Identifícalos explícitamente en el 'vibe_tag' como "Local Promo" o "Descuento".
            - MÁS EXTRAE la información de festivales tipo "Master" (vibe_tag: "Master Fest") y Conciertos (vibe_tag: "Ticketing").
            - OBLIGATORIO: Extraer el enlace directo para Comprar Entradas, Reservar, o el link oficial del Instagram del local que confirma la promo.
            - OBLIGATORIO: Mapear el rango de precios en 'price_range' (ej: "$18.000 COP", "$25.000 2x1").
            - FECHAS: Si es un evento único, pon esa fecha exacta. Si es una promoción recurrente (Ej: "Todos los martes"), calcula la fecha del PRÓXIMO martes más cercano a hoy (${today}) e insértala en 'date'. Si aplica hoy, pon hoy.
            - La 'description' debe sonar comercial y emocionante ("¡Aprovecha el Burger Master!" o "¡Miércoles de 2x1 en Phortos!").
            - Extrae 'promo_highlights' (máx 15 chars). Ej: "Combo $18k", "2x1 Martes", "Happy Hour".
            - Asigna la fecha en 'date'.
            
            Formato de salida (JSON):
            {
                "events": [
                    {
                        "event_name": "Nombre de Artista o Festival",
                        "description": "Descripción",
                        "promo_highlights": "Combo $18k",
                        "date": "YYYY-MM-DD",
                        "venue_name": "Lugar",
                        "address": "Dirección",
                        "city": "Barranquilla",
                        "reservation_link": "https://tuboleta.com/... o instagram... DEBE existir",
                        "contact_phone": "+57...",
                        "price_range": "Ej: $18.000",
                        "image_url": "URL original si existe",
                        "vibe_tag": "Master Fest",
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
