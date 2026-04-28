import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');

serve(async (req) => {
  try {
    const { record } = await req.json();

    // 1. Extraer los datos de la encuesta
    const food = record.rating_food || 0;
    const service = record.rating_service || 0;
    const ambiance = record.rating_ambiance || 0;
    const feedback = record.feedback_text || "Sin comentarios";
    
    // Extraer datos del comensal y la cuenta
    const dinerName = record.user_name || "Cliente Anónimo";
    const totalBill = record.responses?.ai_raw_total || 0;
    const items = Array.isArray(record.receipt_items) ? record.receipt_items : [];
    
    const avg = (food + service + ambiance) / 3;

    // 2. Verificar si es una calificación crítica (<= 2.0)
    if (avg <= 2.0) {
      console.log(`Alerta crítica detectada: Promedio ${avg.toFixed(1)}`);

      if (!RESEND_API_KEY) {
         console.error("No se ha configurado RESEND_API_KEY en los secretos de Supabase.");
         return new Response("Alerta generada pero no enviada (Falta API Key)", { status: 200 });
      }

      // Conectar a Supabase para obtener el owner_email del restaurante
      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
      const supabase = createClient(supabaseUrl, supabaseKey);

      const { data: restaurant } = await supabase
         .from('restaurants')
         .select('owner_email, name')
         .eq('id', record.restaurant_id)
         .maybeSingle();

      const targetEmail = restaurant?.owner_email;

      if (!targetEmail || targetEmail.trim() === '') {
         console.log("El restaurante no tiene owner_email configurado. No se enviará alerta.");
         return new Response("Alerta omitida (No hay owner_email)", { status: 200 });
      }

      const restName = restaurant?.name || "Tu Restaurante";
      
      let itemsHtml = "";
      if (items.length > 0) {
         itemsHtml = `
            <h3>Artículos de la Cuenta</h3>
            <ul>
               ${items.map((i: any) => `<li>${i.qty || 1}x ${i.name} ($${i.price})</li>`).join('')}
            </ul>
         `;
      }

      // 3. Enviar correo usando la API de Resend
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${RESEND_API_KEY}`
        },
        body: JSON.stringify({
          from: 'Planmapp Alerts <onboarding@resend.dev>', // Cambia esto si tienes un dominio verificado
          to: [targetEmail],
          subject: `🚨 ALERTA CRÍTICA: Cliente Insatisfecho en ${restName}`,
          html: `
            <div style="font-family: sans-serif; padding: 20px; color: #333;">
                <h2 style="color: #d9534f;">¡Atención Inmediata!</h2>
                <p>Se acaba de registrar una encuesta con una calificación crítica en <b>${restName}</b>.</p>
                
                <div style="background-color: #f9f9f9; padding: 15px; border-radius: 8px; margin-bottom: 20px;">
                    <p><strong>Comensal:</strong> ${dinerName}</p>
                    <p><strong>Total de la cuenta:</strong> $${totalBill}</p>
                    <p><strong>Hora:</strong> ${new Date(record.created_at || new Date()).toLocaleString()}</p>
                </div>

                <h3>Calificaciones</h3>
                <ul>
                  <li><strong>Promedio General:</strong> <span style="color:red;font-weight:bold;">${avg.toFixed(1)} / 5.0</span></li>
                  <li><strong>Comida:</strong> ${food}</li>
                  <li><strong>Servicio:</strong> ${service}</li>
                  <li><strong>Ambiente:</strong> ${ambiance}</li>
                </ul>
                <p><strong>Comentarios del cliente:</strong> <br/><i>"${feedback}"</i></p>
                
                ${itemsHtml}

                <hr/>
                <p style="color: #555;">Por favor acércate a la mesa de ser posible o revisa la situación para compensar la experiencia.</p>
            </div>
          `
        })
      });

      if (res.ok) {
         return new Response("Alerta enviada por correo exitosamente.", { status: 200 });
      } else {
         const errorText = await res.text();
         console.error("Error enviando correo:", errorText);
         return new Response("Error al enviar alerta.", { status: 500 });
      }
    }

    return new Response("Encuesta registrada (No requiere alerta)", { status: 200 });
  } catch (err) {
    console.error("Error procesando webhook:", err);
    return new Response("Error interno del servidor", { status: 500 });
  }
});
