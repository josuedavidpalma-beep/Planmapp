import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const payload = await req.json()
        const { schema, table, type, record, old_record } = payload

        if (table !== 'promesas_de_pago') {
            return new Response(JSON.stringify({ error: "Ignoring non-promise table" }), { headers: corsHeaders, status: 200 })
        }

        // Initialize Supabase Admin Client
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // Lógica 1: Notificador Inverso (Deudor establece fecha -> Acreedor se relaja)
        if (type === 'UPDATE' && record.estado === 'promesa_establecida' && old_record.estado !== 'promesa_establecida') {
            const { data: acreedor } = await supabaseAdmin.from('profiles').select('telefono, tono_regional').eq('id', record.acreedor_id).single()

            let mensaje = `Ey! El deudor ha prometido pagar el ${record.fecha_promesa}. Ya no tienes que preocuparte, nosotros le recordamos si no lo hace.`;
            if (acreedor?.tono_regional === 'paisa') mensaje = `¡Eavemaría! Ya cuadraron la vaca para el ${record.fecha_promesa}. Relajate pues que nosotros le cobramos si se le olvida.`;
            if (acreedor?.tono_regional === 'costeno') mensaje = `¡Eche! Ya tiraron la liga para el ${record.fecha_promesa}. Cógela suave que acá le hacemos el recordatorio.`;
            if (acreedor?.tono_regional === 'rolo') mensaje = `¡Ala! Ya se cuadró el pago para el ${record.fecha_promesa}. Fresco que nosotros le recordamos.`;

            // TODO: Llamar a Meta Cloud API para enviar 'mensaje' al acreedor.telefono
            console.log("NOTIFICANDO AL ACREEDOR:", mensaje);
        }

        // Retorna 200 para que el webhook no falle
        return new Response(JSON.stringify({ success: true }), {
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
