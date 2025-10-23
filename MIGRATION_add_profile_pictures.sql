-- Migration: Add Profile Picture Upload Support
-- This migration creates a Supabase Storage bucket for profile pictures
-- and sets up the necessary security policies

-- Create the avatars bucket for storing profile pictures
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS on the storage.objects table (if not already enabled)
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Policy: Allow users to upload their own profile pictures
-- Users can only insert files into their own folder (named with their user ID)
CREATE POLICY "Users can upload their own avatar"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow users to update their own profile pictures
CREATE POLICY "Users can update their own avatar"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow users to delete their own profile pictures
CREATE POLICY "Users can delete their own avatar"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow everyone to view all profile pictures (public bucket)
CREATE POLICY "Anyone can view avatars"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- Verify the bucket was created
SELECT * FROM storage.buckets WHERE id = 'avatars';

-- Notes:
-- 1. Profile pictures will be stored with the path: {user_id}/avatar.{extension}
-- 2. The avatar field in the profiles table will store either:
--    - An emoji character (for users who haven't uploaded a picture)
--    - A full Supabase Storage URL (for users who have uploaded a picture)
-- 3. The app will automatically detect and display the appropriate format
