import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// Edge function for generating Dynamic OpenGraph Tags for Social Media previews
serve(async (req) => {
  const url = new URL(req.url);
  const planId = url.searchParams.get('plan_id') || 'unknown';

  // TODO: Query Supabase for real Plan details
  
  const html = `
    <!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <meta property="og:title" content="¡Se armó el Plan! 🔥">
      <meta property="og:description" content="Entra, confirma y revisa el Planómetro de PlanMaps.">
      <meta property="og:image" content="https://via.placeholder.com/1200x630.png?text=PlanMaps">
      <title>PlanMaps - Invitación</title>
    </head>
    <body style="font-family: sans-serif; text-align: center; padding: 50px;">
      <h1>Redirigiendo a la app...</h1>
      <p>Si no eres redirigido, haz clic <a href="/invite/${planId}">aquí</a>.</p>
      <script>
         setTimeout(() => {
             window.location.href = '/invite/' + '${planId}';
         }, 1000);
      </script>
    </body>
    </html>
  `;

  return new Response(html, {
    headers: { "Content-Type": "text/html" },
  })
})
