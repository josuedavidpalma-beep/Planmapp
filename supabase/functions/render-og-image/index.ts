import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0"

// Edge function for generating Dynamic OpenGraph Tags for Social Media previews
serve(async (req) => {
  const url = new URL(req.url);
  const planId = url.searchParams.get('plan_id');
  const redirectPath = url.searchParams.get('redirect_path');

  // URL of the PWA
  const targetUrl = redirectPath ? `https://planmapp.app${redirectPath}` : (planId ? `https://planmapp.app/plan/${planId}` : 'https://planmapp.app/');

  if (!planId || planId === 'unknown') {
    return new Response(generateHtml("¡Planmapp!", "Organiza tus salidas.", null, targetUrl), { headers: new Headers({ "Content-Type": "text/html; charset=utf-8" }) });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Fetch Plan Details
    const { data: planData } = await supabaseClient
      .from('plans')
      .select('title, description, event_date, image_url, location_name')
      .eq('id', planId)
      .single();

    if (!planData) {
       return new Response(generateHtml("Plan no encontrado", "Este plan ya no existe.", null, targetUrl), { 
           headers: new Headers({ "Content-Type": "text/html; charset=utf-8" }) 
       });
    }

    let finalImageUrl = planData.image_url;

    // Resolve Google Places Cache Image if needed
    if (!finalImageUrl && planData.location_name) {
      const { data: placeData } = await supabaseClient
         .from('cached_places')
         .select('photo_reference')
         .eq('name', planData.location_name)
         .maybeSingle();

      if (placeData && placeData.photo_reference) {
         // It's a Google Places reference. Without the Google API Key on the server, we can't fully resolve it to the raw JPEG url.
         // However, the PWA will handle it. For WhatsApp, we can fallback to the generic logo or loremflickr.
         finalImageUrl = `https://loremflickr.com/800/600/${encodeURIComponent(planData.location_name.split(' ')[0])}`;
      } else {
         finalImageUrl = `https://loremflickr.com/800/600/party`;
      }
    } else if (!finalImageUrl) {
      finalImageUrl = `https://loremflickr.com/800/600/event`;
    }

    let description = planData.description || "¡Únete a mi plan en Planmapp!";
    let ogTitle = `¡Plan: ${planData.title}! 🔥`;

    if (redirectPath?.includes('vaca') || redirectPath?.includes('split')) {
        ogTitle = `💸 ¡A pagar! Cuenta de ${planData.title}`;
        description = `Entra para ver cuánto te toca pagar o confirmar tu aporte en Planmapp.`;
    } else {
        ogTitle = `¡Te invitaron a: ${planData.title}! 🔥`;
        if (planData.event_date) {
            description = `📅 Fecha: ${planData.event_date}\n${description}`;
        }
    }

    return new Response(generateHtml(ogTitle, description, finalImageUrl, targetUrl), {
       headers: new Headers({ "Content-Type": "text/html; charset=utf-8" }),
    });

  } catch (err) {
    console.error("Error rendering OG Tags:", err);
    return new Response(generateHtml("Planmapp", "Organiza tus salidas sin drama.", null, targetUrl), { 
        headers: new Headers({ "Content-Type": "text/html; charset=utf-8" }) 
    });
  }
})

function generateHtml(title: string, description: string, imageUrl: string | null, redirectUrl: string) {
  const imageTag = imageUrl ? `<meta property="og:image" content="${imageUrl}">\n      <meta name="twitter:image" content="${imageUrl}">` : `<meta property="og:image" content="https://raw.githubusercontent.com/josuedavidpalma-beep/Planmapp/main/web/icons/Icon-512.png">`;
  
  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
      <meta property="og:title" content="${title}">
      <meta property="og:description" content="${description}">
      <meta property="og:type" content="website">
      <meta name="twitter:card" content="summary_large_image">
      <meta name="twitter:title" content="${title}">
      <meta name="twitter:description" content="${description}">
      ${imageTag}
      <title>${title}</title>
      <script>
         setTimeout(() => {
             window.location.href = '${redirectUrl}';
         }, 100);
      </script>
    </head>
    <body style="font-family: sans-serif; background-color: #050505; color: white; text-align: center; padding-top: 20vh;">
      <img src="https://raw.githubusercontent.com/josuedavidpalma-beep/Planmapp/main/web/icons/Icon-192.png" width="80" style="border-radius: 20px; margin-bottom: 20px;">
      <h2>Abriendo Planmapp...</h2>
      <p style="color: #888;">Si no eres redirigido automáticamente, haz clic <a href="${redirectUrl}" style="color: #6366f1;">aquí</a>.</p>
    </body>
    </html>
  `;
}
