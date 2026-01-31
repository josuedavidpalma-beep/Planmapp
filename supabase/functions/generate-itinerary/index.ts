
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
        const { location, days, interests } = await req.json();

        if (!location || !days) {
            throw new Error("Location and days are required");
        }

        const apiKey = Deno.env.get('GEMINI_API_KEY');
        if (!apiKey) {
            throw new Error("GEMINI_API_KEY is not set");
        }

        // Modern Prompt Engineering for JSON
        const prompt = `
      Act as a Travel Agent. Generate a ${days}-day itinerary for ${location}.
      Interests: ${interests || "generalHighlights"}.
      
      Return ONLY a raw JSON list of activities. Do not include markdown formatting (like \`\`\`json).
      Each activity must have:
      - title: String (Name of activity)
      - description: String (Short appealing description)
      - day: Number (1 to ${days})
      - time: String (HH:MM 24hr format, e.g., "09:00", "14:00")
      - category: String (One of: "food", "activity", "lodging", "transport")
      
      Example format:
      [
        { "title": "Visit Eiffel Tower", "description": "Iconic iron lady...", "day": 1, "time": "09:00", "category": "activity" },
        { "title": "Lunch at Le Relais", "description": "Famous steak frites...", "day": 1, "time": "13:00", "category": "food" }
      ]
    `;

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

        if (!textResult) {
            throw new Error("No response from Gemini");
        }

        // Clean up potential markdown code blocks if the model ignores the prompt
        textResult = textResult.replace(/```json/g, '').replace(/```/g, '').trim();

        const activities = JSON.parse(textResult);

        return new Response(JSON.stringify(activities), {
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
