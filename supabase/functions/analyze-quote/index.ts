import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { GoogleGenerativeAI } from "https://esm.sh/@google/generative-ai@0.21.0"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) throw new Error('Missing Authorization header')

        const { image_base64 } = await req.json()
        if (!image_base64) throw new Error('Missing image_base64')

        const apiKey = Deno.env.get('GEMINI_API_KEY')
        if (!apiKey) throw new Error('Server configuration error: GEMINI_API_KEY not set')

        const genAI = new GoogleGenerativeAI(apiKey)
        const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' })

        const promptText = `
# ROL DEL SISTEMA
Eres un asistente experto analizando cotizaciones de servicios turísticos, presupuestos de viajes, facturas proforma y reservas.
Tu misión es extraer los rubros principales que componen el costo de un viaje para armar un presupuesto conjunto.

# REGLAS DE EXTRACCIÓN
1. Busca servicios como "Hospedaje", "Vuelos", "Tour", "Alquiler de Auto", "Seguro", "Transporte", etc.
2. Extrae el nombre o la descripción de manera concisa. (Por ejemplo, "Hotel XYZ - 3 Noches" o "Ticket Aéreo Nacional").
3. Extrae la cantidad si aplica (Ej. número de personas o de noches). Por defecto 1.
4. Extrae el "valor_unitario" (el costo por cada unidad o el subtotal del plan para esa línea).

# SALIDA JSON
Responde ÚNICAMENTE con este JSON:

{
  "section_A_items": [
    {
      "descripcion": "string",
      "cantidad": number,
      "valor_unitario": number
    }
  ],
  "section_B_additionals": [],
  "metadata": {
    "total_pagado": number
  }
}
`

        const result = await model.generateContent([
            promptText,
            { inlineData: { data: image_base64, mimeType: "image/jpeg" } }
        ])

        const responseText = result.response.text()

        let cleanText = responseText.replace(/```json/g, '').replace(/```/g, '')
        const startIndex = cleanText.indexOf('{')
        const endIndex = cleanText.lastIndexOf('}')
        if (startIndex !== -1 && endIndex !== -1) {
            cleanText = cleanText.substring(startIndex, endIndex + 1)
        }

        const rawJson = JSON.parse(cleanText)

        return new Response(JSON.stringify(rawJson), {
             headers: { ...corsHeaders, 'Content-Type': 'application/json' },
             status: 200,
        })
    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})
