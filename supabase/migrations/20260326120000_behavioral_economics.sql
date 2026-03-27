-- Migración: Economía Conductual e Infraestructura WhatsApp
-- Creada en 2026-03-26

-- 1. Enums Regionales y de Estado
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tono_regional') THEN
        CREATE TYPE tono_regional AS ENUM ('costeno', 'paisa', 'rolo', 'valluno', 'neutro');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'intencion_plan') THEN
        CREATE TYPE intencion_plan AS ENUM ('recaudo', 'cobro', 'rsvp');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'canal_notificacion') THEN
        CREATE TYPE canal_notificacion AS ENUM ('whatsapp', 'push', 'email');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'estado_promesa') THEN
        CREATE TYPE estado_promesa AS ENUM ('creada', 'notificada', 'promesa_establecida', 'cumplida', 'incumplida');
    END IF;
END$$;

-- 2. Extensión de Profiles
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS telefono TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS tono_regional tono_regional DEFAULT 'neutro';

-- 3. Tabla de Promesas de Pago (Behavioral Economics)
CREATE TABLE IF NOT EXISTS public.promesas_de_pago (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id UUID NOT NULL REFERENCES public.plans(id) ON DELETE CASCADE,
    expense_id UUID REFERENCES public.expenses(id) ON DELETE CASCADE,
    acreedor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    deudor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, 
    deudor_telefono TEXT, 
    monto NUMERIC NOT NULL,
    fecha_limite_plan TIMESTAMPTZ,
    fecha_promesa TIMESTAMPTZ, 
    estado estado_promesa DEFAULT 'creada',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Seguridad (RLS)
ALTER TABLE public.promesas_de_pago ENABLE ROW LEVEL SECURITY;

-- Políticas
DROP POLICY IF EXISTS "Promesas visibles para involucrados" ON public.promesas_de_pago;
CREATE POLICY "Promesas visibles para involucrados" ON public.promesas_de_pago
    FOR SELECT USING (auth.uid() = acreedor_id OR auth.uid() = deudor_id);

DROP POLICY IF EXISTS "Deudores solo pueden establecer fecha de promesa" ON public.promesas_de_pago;
CREATE POLICY "Deudores solo pueden establecer fecha de promesa" ON public.promesas_de_pago
    FOR UPDATE USING (auth.uid() = deudor_id)
    WITH CHECK (estado = 'notificada' OR estado = 'creada');

DROP POLICY IF EXISTS "Acreedores manejan todas sus promesas" ON public.promesas_de_pago;
CREATE POLICY "Acreedores manejan todas sus promesas" ON public.promesas_de_pago
    FOR ALL USING (auth.uid() = acreedor_id);

-- 5. Trigger para Updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_promesas_updated_at ON public.promesas_de_pago;
CREATE TRIGGER set_promesas_updated_at
BEFORE UPDATE ON public.promesas_de_pago
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
