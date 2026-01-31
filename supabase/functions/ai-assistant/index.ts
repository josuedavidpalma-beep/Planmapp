
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const { action, payload } = await req.json();
        const apiKey = Deno.env.get('GEMINI_API_KEY');

        if (!apiKey) throw new Error("GEMINI_API_KEY is not set");

        let prompt = "";

        // --- ROUTER ---
        if (action === 'classify_expense') {
            const title = payload.title || "";
            prompt = `
          Analyze this expense title: "${title}".
          Return a JSON object with:
          - category: One of ["Comida", "Transporte", "Alojamiento", "Actividad", "Compras", "Otro"]
          - emoji: A single relevant emoji
          
          Example: { "category": "Food", "emoji": "🍔" }
          Return ONLY JSON.
        `;
        } else if (action === 'suggest_poll_options') {
            const question = payload.question || "";
            const location = payload.location || "general context";
            prompt = `
          The user asks: "${question}" in the context of "${location}".
          Suggest 3-4 short, specific options for a poll.
          Return a JSON list of strings.
          
          Example: ["Option 1", "Option 2", "Option 3"]
          Return ONLY JSON.
        `;
        } else {
            throw new Error(`Unknown action: ${action}`);
        }

        // --- CALL GEMINI ---
        const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`, {
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

        if (!textResult) throw new Error("No response from AI");

        // Robust JSON Cleanup
        textResult = textResult.replace(/```json/g, '').replace(/```/g, '').trim();
        const firstBracket = textResult.indexOf(action === 'suggest_poll_options' ? '[' : '{');
        const lastBracket = textResult.lastIndexOf(action === 'suggest_poll_options' ? ']' : '}');

        if (firstBracket !== -1 && lastBracket !== -1) {
            textResult = textResult.substring(firstBracket, lastBracket + 1);
        }

        const resultJson = JSON.parse(textResult);

        return new Response(JSON.stringify(resultJson), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        });

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        });
    }
});
