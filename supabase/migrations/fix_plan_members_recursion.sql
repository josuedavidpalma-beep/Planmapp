-- ========================================================================================
-- SOLUCIÓN DEFINITIVA A RECURSIÓN INFINITA EN: plan_members
-- ========================================================================================

-- El error 42P17 (infinite recursion detected) en `plan_members` ocurre cuando 
-- la política de RLS de la tabla intenta consultar a la MISMA tabla para 
-- validar si el usuario tiene permiso de ver otros registros.
-- 
-- Para romper este bucle sin perder la seguridad, usamos una función SECURITY DEFINER.
-- Esto permite que PostgreSQL consulte la tabla internamente ANTES de aplicar el RLS
-- de manera cíclica.

-- 1. Creamos una función inmutable y segura que salta el RLS solo para esta comprobación leída.
CREATE OR REPLACE FUNCTION public.check_is_plan_member(p_plan_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER   -- IMPORTANTE: Ejecuta con privilegios de creador, bypass de RLS
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM plan_members 
    WHERE plan_id = p_plan_id AND user_id = auth.uid()
  );
$$;

-- 2. Limpiamos cualquier política de plan_members que esté causando el bucle.
DROP POLICY IF EXISTS "Members_Select_Decoupled" ON public.plan_members;
DROP POLICY IF EXISTS "Members_Manage_Decoupled" ON public.plan_members;
DROP POLICY IF EXISTS "Plan Members Select" ON public.plan_members;
DROP POLICY IF EXISTS "Plan Members Manage" ON public.plan_members;

-- 3. Reescribimos las políticas de plan_members utilizando la función segura
CREATE POLICY "Plan_Members_Select_Safe" ON public.plan_members FOR SELECT
USING (
  -- 1. Bypass Admin
  auth.uid() = '9e2f59a8-0919-40dd-a561-265eaeb66aaf'::uuid 
  
  -- 2. Yo veo mis propios registros sin consultar nada extra
  OR user_id = auth.uid()
  
  -- 3. Si estoy en el plan, veo a los demás (Ojo: usa la función sin bucle)
  OR public.check_is_plan_member(plan_id)
);

CREATE POLICY "Plan_Members_Manage_Safe" ON public.plan_members FOR ALL
USING (
  -- 1. Bypass Admin
  auth.uid() = '9e2f59a8-0919-40dd-a561-265eaeb66aaf'::uuid 
  
  -- 2. Yo solo me puedo actualizar a mi mismo (recharzar/salir)
  OR user_id = auth.uid()
  
  -- 3. Nota: Si necesitas que un 'admin' borre a otros, la regla sería:
  -- OR EXISTS (SELECT 1 FROM plans WHERE id = plan_members.plan_id AND creator_id = auth.uid())
  -- PERO eso chocaría con la tabla plans. Así que lo mantenemos limpio y seguro.
);
