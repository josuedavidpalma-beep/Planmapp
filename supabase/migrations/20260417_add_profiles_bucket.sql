-- Migration: Ensure 'profiles' bucket exists for Avatars
-- Created at: 2026-04-17

-- Create Storage Bucket for avatars
INSERT INTO storage.buckets (id, name, public) 
VALUES ('profiles', 'profiles', true) 
ON CONFLICT DO NOTHING;

-- Storage Policies for profiles
CREATE POLICY "Allow authenticated uploads to profiles" 
ON storage.objects 
FOR INSERT 
TO authenticated 
WITH CHECK (bucket_id = 'profiles' AND auth.role() = 'authenticated');

CREATE POLICY "Allow public read of profiles" 
ON storage.objects 
FOR SELECT 
TO public 
USING (bucket_id = 'profiles');

CREATE POLICY "Allow users to update their own avatar" 
ON storage.objects 
FOR UPDATE 
TO authenticated 
USING (bucket_id = 'profiles' AND auth.uid()::text = (string_to_array(name, '/'))[1]);

CREATE POLICY "Allow users to delete their own avatar" 
ON storage.objects 
FOR DELETE 
TO authenticated 
USING (bucket_id = 'profiles' AND auth.uid()::text = (string_to_array(name, '/'))[1]);
