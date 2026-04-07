-- SCRIPT CORREGIDO (Sin Usuario Demo que causa error)
-- ID DEL USUARIO: 9e2f59a8-0919-40dd-a561-265eaeb66aaf

DO $$
DECLARE
    target_user_id uuid := '9e2f59a8-0919-40dd-a561-265eaeb66aaf'; 
BEGIN
    -- 1. Asignarte TODOS los planes como Creador
    UPDATE public.plans 
    SET creator_id = target_user_id
    WHERE true;

    -- 2. Asegurar que eres miembro 'admin' en todos esos planes
    INSERT INTO public.plan_members (plan_id, user_id, role)
    SELECT id, target_user_id, 'admin'
    FROM public.plans
    ON CONFLICT (plan_id, user_id) DO UPDATE SET role = 'admin';

END $$;

-- 3. Asegurar columnas de Perfil (Para que funcione el nuevo Perfil)
alter table public.profiles 
add column if not exists phone text,
add column if not exists country_code text default '+57',
add column if not exists birthday timestamp with time zone,
add column if not exists preferences text[];
