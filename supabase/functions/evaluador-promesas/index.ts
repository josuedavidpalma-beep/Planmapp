import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

serve(async (req) => {
    try {
        // Solo debe ser llamado via pg_cron (auth key check recomendado)
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 1. Encontrar promesas vencidas
        const { data: vencidas, error } = await supabaseAdmin
            .from('promesas_de_pago')
            .select('id, deudor_telefono, monto, deudor_id')
            .eq('estado', 'promesa_establecida')
            .lt('fecha_promesa', new Date().toISOString());

        if (error) throw error;

        for (const promesa of vencidas) {
            // 2. Transicionar a 'incumplida'
            await supabaseAdmin
                .from('promesas_de_pago')
                .update({ estado: 'incumplida' })
                .eq('id', promesa.id);

            // 3. Conseguir tono del deudor
            let tono = 'neutro';
            if (promesa.deudor_id) {
                const { data: perfil } = await supabaseAdmin.from('profiles').select('tono_regional').eq('id', promesa.deudor_id).single();
                if (perfil) tono = perfil.tono_regional;
            }

            // 4. Degradación empática con Gemini UI (The AI Collector)
            let mensajeError = `Hola, notamos que pasó la fecha acordada para tu aporte de ${promesa.monto}. ¿Tuviste algún inconveniente?`;
            
            const geminiKey = Deno.env.get('GEMINI_API_KEY');
            if (geminiKey && tono !== 'neutro') {
                try {
                    const geminiRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiKey}`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            contents: [{
                                parts: [{ text: `Eres PlanMaps, un asistente logístico. Genera UN solo mensaje muy corto y coloquial de WhatsApp cobrando a un amigo una cuota o promesa de pago vencida de $${promesa.monto}. El tono/jerga del deudor es colombiano: '${tono}'. Actúa como si fueras de su misma región. Sé empático pero directo. Usa MÁXIMO 20 palabras y un emoji.` }]
                            }]
                        })
                    });
                    const geminiData = await geminiRes.json();
                    if (geminiData?.candidates?.[0]?.content?.parts?.[0]?.text) {
                        mensajeError = geminiData.candidates[0].content.parts[0].text.trim();
                    }
                } catch (e) {
                    console.error("Error llamando a Gemini:", e);
                }
            } else {
                // Fallback local
                if (tono === 'paisa') mensajeError = `¡Quiubo! Pasó la fecha de la vaca por ${promesa.monto}. ¿Qué te pasó, mor?`;
                if (tono === 'costeno') mensajeError = `¡Eche vale! Pasó la fecha pa la vaca de ${promesa.monto}. ¿Qué pasó con la liga?`;
                if (tono === 'rolo') mensajeError = `¡Ala! Pasó la fecha acordada por ${promesa.monto}. ¿Te cobró el banco paila o qué?`;
            }

            // TODO: Enviar mensaje de utilidad vía Meta WhatsApp API
            console.log("Enviando WhatsApp a deudor:", promesa.deudor_telefono, mensajeError);
        }

        return new Response(JSON.stringify({ procesadas: vencidas.length }), { status: 200 })
    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), { status: 500 })
    }
})
