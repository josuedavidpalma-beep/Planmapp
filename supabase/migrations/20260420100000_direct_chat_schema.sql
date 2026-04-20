-- Migration: Add direct_chat flag to plans
-- Created at: 2026-04-20

-- Agregamos la columna boolean
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS is_direct_chat BOOLEAN DEFAULT false;

-- Si quisieras asegurar que un chat directo tiene título e info vacía, puedes poner una restricción
-- Pero por ahora, dejar default false es suficiente.

-- Opcional: Policy para asegurar que si is_direct_chat = true, no existan más de 2 plan_members.
-- Esto se puede controlar mejor en la capa de aplicación o mediante un Trigger,
-- pero por ahora lo dejamos a merced del frontend.
