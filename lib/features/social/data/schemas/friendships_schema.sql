-- Create friendships table
CREATE TABLE IF NOT EXISTS public.friendships (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    requester_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    status TEXT CHECK (status IN ('pending', 'accepted', 'blocked')) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(requester_id, receiver_id)
);

-- Enable RLS
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

-- Policies
-- 1. Users can view their own friendships (either sent or received)
CREATE POLICY "Users can view their own friendships" ON public.friendships
    FOR SELECT USING (auth.uid() = requester_id OR auth.uid() = receiver_id);

-- 2. Users can create a friendship request (as requester)
CREATE POLICY "Users can create friendship requests" ON public.friendships
    FOR INSERT WITH CHECK (auth.uid() = requester_id);

-- 3. Users can update friendships involve them (accepting requests, blocking)
-- Ideally strictly: Receiver can update status to 'accepted' or 'blocked'. Requester can maybe cancel?
-- For simplicity: Allow update if user is involved.
CREATE POLICY "Users can update their own friendships" ON public.friendships
    FOR UPDATE USING (auth.uid() = requester_id OR auth.uid() = receiver_id);

-- 4. Users can delete their own friendships (unfriend/cancel request)
CREATE POLICY "Users can delete their own friendships" ON public.friendships
    FOR DELETE USING (auth.uid() = requester_id OR auth.uid() = receiver_id);

-- Helper function to search users (if not exists)
-- This assumes we have a 'profiles' table or similar that is publicly searchable by username/email
-- If not, we might need one.
