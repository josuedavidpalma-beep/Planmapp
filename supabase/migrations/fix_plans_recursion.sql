-- ========================================================================================
-- SOLUCIÓN DE RECURSIÓN INFINITA: plans & plan_members DESACOPLADOS
-- ========================================================================================

-- UUID Administrativo
-- 9e2f59a8-0919-40dd-a561-265eaeb66aaf

-- ==========================================
-- 1. DROP POLICY ACTUALES DE AMBAS TABLAS
-- ==========================================
DROP POLICY IF EXISTS "Plans Select" ON public.plans;
DROP POLICY IF EXISTS "Plans Insert" ON public.plans;
DROP POLICY IF EXISTS "Plans Update" ON public.plans;
DROP POLICY IF EXISTS "Plans Delete" ON public.plans;
DROP POLICY IF EXISTS "Ver Planes" ON public.plans;
DROP POLICY IF EXISTS "Plans_Select_Safe" ON public.plans;
DROP POLICY IF EXISTS "Enable read for members and public" ON public.plans;

DROP POLICY IF EXISTS "Plan Members Select" ON public.plan_members;
DROP POLICY IF EXISTS "Plan Members Manage" ON public.plan_members;
DROP POLICY IF EXISTS "Users can view their own membership" ON public.plan_members;
DROP POLICY IF EXISTS "Members can view other members in same plan" ON public.plan_members;

-- ==========================================
-- 2. POLÍTICAS PARA: plans
-- ==========================================
-- Regla SELECT estricta y plana sin JOINs implícitos cruzados
CREATE POLICY "Plans_Select_Decoupled" ON public.plans FOR SELECT
USING (
  -- 1. Bypass Administrador
  auth.uid() = '9e2f59a8-0919-40dd-a561-265eaeb66aaf'::uuid 
  
  -- 2. Planes Públicos (asumiendo que existe la columna 'visibility')
  OR visibility = 'public' 
  
  -- 3. Soy el Creador (Evaluación plana sin subconsultas)
  OR auth.uid() = creator_id
  
  -- 4. Soy Miembro (Subconsulta limpia hacia la tabla hija que no consulta a parent)
  OR EXISTS (
      SELECT 1 FROM public.plan_members 
      WHERE plan_members.plan_id = plans.id 
        AND plan_members.user_id = auth.uid()
  )
);

-- UPDATE/INSERT/DELETE limitadas al creador o administrador
CREATE POLICY "Plans_Insert_Decoupled" ON public.plans FOR INSERT
WITH CHECK (
  auth.uid() = '9e2f59a8-0919-40dd-a561-265eaeb66aaf'::uuid 
  OR auth.uid() = creator_id
);

CREATE POLICY "Plans_Update_Decoupled" ON public.plans FOR UPDATE
USING (
  auth.uid() = '9e2f59a8-0919-40dd-a561-265eaeb66aaf'::uuid 
  OR auth.uid() = creator_id
);

CREATE POLICY "Plans_Delete_Decoupled" ON public.plans FOR DELETE
USING (
  auth.uid() = '9e2f59a8-0919-40dd-a561-265eaeb66aaf'::uuid 
  OR auth.uid() = creator_id
);

-- ==========================================
-- 3. POLÍTICAS PARA: plan_members
-- ==========================================
-- No podemos hacer SELECT a plans aquí para evitar el bucle A -> B -> A.
-- Solución: La política es auto-contenida (solo ve sus propios registros) 
-- y usa SECURITY DEFINER o funciones seguras para ver al resto. 
-- Como se solicitó consulta plana, lo hacemos por evaluación directa de existencia en SU PROPIA tabla.

CREATE POLICY "Members_Select_Decoupled" ON public.plan_members FOR SELECT
USING (
  -- 1. Bypass Administrador
  auth.uid() = '9e2f59a8-0919-40dd-a561-265eaeb66aaf'::uuid 
  
  -- 2. Yo puedo ver mis propios registros de invitación/membresía
  OR user_id = auth.uid()
  
  -- 3. Si yo estoy en ESE mismo plan_id, puedo ver los demás registros asociados a ese plan.
  -- Usamos un select explícito que evalúa la propia tabla de destino rompiendo la dependencia cíclica.
  OR EXISTS (
      SELECT 1 FROM public.plan_members AS my_membership 
      WHERE my_membership.plan_id = plan_members.plan_id 
        AND my_membership.user_id = auth.uid()
  )
);

-- Para manipular miembros (Añadir/borrar)
-- No consultamos plans de vuelta. Confíamos en el rol almacenado 'admin' en la propia tabla 
-- de members O permitimos que un usuario se auto-gestione (ej. salir del plan).
CREATE POLICY "Members_Manage_Decoupled" ON public.plan_members FOR ALL
USING (
  -- 1. Bypass
  auth.uid() = '9e2f59a8-0919-40dd-a561-265eaeb66aaf'::uuid 
  
  -- 2. Yo me puedo actualizar o borrar (rechazar invitación)
  OR user_id = auth.uid()
  
  -- 3. Soy admin/creador de ESE plan según MIS MISMAS credenciales en plan_members
  OR EXISTS (
      SELECT 1 FROM public.plan_members AS my_admin_status
      WHERE my_admin_status.plan_id = plan_members.plan_id 
        AND my_admin_status.user_id = auth.uid() 
        AND my_admin_status.role = 'admin' -- Asegúrate de que tengas una columna 'role' ('admin', 'member')
  )
);
