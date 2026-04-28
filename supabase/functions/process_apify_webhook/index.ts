import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.47.0";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const payload = await req.json();
    console.log("Recibido Webhook de Apify:", JSON.stringify(payload));

    // Validar payload
    if (payload.test === "get_events") {
        const { data, error } = await supabase.from('local_events').select('*').eq('status', 'pending');
        return new Response(JSON.stringify({ data, error }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        });
    }

    let items = [];
    if (payload.resource && payload.resource.defaultDatasetId) {
        // Es un webhook de Apify (Run Succeeded)
        const datasetId = payload.resource.defaultDatasetId;
        const apifyToken = Deno.env.get('APIFY_TOKEN') || '';
        const tokenParam = apifyToken ? `?token=${apifyToken}` : '';
        
        const datasetRes = await fetch(`https://api.apify.com/v2/datasets/${datasetId}/items${tokenParam}`);
        const jsonRes = await datasetRes.json();
        
        if (!Array.isArray(jsonRes)) {
            throw new Error(`Apify Dataset error. Token: ${apifyToken ? 'Presente' : 'Ausente'}. Respuesta: ${JSON.stringify(jsonRes).substring(0, 200)}`);
        }
        items = jsonRes;
        console.log(`Recuperados ${items.length} items del dataset ${datasetId}`);
    } else {
        // Envio directo o formato diferente
        items = Array.isArray(payload) ? payload : (payload.items || [payload]);
    }
    
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY');
    if (!geminiApiKey) throw new Error("Falta GEMINI_API_KEY");

    let processedCount = 0;
    let lastError = null;

    for (const item of items) {
       const caption = item.caption || item.text || "";
       const imageUrl = item.displayUrl || item.imageUrl || item.image_url || "";
       const url = item.url || "";
       
       if (!caption || caption.length < 20) continue;

       // 1. Enviar a Gemini para extraer los datos
       const prompt = `
Eres un Conserje Experto en eventos de Barranquilla (y Colombia).
Analiza la siguiente publicación de Instagram o página web:
---
TEXTO: ${caption}
---
Extrae la siguiente información en formato JSON estricto sin markdown extra:
{
   "event_name": "Nombre corto y llamativo del evento",
   "description": "Descripción amigable de lo que trata",
   "date": "Fecha en formato YYYY-MM-DD (Si menciona 'hoy' o 'mañana', aproxima basado en el texto, si no hay asume null)",
   "price_level": "Nivel de precio: $, $$, $$$, o $$$$",
   "location": "Nombre del lugar (Ej: Puerta de Oro, El Gran Malecón)",
   "vibes": ["Relajado", "Romántico", "Electrónica", "Familiar", "etc... extrae máximo 3 vibes clave"]
}
Si la publicación NO parece ser un evento o plan, devuelve {"is_valid": false}
       `;

       const geminiRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`, {
           method: 'POST',
           headers: { 'Content-Type': 'application/json' },
           body: JSON.stringify({
               contents: [{ parts: [{ text: prompt }] }]
           })
       });

       const geminiData = await geminiRes.json();
       const rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || "";
       
       // Clean markdown from JSON
       const cleanJson = rawText.replace(/```json/g, "").replace(/```/g, "").trim();
       
       try {
           const parsed = JSON.parse(cleanJson);
           if (parsed.is_valid === false) continue;

            // 2. Insert into local_events with status = 'pending'
            const insertData = {
                event_name: parsed.event_name || 'Evento sin título',
                description: parsed.description || '',
                date: parsed.date || new Date().toISOString().split('T')[0], // FECHA SEGURA
                price_level: parsed.price_level || '',
                venue_name: parsed.location || 'Desconocido',
                image_url: imageUrl,
                primary_source: url,
                city: "Barranquilla", // Default based on target scraping
                status: 'pending', // Requires Super Admin approval!
                vibe_tag: (parsed.vibes || []).join(", ")
            };

            const { error } = await supabase.from('local_events').insert(insertData);
            if (error) {
                console.error("Supabase insert error:", error);
                lastError = error;
            } else {
                processedCount++;
            }

        } catch (parseError) {
            console.error("Error parseando Gemini JSON:", rawText);
        }
    }

    if (processedCount === 0 && items.length > 0) {
       // Insert a debug event so the user can see what data came in
       try {
           await supabase.from('local_events').insert({
               event_name: 'Debug Apify',
               description: lastError ? `ERROR: ${JSON.stringify(lastError)}` : JSON.stringify(items[0]).substring(0, 500),
               venue_name: 'Debug',
               date: new Date().toISOString().split('T')[0],
               status: 'pending',
               city: 'Barranquilla'
           });
       } catch(e) {
           console.error("Debug insert failed", e);
       }
    }

    return new Response(JSON.stringify({ success: true, processed: processedCount }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    try {
        const supabase = createClient(
          Deno.env.get('SUPABASE_URL') ?? '',
          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );
        await supabase.from('local_events').insert({
            event_name: 'CRITICAL WEBHOOK ERROR',
            description: String(error.message).substring(0, 500),
            venue_name: 'Error',
            date: new Date().toISOString().split('T')[0],
            status: 'pending',
            city: 'Barranquilla'
        });
    } catch(e) {}

    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
