-- Migration: Create support tickets table and bucket
-- Created at: 2026-04-17

CREATE TABLE IF NOT EXISTS public.support_tickets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    image_url TEXT,
    status TEXT DEFAULT 'open',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

-- Policy: Users can insert their own tickets
CREATE POLICY "Allow users to insert their own tickets" 
ON public.support_tickets FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can view their own tickets
CREATE POLICY "Allow users to view their own tickets"
ON public.support_tickets FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Create Storage Bucket for support images
INSERT INTO storage.buckets (id, name, public) 
VALUES ('support_images', 'support_images', true) 
ON CONFLICT DO NOTHING;

-- Storage Policies for support_images
CREATE POLICY "Allow authenticated uploads to support_images" 
ON storage.objects 
FOR INSERT 
TO authenticated 
WITH CHECK (bucket_id = 'support_images' AND auth.role() = 'authenticated');

CREATE POLICY "Allow public read of support_images" 
ON storage.objects 
FOR SELECT 
TO public 
USING (bucket_id = 'support_images');
