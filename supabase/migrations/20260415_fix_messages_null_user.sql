
-- Migration: Allow system messages (null user_id)
ALTER TABLE public.messages 
ALTER COLUMN user_id DROP NOT NULL;

-- Allow system messages to be read by everyone in the plan
DROP POLICY IF EXISTS "Messages Select" ON public.messages;
CREATE POLICY "Messages Select" ON public.messages FOR SELECT
USING (
  auth.uid() = user_id 
  OR EXISTS (
    SELECT 1 FROM public.plan_members 
    WHERE plan_id = public.messages.plan_id AND user_id = auth.uid()
  )
  OR user_id IS NULL -- Allow reading system messages
);
