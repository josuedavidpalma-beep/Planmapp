-- Migración: Papelera y Archivos para Planes
-- Creada en 2026-03-26

ALTER TABLE public.plans 
  ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- La lógica de borrado autoamatizado (24h para papelera, 7 días para archivo)
-- Normalmente se maneja en Edge Functions cron, pero aquí solo dejamos la estructura base lista.
