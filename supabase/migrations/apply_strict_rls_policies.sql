-- ========================================================================================
-- SCRIPT DE ACTUALIZACIÓN DE POLÍTICAS RLS (Row Level Security) ESTRICTAS
-- ========================================================================================

-- ==========================================
-- 0. CREACIÓN DE TABLAS FALTANTES (Amistades)
-- ==========================================
-- Create friendships table if it doesn't exist yet before applying new policies
CREATE TABLE IF NOT EXISTS public.friendships (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    requester_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    status TEXT CHECK (status IN ('pending', 'accepted', 'blocked')) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(requester_id, receiver_id)
);

ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- 1. CONFIGURACIÓN DEL SUPER ADMINISTRADOR
-- ==========================================
-- Función inmutable y segura para validar el Modo Dios.
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT auth.uid() = '9e2f59a8-0919-40dd-a561-265eaeb66aaf'::uuid;
$$;

-- Función segura para obtener el estado del miembro actual (Evita recursión infinita en plan_members)
-- Se usa SECURITY DEFINER para bypass de RLS y romper el clásico bucle donde 
-- comprobar membresía dispara la misma regla de membresía repetidamente.
CREATE OR REPLACE FUNCTION public.get_member_status(p_plan_id UUID)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT status FROM public.plan_members WHERE plan_id = p_plan_id AND user_id = auth.uid() LIMIT 1;
$$;

-- ==========================================
-- 2. TABLA: plans
-- ==========================================
DROP POLICY IF EXISTS "Plans Select" ON public.plans;
DROP POLICY IF EXISTS "Plans Insert" ON public.plans;
DROP POLICY IF EXISTS "Plans Update" ON public.plans;
DROP POLICY IF EXISTS "Plans Delete" ON public.plans;
DROP POLICY IF EXISTS "Ver Planes" ON public.plans;
DROP POLICY IF EXISTS "Crear Planes" ON public.plans;
DROP POLICY IF EXISTS "Editar Planes" ON public.plans;
DROP POLICY IF EXISTS "Borrar Planes" ON public.plans;

-- SELECT: Permitido si el plan es public O si el usuario es miembro.
CREATE POLICY "Plans Select" ON public.plans FOR SELECT
USING (
  is_super_admin() 
  OR visibility = 'public' 
  OR EXISTS (
    SELECT 1 FROM public.plan_members 
    WHERE plan_id = public.plans.id AND user_id = auth.uid()
  )
);

-- INSERT / UPDATE / DELETE: Solo creador del plan
CREATE POLICY "Plans Insert" ON public.plans FOR INSERT
WITH CHECK (is_super_admin() OR auth.uid() = creator_id);

CREATE POLICY "Plans Update" ON public.plans FOR UPDATE
USING (is_super_admin() OR auth.uid() = creator_id);

CREATE POLICY "Plans Delete" ON public.plans FOR DELETE
USING (is_super_admin() OR auth.uid() = creator_id);

-- ==========================================
-- 3. TABLA: plan_members
-- ==========================================
DROP POLICY IF EXISTS "Plan Members Select" ON public.plan_members;
DROP POLICY IF EXISTS "Plan Members Manage" ON public.plan_members;
DROP POLICY IF EXISTS "Users can view their own membership" ON public.plan_members;
DROP POLICY IF EXISTS "Members can view other members in same plan" ON public.plan_members;

-- Para evitar recursión usaremos get_member_status o validación directa de UID.
CREATE POLICY "Plan Members Select" ON public.plan_members FOR SELECT
USING (
  is_super_admin()
  OR user_id = auth.uid() -- Puedo verme a mi mismo
  OR get_member_status(plan_id) IS NOT NULL -- Si soy miembro del plan, puedo ver al resto
);

-- Gestión de miembros (Admin/Owner scope)
CREATE POLICY "Plan Members Manage" ON public.plan_members FOR ALL
USING (
  is_super_admin()
  OR EXISTS (
    SELECT 1 FROM public.plans 
    WHERE id = public.plan_members.plan_id AND creator_id = auth.uid()
  )
  OR user_id = auth.uid() -- El propio usuario puede auto-actualizar su status o borrarse (rechazar invite)
);

-- ==========================================
-- 4. TABLA: activities (Itinerario)
-- ==========================================
DROP POLICY IF EXISTS "Members can view activities" ON public.activities;
DROP POLICY IF EXISTS "Admins can manage activities" ON public.activities;

-- SELECT: Solo posible si el estado en plan_members es 'accepted'
CREATE POLICY "Activities Select" ON public.activities FOR SELECT
USING (
  is_super_admin()
  OR EXISTS (
    SELECT 1 FROM public.plan_members 
    WHERE plan_id = public.activities.plan_id 
      AND user_id = auth.uid() 
      AND status = 'accepted'
  )
);

-- MANAGE: Creador del plan (modificable si quieres que todos puedan agregar luego, pero por ahora estricto)
CREATE POLICY "Activities Manage" ON public.activities FOR ALL
USING (
  is_super_admin()
  OR EXISTS (
    SELECT 1 FROM public.plans 
    WHERE id = public.activities.plan_id AND creator_id = auth.uid()
  )
);

-- ==========================================
-- 5. TABLAS: bills y bill_items (Gastos)
-- ==========================================
-- BILLS (Cabecera)
DROP POLICY IF EXISTS "Plan members can view bills" ON public.bills;
DROP POLICY IF EXISTS "Creators/Payers can manage bills" ON public.bills;

CREATE POLICY "Bills Select" ON public.bills FOR SELECT
USING (
  is_super_admin()
  OR EXISTS (
    SELECT 1 FROM public.plan_members 
    WHERE plan_id = public.bills.plan_id 
      AND user_id = auth.uid() 
      AND status = 'accepted'
  )
);

-- INSERT/UPDATE/DELETE en cabecera: Solo creador del plan o el pagador original
CREATE POLICY "Bills Manage" ON public.bills FOR ALL
USING (
  is_super_admin()
  OR payer_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.plans 
    WHERE id = public.bills.plan_id AND creator_id = auth.uid()
  )
);

-- BILL ITEMS (Detalles)
DROP POLICY IF EXISTS "Plan members can view items" ON public.bill_items;
DROP POLICY IF EXISTS "Plan members can manage items" ON public.bill_items;

CREATE POLICY "Bill Items Select" ON public.bill_items FOR SELECT
USING (
  is_super_admin()
  OR EXISTS (
    SELECT 1 FROM public.bills b
    JOIN public.plan_members pm ON b.plan_id = pm.plan_id
    WHERE b.id = public.bill_items.bill_id 
      AND pm.user_id = auth.uid() 
      AND pm.status = 'accepted'
  )
);

-- Cualquier miembro con estado 'accepted' puede insertar/editar ítems
CREATE POLICY "Bill Items Manage" ON public.bill_items FOR ALL
USING (
  is_super_admin()
  OR EXISTS (
    SELECT 1 FROM public.bills b
    JOIN public.plan_members pm ON b.plan_id = pm.plan_id
    WHERE b.id = public.bill_items.bill_id 
      AND pm.user_id = auth.uid() 
      AND pm.status = 'accepted'
  )
);

-- ==========================================
-- 6. TABLA: friendships (Amistades)
-- ==========================================
DROP POLICY IF EXISTS "Users can view their own friendships" ON public.friendships;
DROP POLICY IF EXISTS "Users can create friendship requests" ON public.friendships;
DROP POLICY IF EXISTS "Users can update their own friendships" ON public.friendships;
DROP POLICY IF EXISTS "Users can delete their own friendships" ON public.friendships;

-- SELECT: Solo terceros NO ven listas de amigos que no les conciernen.
CREATE POLICY "Friendships Select" ON public.friendships FOR SELECT
USING (
  is_super_admin()
  OR auth.uid() = requester_id 
  OR auth.uid() = receiver_id
);

-- INSERT: Solo yo puedo enviar solicitudes desde mi cuenta
CREATE POLICY "Friendships Insert" ON public.friendships FOR INSERT
WITH CHECK (
  is_super_admin()
  OR auth.uid() = requester_id
);

-- UPDATE / DELETE: Involucrados (Para aceptar, confirmar o bloquear)
CREATE POLICY "Friendships Update" ON public.friendships FOR UPDATE
USING (
  is_super_admin()
  OR auth.uid() = requester_id 
  OR auth.uid() = receiver_id
);

CREATE POLICY "Friendships Delete" ON public.friendships FOR DELETE
USING (
  is_super_admin()
  OR auth.uid() = requester_id 
  OR auth.uid() = receiver_id
);
