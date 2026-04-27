-- Migración: Añadir sistema de suscripciones / Tiers a Restaurantes B2B
-- Opciones esperadas: 'basic', 'premium', 'gold'

ALTER TABLE public.restaurants 
ADD COLUMN IF NOT EXISTS tier VARCHAR(20) DEFAULT 'basic';

-- Nota: Las reglas de RLS de Supabase para esta tabla ya restringen UPDATE al email maestro.
-- Ver `20260424010000_b2b2c_phase1.sql` (CREATE POLICY "Admin can update restaurants").
