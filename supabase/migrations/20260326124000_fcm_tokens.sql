-- ==========================================
-- TABLA: fcm_tokens (Notificaciones Push)
-- ==========================================
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    token TEXT NOT NULL,
    device_type TEXT NOT NULL, -- 'android', 'ios', 'web'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, token)
);

ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Solo los dueños del token pueden verlo o modificarlo (o un admin)
CREATE POLICY "FCM Tokens Select" ON public.fcm_tokens FOR SELECT
USING (auth.uid() = user_id OR public.is_super_admin());

CREATE POLICY "FCM Tokens Insert" ON public.fcm_tokens FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "FCM Tokens Update" ON public.fcm_tokens FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "FCM Tokens Delete" ON public.fcm_tokens FOR DELETE
USING (auth.uid() = user_id);

-- Create a generic function to notify a user via edge functions (rpc) or trigger
