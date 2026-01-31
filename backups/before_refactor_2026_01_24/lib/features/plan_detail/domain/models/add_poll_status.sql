-- Migration to add status to polls and draft support
-- Created by Antigravity

ALTER TABLE public.polls ADD COLUMN IF NOT EXISTS status text DEFAULT 'active';

-- Backfill existing as active
UPDATE public.polls SET status = 'active' WHERE status IS NULL;

-- Allow editing options if draft? Not handling via RLS yet, relying on app logic.
-- Drafts are visible to creators mainly, but for now we let everyone see them if they exist.
-- Ideally we would hide drafts from members, but MVP: show in "Borradores" tab.
