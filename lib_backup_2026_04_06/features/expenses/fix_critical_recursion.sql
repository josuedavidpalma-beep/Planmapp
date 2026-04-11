-- =========================================================
-- ☢️ SCRIPT NUCLEAR DE REPARACIÓN (RLS RECURSION FIX) ☢️
-- =========================================================
-- Ejecuta este script COMPLETO en el Editor SQL de Supabase.
-- Objetivo: Eliminar TODAS las políticas conflictivas y crearlas desde cero
-- usando funciones "blindadas" (Security Definer) que rompen el ciclo infinito.

-- 1. LIMPIEZA PROFUNDA (Borrar todo lo que pueda causar conflicto)
DROP POLICY IF EXISTS "Members view other members" ON public.plan_members;
DROP POLICY IF EXISTS "Admins manage members" ON public.plan_members;
DROP POLICY IF EXISTS "Safe view members" ON public.plan_members;
DROP POLICY IF EXISTS "Safe insert members" ON public.plan_members;
DROP POLICY IF EXISTS "Safe update members" ON public.plan_members;
DROP POLICY IF EXISTS "Safe delete members" ON public.plan_members;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.plan_members;

DROP POLICY IF EXISTS "Plans visible to members" ON public.plans;
DROP POLICY IF EXISTS "Plans visible to members and creators" ON public.plans;
DROP POLICY IF EXISTS "Authenticated users can create plans" ON public.plans;
DROP POLICY IF EXISTS "Admins can update plans" ON public.plans;

-- Borramos funciones viejas para asegurarnos que se actualicen
DROP FUNCTION IF EXISTS public.is_plan_member(uuid);
DROP FUNCTION IF EXISTS public.is_plan_admin(uuid);
DROP FUNCTION IF EXISTS public.get_my_plan_ids();

-- 2. CREAR FUNCIONES BLINDADAS (SECURITY DEFINER)
-- Estas funciones corren con permisos de SUPERUSUARIO, ignorando el RLS.
-- Esto es lo que rompe el ciclo infinito: "Chequea permisos sin chequear reglas de permiso".

-- A. Obtener mis planes (Para listas)
CREATE OR REPLACE FUNCTION public.get_my_plan_ids()
RETURNS SETOF uuid
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY SELECT plan_id FROM public.plan_members WHERE user_id = auth.uid();
END;
$$;

-- B. Verificar si soy miembro (Para un plan especifico)
CREATE OR REPLACE FUNCTION public.is_plan_member(_plan_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.plan_members 
    WHERE plan_id = _plan_id AND user_id = auth.uid()
  );
END;
$$;

-- C. Verificar si soy Admin (Para editar/borrar)
CREATE OR REPLACE FUNCTION public.is_plan_admin(_plan_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.plan_members 
    WHERE plan_id = _plan_id AND user_id = auth.uid() AND role = 'admin'
  );
END;
$$;

-- 3. HABILITAR SEGURIDAD (Por si acaso estuviera apagada)
ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plan_members ENABLE ROW LEVEL SECURITY;

-- 4. CREAR POLÍTICAS NUEVAS (TABLA: PLANS)

-- Ver: Si soy miembro O si soy el creador (mientras me agrego)
CREATE POLICY "Ver Planes" ON public.plans
FOR SELECT USING (
  creator_id = auth.uid() 
  OR 
  is_plan_member(id)
);

-- Crear: Todos los logueados
CREATE POLICY "Crear Planes" ON public.plans
FOR INSERT WITH CHECK (
  auth.role() = 'authenticated'
);

-- Editar: Solo Admins o Creador
CREATE POLICY "Editar Planes" ON public.plans
FOR UPDATE USING (
  creator_id = auth.uid() 
  OR 
  is_plan_admin(id)
);

-- Borrar: Solo Admins o Creador
CREATE POLICY "Borrar Planes" ON public.plans
FOR DELETE USING (
  creator_id = auth.uid() 
  OR 
  is_plan_admin(id)
);

-- 5. CREAR POLÍTICAS NUEVAS (TABLA: PLAN_MEMBERS)

-- Ver: Veo mis filas O las filas de mis planes
CREATE POLICY "Ver Miembros" ON public.plan_members
FOR SELECT USING (
  user_id = auth.uid() 
  OR 
  plan_id IN (SELECT get_my_plan_ids())
);

-- Insertar: Puedo agregarme a mí mismo (al crear plan) O si soy admin agregando a otro
CREATE POLICY "Agregar Miembros" ON public.plan_members
FOR INSERT WITH CHECK (
  user_id = auth.uid() 
  OR 
  is_plan_admin(plan_id)
);

-- Gestionar Miembros: Solo Admins
CREATE POLICY "Gestionar Miembros" ON public.plan_members
FOR ALL USING (
  is_plan_admin(plan_id)
);

-- =========================================================
-- 6. AUTOMATIZACIÓN (La Vaca / Presupuesto) 🐮
-- =========================================================
-- Cuando alguien entra al plan, se le agrega automáticamente al seguimiento de pagos.

CREATE OR REPLACE FUNCTION public.auto_add_to_budget()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.payment_trackers (plan_id, user_id)
  VALUES (NEW.plan_id, NEW.user_id)
  ON CONFLICT DO NOTHING; -- Si ya está, no pasa nada
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_member_joined_budget ON public.plan_members;
CREATE TRIGGER on_member_joined_budget
AFTER INSERT ON public.plan_members
FOR EACH ROW EXECUTE FUNCTION public.auto_add_to_budget();

