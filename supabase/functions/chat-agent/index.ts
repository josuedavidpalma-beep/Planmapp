
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

    let body: any = {};
    try {
        body = await req.json();
        const { plan_id, content } = body;
        const geminiApiKey = Deno.env.get('GEMINI_API_KEY');
        const supabaseUrl = Deno.env.get('SUPABASE_URL');
        const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

        if (!geminiApiKey) throw new Error("GEMINI_API_KEY is not set");
        
        const supabase = createClient(supabaseUrl!, supabaseServiceRoleKey!);

        // 1. Fetch Plan Details to give context to Gemini
        const { data: plan, error: planError } = await supabase
            .from('plans')
            .select('*')
            .eq('id', plan_id)
            .single();

        if (planError || !plan) throw new Error("Plan not found");

        // 1.5 Fetch any active promos for this location
        const { data: promos } = await supabase
            .from('local_events')
            .select('event_name, promo_highlights, date, end_date')
            .ilike('venue_name', `%${plan.location_name || ''}%`)
            .eq('status', 'active')
            .limit(3);
            
        let promosContext = "No hay promos registradas para este lugar actualmente.";
        if (promos && promos.length > 0) {
            promosContext = promos.map((p: any) => `- "${p.event_name}": ${p.promo_highlights} (Válido: ${p.date} al ${p.end_date})`).join('\n');
        }

        // 2. Prepare Prompt
        const prompt = `
            Eres "Plan Bot", el asistente y amigo organizador de Planmapp. Tu objetivo es ayudar a este grupo a concretar su plan de forma fluida.
            
            Contexto del Plan actual:
            - Título: "${plan.title}"
            - Ubicación: "${plan.location_name}"
            - Descripción: "${plan.description}"
            - Info de contacto/reserva disponible: "${plan.contact_info || 'No especificada'}" y "${plan.reservation_link || 'No especificado'}"
            
            ⭐⭐ OFERTAS/PROMOS ACTIVAS DESCUBIERTAS POR IA EN ESTE LOCAL ⭐⭐:
            ${promosContext}
            (¡Usa esta info si alguien pregunta cuándo ir o recomienda usar la promo!)
            
            Mensaje del usuario: "${content}"
            
            Instrucciones IMPORTANTES de Personalidad ("Plan Bot"):
            1. SIEMPRE asume un tono casual, cálido y de grupo. Usa expresiones amplias como "Hola amig@s", "Chicos", o "Equipo".
            2. Tu personalidad es útil pero relajada, no suenes robótico. Eres el amigo que organiza el plan.
            3. SI hay información de contacto o reserva (WhatsApp, link, teléfono), anímalos a usarla. Ejemplo: "Chicos, ya vi que tienen el contacto aquí, ¿lo usamos de una vez?"
            4. ¡ESENCIAL!: Si el sistema detectó Promos Acivas arriba, trata de sugerir ir el día de la promo para ahorrar dinero de forma súper natural.
            5. Si el usuario pide sugerencias distintas de lugar, dales ideas concretas cerca de "${plan.location_name}".
            
            Formato de salida (JSON):
            {
                "rationale": "Tu respuesta amable y proactiva al grupo",
                "suggested_event": {
                    "title": "Nombre de actividad/lugar sugerido (opcional)",
                    "location": "Dirección aprox (opcional)",
                    "image_url": "URL sugerida (opcional)"
                }
            }
            RETORNA ÚNICAMENTE EL JSON.
        `;

        // 3. Call Gemini
        const response = await fetch(`https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                contents: [{ parts: [{ text: prompt }] }],
            }),
        });

        if (!response.ok) {
            const err = await response.text();
            throw new Error(`Gemini API Error: ${err}`);
        }

        const data = await response.json();
        let textResult = data.candidates?.[0]?.content?.parts?.[0]?.text;
        
        console.log("Gemini Raw Response:", textResult);

        // Robust JSON extraction
        const jsonMatch = textResult.match(/\{[\s\S]*\}/);
        if (!jsonMatch) {
            console.error("No JSON found in Gemini response:", textResult);
            throw new Error("Could not parse AI response as JSON");
        }
        
        const resultJson = JSON.parse(jsonMatch[0]);

        // 4. Update the chat in real-time (Insert system message)
        await supabase.from('messages').insert({
            plan_id,
            content: resultJson.rationale,
            user_id: null, // System
            type: 'system',
            metadata: resultJson.suggested_event ? { suggested_event: resultJson.suggested_event } : null
        });

        return new Response(JSON.stringify({ status: 'ok' }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        });

    } catch (error) {
        console.error(error);
        
        // Final attempt to report error to the chat if we have plan_id
        try {
            const { plan_id } = await req.json().catch(() => ({}));
            if (plan_id) {
                const supabaseUrl = Deno.env.get('SUPABASE_URL');
                const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
                const supabase = createClient(supabaseUrl!, supabaseServiceRoleKey!);
                await supabase.from('messages').insert({
                    plan_id,
                    content: `⚠️ Error de Asistente: ${error.message}. Por favor, verifica la configuración de Gemini.`,
                    user_id: null,
                    type: 'system'
                });
            }
        } catch (innerErr) {
            console.error("Failed to report error to chat:", innerErr);
        }

        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        });
    }
});
