import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const ALERT_EMAIL = Deno.env.get('ALERT_EMAIL') // Correo del administrador o dueño al que le llegará la alerta

serve(async (req) => {
  try {
    const { record } = await req.json();

    // 1. Extraer los datos de la encuesta
    const food = record.responses?.rating_food || 0;
    const service = record.responses?.rating_service || 0;
    const ambiance = record.responses?.rating_ambiance || 0;
    const feedback = record.responses?.feedback_text || "Sin comentarios";

    const avg = (food + service + ambiance) / 3;

    // 2. Verificar si es una calificación crítica (<= 2.0)
    if (avg <= 2.0) {
      console.log(`Alerta crítica detectada: Promedio ${avg.toFixed(1)}`);

      if (!RESEND_API_KEY) {
         console.error("No se ha configurado RESEND_API_KEY en los secretos de Supabase.");
         return new Response("Alerta generada pero no enviada (Falta API Key)", { status: 200 });
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
          to: [ALERT_EMAIL || 'josuedavidpalma@gmail.com'],
          subject: '🚨 ALERTA CRÍTICA: Cliente Insatisfecho en la Mesa',
          html: `
            <h2>¡Atención Inmediata!</h2>
            <p>Se acaba de registrar una encuesta con una calificación crítica.</p>
            <ul>
              <li><strong>Promedio General:</strong> <span style="color:red;font-weight:bold;">${avg.toFixed(1)} / 5.0</span></li>
              <li><strong>Comida:</strong> ${food}</li>
              <li><strong>Servicio:</strong> ${service}</li>
              <li><strong>Ambiente:</strong> ${ambiance}</li>
            </ul>
            <p><strong>Comentarios del cliente:</strong> "${feedback}"</p>
            <hr/>
            <p>Por favor acércate a la mesa o revisa la situación para compensar la experiencia antes de que el cliente se retire.</p>
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
