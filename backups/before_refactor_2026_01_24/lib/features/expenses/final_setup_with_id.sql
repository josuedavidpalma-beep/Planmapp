-- SCRIPT FINAL DE CONFIGURACIÓN
-- ID DEL USUARIO: 9e2f59a8-0919-40dd-a561-265eaeb66aaf

DO $$
DECLARE
    -- TU ID REAL QUE NOS DISTE:
    target_user_id uuid := '9e2f59a8-0919-40dd-a561-265eaeb66aaf'; 
    demo_id uuid := '11111111-1111-1111-1111-111111111111';
    my_plan_id uuid;
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

    -- 3. Crear el Amigo Demo para pruebas (Si no existe)
    INSERT INTO public.profiles (id, full_name, display_name, phone, country_code, avatar_url)
    VALUES (
        demo_id, 
        'Amigo de Prueba', 
        'Amigo Demo', 
        '3001234567', 
        '+57', 
        'https://ui-avatars.com/api/?name=Amigo+Demo&background=random'
    )
    ON CONFLICT (id) DO UPDATE 
    SET phone = '3001234567', country_code = '+57';

    -- 4. Agregar al Amigo Demo a tu último plan creado
    SELECT id INTO my_plan_id FROM public.plans ORDER BY created_at DESC LIMIT 1;
    IF my_plan_id IS NOT NULL THEN
        INSERT INTO public.plan_members (plan_id, user_id, role)
        VALUES (my_plan_id, demo_id, 'member')
        ON CONFLICT (plan_id, user_id) DO NOTHING;
    END IF;

END $$;

-- 5. Asegurar columnas de Perfil (Por si acaso falto alguna)
alter table public.profiles 
add column if not exists phone text,
add column if not exists country_code text default '+57',
add column if not exists birthday timestamp with time zone,
add column if not exists preferences text[]; -- Array de gustos
