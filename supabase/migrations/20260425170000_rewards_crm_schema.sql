-- 1. Modificar encuestas para soportar identidad B2B
ALTER TABLE public.survey_responses 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS user_name TEXT;

-- 2. Crear tabla de Recompensas y Cupones (CRM B2B2C)
CREATE TABLE public.restaurant_rewards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    restaurant_id UUID NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    promo_code TEXT NOT NULL UNIQUE,
    discount_percentage INT NOT NULL DEFAULT 10,
    is_redeemed BOOLEAN DEFAULT false,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS para Rewards
ALTER TABLE public.restaurant_rewards ENABLE ROW LEVEL SECURITY;

-- Los usuarios ven los suyos
CREATE POLICY "Users view own rewards" ON public.restaurant_rewards 
    FOR SELECT USING (auth.uid() = user_id);

-- Los administradores (email maestro) insertan, y actualizan
CREATE POLICY "Admin full access to rewards" ON public.restaurant_rewards 
    FOR ALL USING (auth.jwt() ->> 'email' = 'josuedavidpalma@gmail.com')
    WITH CHECK (auth.jwt() ->> 'email' = 'josuedavidpalma@gmail.com');
