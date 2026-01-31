-- ⚠️ IMPORTANTE: LEE ESTO ANTES DE CORRER EL SCRIPT ⚠️
-- El Editor SQL no sabe quién eres, por eso falló antes.
-- Necesitas pegar TU ID de usuario abajo.

DO $$
DECLARE
    -- 1. BUSCA TU ID en la App (donde dice "Debug: Yo=...") o en Authentication > Users
    -- 2. PÉGALO AQUÍ DENTRO DE LAS COMILLAS: 'tu-id-aqui'
    target_user_id uuid := '00000000-0000-0000-0000-000000000000'; 
BEGIN
    
    -- Si no has cambiado el ID de arriba, lanzará un error para avisarte.
    IF target_user_id = '00000000-0000-0000-0000-000000000000' THEN
        RAISE EXCEPTION '⚠️ DEBES PONER TU ID DE USUARIO EN LA LÍNEA 8 DEL SCRIPT ⚠️';
    END IF;

    -- 1. Asignarte todos los planes (Arregla los 3 puntos)
    UPDATE public.plans 
    SET creator_id = target_user_id
    WHERE true;

    -- 2. Asegurar que eres miembro 'admin'
    INSERT INTO public.plan_members (plan_id, user_id, role)
    SELECT id, target_user_id, 'admin'
    FROM public.plans
    ON CONFLICT (plan_id, user_id) DO UPDATE SET role = 'admin';

END $$;

-- 3. Crear columnas de Perfil (Esto funciona automático)
alter table public.profiles 
add column if not exists phone text,
add column if not exists display_name text;
