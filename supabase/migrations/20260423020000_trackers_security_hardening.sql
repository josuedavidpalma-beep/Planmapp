-- Security hardening for payment_trackers

ALTER TABLE public.payment_trackers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS " Tracker read policy\ ON public.payment_trackers;
CREATE POLICY \Tracker read policy\ ON public.payment_trackers FOR SELECT TO authenticated USING (
 user_id = auth.uid()
 OR responsible_user_id = auth.uid()
 OR plan_id IN (SELECT id FROM public.plans WHERE creator_id = auth.uid())
 OR plan_id IN (SELECT plan_id FROM public.plan_members WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS \Tracker insert policy\ ON public.payment_trackers;
CREATE POLICY \Tracker insert policy\ ON public.payment_trackers FOR INSERT TO authenticated WITH CHECK (
 plan_id IN (SELECT id FROM public.plans WHERE creator_id = auth.uid())
 OR plan_id IN (SELECT plan_id FROM public.plan_members WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS \Tracker update policy\ ON public.payment_trackers;
CREATE POLICY \Tracker update policy\ ON public.payment_trackers FOR UPDATE TO authenticated USING (
 user_id = auth.uid()
 OR responsible_user_id = auth.uid()
 OR plan_id IN (SELECT id FROM public.plans WHERE creator_id = auth.uid())
);

DROP POLICY IF EXISTS \Tracker delete policy\ ON public.payment_trackers;
CREATE POLICY \Tracker delete policy\ ON public.payment_trackers FOR DELETE TO authenticated USING (
 plan_id IN (SELECT id FROM public.plans WHERE creator_id = auth.uid())
);
