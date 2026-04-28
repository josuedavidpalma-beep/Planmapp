-- 1. Añadir logo_url a la tabla de restaurantes
ALTER TABLE public.restaurants
ADD COLUMN IF NOT EXISTS logo_url TEXT;

-- 2. Crear Trigger para enviar notificaciones en calificaciones bajas (<= 2)
-- Para esto, llamaremos a un Webhook (usando pg_net) o llamaremos a la edge function a través de supabase net.
-- Supabase Edge Functions se pueden llamar de forma segura mediante peticiones POST.

CREATE EXTENSION IF NOT EXISTS "pg_net";

CREATE OR REPLACE FUNCTION notify_low_rating()
RETURNS TRIGGER AS $$
DECLARE
    avg_score NUMERIC;
BEGIN
    -- Se espera que el JSONB 'responses' tenga propiedades o se calcule un promedio general.
    -- Dado que 'responses' tiene ai_raw_total y keys como "Calidad", extraemos de la lógica o asumimos 
    -- que el Edge Function calculará el promedio y enviará la alerta si es necesario.
    -- Simplemente enviamos el JSON a la Edge Function cada vez que hay una encuesta.

    -- NOTA: Asegúrate de tener la variable de entorno SUPABASE_URL en el Edge Function o reemplazar el host aquí con tu URL del proyecto.
    -- Para este entorno local/nube, usaremos pg_net para hacer el request a la función.
    -- Solo mandaremos la petición si se determina que necesita alerta. Para simplificar, la Edge Function evaluará.

    PERFORM net.http_post(
        url := current_setting('request.headers')::json->>'origin' || '/functions/v1/alert_low_rating',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', current_setting('request.headers')::json->>'authorization'
        ),
        body := jsonb_build_object(
            'record', row_to_json(NEW)
        )
    );

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Ignorar fallos de red para no bloquear la inserción de la encuesta
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notify_low_rating ON public.survey_responses;
CREATE TRIGGER trigger_notify_low_rating
AFTER INSERT ON public.survey_responses
FOR EACH ROW
EXECUTE FUNCTION notify_low_rating();
