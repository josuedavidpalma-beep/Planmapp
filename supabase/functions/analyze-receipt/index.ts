
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { GoogleGenerativeAI, Part } from "https://esm.sh/@google/generative-ai@0.1.3"

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
        // 1. Verify Authentication
        // The Supabase Auth token is passed in the Authorization header.
        // Edge Runtime automatically validates it if we use formatted responses, 
        // but for strict security we could use supabase-js to getUser().
        // For now, checks if header exists.
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            throw new Error('Missing Authorization header')
        }

        // 2. Parse Body
        const { image_base64 } = await req.json()
        if (!image_base64) {
            throw new Error('Missing image_base64')
        }

        // 3. Initialize Gemini
        // API KEY must be set in Supabase Secrets: supabase secrets set GEMINI_API_KEY=...
        const apiKey = Deno.env.get('GEMINI_API_KEY')
        if (!apiKey) {
            throw new Error('Server configuration error: GEMINI_API_KEY not set')
        }

        const genAI = new GoogleGenerativeAI(apiKey)
        // Switch to Pro for better reasoning on complex receipts
        const model = genAI.getGenerativeModel({ model: 'gemini-1.5-pro' })

        // 4. Construct Prompt (Identical to Mobile Implementation)
        const promptText = `
# ROL DEL SISTEMA
Eres un motor OCR de precisión para facturas. Tu problema actual es que estás confundiendo precios con descripciones. Para solucionar esto, usarás un proceso de dos pasos para cada ítem.

# PROCESO OBLIGATORIO DE EXTRACCIÓN (ESTRATEGIA DE SUSTRACCIÓN)

Para cada ítem, ejecuta este algoritmo mental:

1.  **PASO 1: DETECTAR NÚMEROS (Los objetos rígidos)**
    *   Identifica primero lo fácil: PRECIO (miles/decimales) y CANTIDAD (enteros pequeños).
    *   *Acción Mental:* "Sustrae" o "Recorta" esos números de la imagen de la línea.

2.  **PASO 2: EL SOBRANTE (La Descripción)**
    *   ¿Qué queda en la línea después de quitar los números? **ESO ES LA DESCRIPCIÓN.**
    *   Transcribe ese sobrante literalmente.
    *   Si el sobrante es vacío (ej: la línea era "12.000"), ENTONCES busca texto en la línea de arriba (Caso Delipizza).

# REGLAS DE BLOQUEO (FIREWALL)
*   **ORDEN:** Primero llena Cantidad/Precio. Lo que sobre es Descripción.
*   **SI EL SOBRANTE SON MÁS NÚMEROS:** Ignóralos. No los pongas en descripción.
*   **SI NO HAY SOBRANTE (SOLO NÚMEROS):** Busca arriba. Si arriba tampoco hay texto, el ítem es inválido.

# REGLAS DE BLOQUEO (FIREWALL)
* **SI EL CAMPO 'descripcion' CONTIENE SOLO NÚMEROS O SÍMBOLOS, EL ÍTEM ES INVÁLIDO.** Es preferible devolver "ITEM_ILLEGIBLE" a devolver un precio en la descripción.
* Si la línea detectada es "9,00 9,00" (sin texto), IGNÓRALA. No es un producto.

# SALIDA JSON (NUEVA ESTRUCTURA)
Responde ÚNICAMENTE con este JSON. Fíjate que hemos añadido 'linea_cruda'.

{
  "section_A_items": [
    {
      "descripcion": "string",  // ESTRICTAMENTE TEXTO ALFABÉTICO. Si pones un número aquí, fallas.
      "cantidad": number,       // Número entero o decimal. Default: 1
      "valor_unitario": number  // El precio que usaste de ancla
    }
  ],
  "section_B_additionals": [
    {
      "type": "Tax" | "Tip" | "Discount",
      "descripcion": "string",
      "valor": number
    }
  ],
  "metadata": {
    "comercio": "string",
    "total_pagado": number
  }
}
    `

        // 5. Call Gemini
        const result = await model.generateContent([
            promptText,
            { inlineData: { data: image_base64, mimeType: "image/jpeg" } }
        ])

        const responseText = result.response.text()

        // 6. Clean and Parse JSON
        let cleanText = responseText.replace(/```json/g, '').replace(/```/g, '')
        const startIndex = cleanText.indexOf('{')
        const endIndex = cleanText.lastIndexOf('}')
        if (startIndex !== -1 && endIndex !== -1) {
            cleanText = cleanText.substring(startIndex, endIndex + 1)
        }

        const rawJson = JSON.parse(cleanText)

        // 7. Post-Processing (Ported from Dart)
        const refinedItems = sanitizeAndRefineItems(rawJson.section_A_items || [])

        // Update the items in the response
        rawJson.section_A_items = refinedItems

        // 8. Return Result
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

// --- Helper Functions (Ported from Dart) ---

function sanitizeAndRefineItems(rawItems: any[]) {
    let refined = []

    for (let i = 0; i < rawItems.length; i++) {
        const current = rawItems[i]
        const rawName = current.descripcion?.toString() || "Item"
        const price = parseFloat(current.valor_unitario?.toString() || "0")
        const quantity = parseFloat(current.cantidad?.toString() || "1")

        // 1. NUCLEAR DIGIT REMOVAL
        // Remove ANY digit (0-9) and common price symbols from the name.
        let cleanName = rawName.replace(/[0-9$]/g, '').trim()

        // Clean up leftover messy punctuation at start/end
        cleanName = cleanName.replace(/^[\.\-\s]+|[\.\-\s]+$/g, '')

        // 2. CHECK IF DEAD
        if (!cleanName) {
            // Fusion candidate?
            if (price > 0) {
                cleanName = "Escribir nombre..."
            } else {
                // Garbage line? Check fusion.
            }
        }

        // 3. FUSION RULE
        if (i + 1 < rawItems.length) {
            const next = rawItems[i + 1]
            const nextName = next.descripcion?.toString() || ""
            const nextPrice = parseFloat(next.valor_unitario?.toString() || "0")

            const currentIsText = cleanName.length > 1 && cleanName !== "Escribir nombre..."
            const currentNoPrice = price === 0

            const nextNameNoDigits = nextName.replace(/[0-9$]/g, '').trim()
            const nextIsNumeric = !nextNameNoDigits
            const nextHasPrice = nextPrice > 0

            if (currentIsText && currentNoPrice && (nextHasPrice || nextIsNumeric)) {
                // MERGE
                refined.push({
                    descripcion: cleanName,
                    cantidad: parseFloat(next.cantidad?.toString() || "1"),
                    valor_unitario: nextPrice
                })
                i++ // Skip next
                continue
            }
        }

        if ((cleanName === "Escribir nombre..." || !cleanName) && price === 0) {
            continue
        }

        refined.push({
            descripcion: cleanName,
            cantidad: quantity,
            valor_unitario: price
        })
    }

    return refined
}
