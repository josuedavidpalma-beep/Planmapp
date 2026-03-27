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

            // 4. Degradación empática
            let mensajeError = `Hola, notamos que pasó la fecha acordada para tu aporte de ${promesa.monto}. ¿Tuviste algún inconveniente?`;
            if (tono === 'paisa') mensajeError = `¡Quiubo! Pasó la fecha de la vaca por ${promesa.monto}. ¿Qué te pasó, mor?`;
            // ... (otros tonos)

            // TODO: Enviar mensaje de utilidad vía Meta WhatsApp API
            console.log("Enviando WhatsApp a deudor:", promesa.deudor_telefono, mensajeError);
        }

        return new Response(JSON.stringify({ procesadas: vencidas.length }), { status: 200 })
    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), { status: 500 })
    }
})
