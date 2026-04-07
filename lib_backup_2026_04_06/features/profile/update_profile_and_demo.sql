-- 1. Add new columns to PROFILES
alter table public.profiles 
add column if not exists birthday date,
add column if not exists preferences text[], -- Array of strings for tags like ['Playa', 'Party']
add column if not exists country_code text default '+57';

-- 2. Create a DEMO USER (Fake Profile for testing)
-- We generate a fake UUID for the ID. This user won't be able to log in, 
-- but will appear in the member list if we add them to a plan.
DO $$
DECLARE
    demo_id uuid := '11111111-1111-1111-1111-111111111111';
    my_plan_id uuid;
BEGIN
    -- Insert/Update Demo Profile
    INSERT INTO public.profiles (id, full_name, display_name, phone, country_code, avatar_url)
    VALUES (
        demo_id, 
        'Amigo de Prueba', 
        'Amigo Demo', 
        '3001234567', -- Fake phone without code
        '+57', 
        'https://ui-avatars.com/api/?name=Amigo+Demo&background=random'
    )
    ON CONFLICT (id) DO UPDATE 
    SET phone = '3001234567', country_code = '+57';

    -- Find a plan (The most recently created one) to add this demo user to
    SELECT id INTO my_plan_id FROM public.plans ORDER BY created_at DESC LIMIT 1;

    IF my_plan_id IS NOT NULL THEN
        -- Add Demo User to that plan
        INSERT INTO public.plan_members (plan_id, user_id, role)
        VALUES (my_plan_id, demo_id, 'member')
        ON CONFLICT (plan_id, user_id) DO NOTHING;
    END IF;
END $$;
