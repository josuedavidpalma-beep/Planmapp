-- Link logistics items to profiles for joins
ALTER TABLE public.logistics_items
ADD CONSTRAINT logistics_items_assigned_user_id_fkey
FOREIGN KEY (assigned_user_id)
REFERENCES public.profiles(id)
ON DELETE SET NULL;

NOTIFY pgrst, 'reload schema';
