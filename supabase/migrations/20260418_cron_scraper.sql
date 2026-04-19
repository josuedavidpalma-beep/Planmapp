-- Habilita pg_cron para tareas automatizadas programadas
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Habilita pg_net (si no esta habilitada) para llamadas HTTP
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Programa la recolección automática de eventos (Scraper IA)
-- Todos los días a las 10:00 UTC (Equivale a 05:00 AM hora Colombia)
-- URL de la Edge Function (el subdominio asume tu proyecto actual)
SELECT cron.schedule(
  'scrape-events-daily',
  '0 10 * * *',
  $$
    SELECT net.http_post(
        url:='https://pthiaalrizufhlplbjht.supabase.co/functions/v1/event-scraper',
        headers:='{"Content-Type": "application/json"}'::jsonb
    );
  $$
);
