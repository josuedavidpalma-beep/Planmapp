-- Migration to allow users to securely delete their own accounts to comply with Habeas Data

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void AS $$
BEGIN
  -- Verify the user is authenticated
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Delete from public.profiles (if exists, many foreign keys might rely on this, but we'll try)
  -- Actually, the best way in Supabase is just to delete from auth.users, and let ON DELETE CASCADE handle the rest.
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
