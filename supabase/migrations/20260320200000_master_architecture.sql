-- A. Tipos Enumerados (Enums):
DO $$ BEGIN
    CREATE TYPE attendance_status AS ENUM ('confirmed', 'maybe', 'pending', 'declined');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE plan_status AS ENUM ('open', 'confirmed', 'settling', 'closed', 'archived');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE fee_application_type AS ENUM ('proportional', 'equal');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- B. Modificación de Tablas Principales:
-- Tabla: plans (El Planómetro y Smart-Deadline)
ALTER TABLE public.plans 
ADD COLUMN IF NOT EXISTS min_participants int DEFAULT 2,
ADD COLUMN IF NOT EXISTS max_participants int,
ADD COLUMN IF NOT EXISTS deadline timestamp with time zone,
ADD COLUMN IF NOT EXISTS current_viability numeric DEFAULT 0;

-- Tabla: plan_members (Gestión de desertores y Habeas Data)
ALTER TABLE public.plan_members 
ADD COLUMN IF NOT EXISTS status attendance_status DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS late_cancellation boolean DEFAULT false;

-- C. Tablas para "El Tocheo" y Gastos Transversales:
-- C. (Se removió la parte C de Invoices debido a que fue reemplazado por la arquitectura de Expenses en las migraciones posteriores)

-- D. Storage y Limpieza Automática:
INSERT INTO storage.buckets (id, name, public) 
VALUES ('plan-attachments', 'plan-attachments', false) 
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.delete_plan_storage_objects()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM storage.objects
  WHERE bucket_id = 'plan-attachments'
  AND (storage.foldername(name))[1] = OLD.id::text;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_delete_plan_storage ON public.plans;
CREATE TRIGGER trigger_delete_plan_storage
BEFORE DELETE ON public.plans
FOR EACH ROW
EXECUTE FUNCTION public.delete_plan_storage_objects();

-- E. Tareas Programadas (pg_cron)
-- Se requiere extensión pg_cron habilitada en el dashboard de Supabase o localmente.
DO $$ 
BEGIN
  IF EXISTS (
      SELECT 1
      FROM pg_extension
      WHERE extname = 'pg_cron'
  ) THEN
      PERFORM cron.schedule('auto-archivar', '0 * * * *', 
        'UPDATE public.plans SET status = ''archived'' WHERE event_date < now() - interval ''24 hours'' AND status != ''archived'';'
      );
      PERFORM cron.schedule('purga-anual', '0 0 1 * *', 
        'DELETE FROM public.plans WHERE status = ''archived'' AND event_date < now() - interval ''12 months'';'
      );
  END IF;
END $$;
