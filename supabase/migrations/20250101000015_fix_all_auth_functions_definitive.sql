/*
          # [Definitive Auth Function Fix]
          This migration provides a comprehensive and final fix for all authentication-related database functions. It addresses the persistent "Function Search Path Mutable" security warnings by explicitly setting the search_path and correctly defining security contexts. This will resolve the root cause of the user registration failures.

          ## Query Description: [This operation will replace the existing, faulty database functions (`get_user_role`, `is_organizer`, `handle_new_user`) with secure and correct versions. There is no risk to existing user data, as this only affects the logic for creating and authenticating new users. This is a safe and necessary fix.]
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - Functions being replaced: `public.get_user_role`, `public.is_organizer`, `public.handle_new_user`
          
          ## Security Implications:
          - RLS Status: Unchanged
          - Policy Changes: No
          - Auth Requirements: This fixes the core authentication trigger.
          
          ## Performance Impact:
          - Indexes: None
          - Triggers: The `on_auth_user_created` trigger will now function correctly.
          - Estimated Impact: "Negligible performance impact. This is a logic and security fix."
          */

-- Drop the existing problematic functions and trigger to ensure a clean slate.
-- This is necessary because of the previous faulty migration attempts.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.get_user_role(uuid);
DROP FUNCTION IF EXISTS public.is_organizer(uuid);


-- Function to get a user's role from their profile.
-- SECURE: Sets a specific search_path and runs as SECURITY DEFINER.
CREATE OR REPLACE FUNCTION public.get_user_role(user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (SELECT role FROM profiles WHERE id = user_id);
END;
$$;

-- Function to check if a user is an organizer.
-- SECURE: Sets a specific search_path and runs as SECURITY DEFINER.
CREATE OR REPLACE FUNCTION public.is_organizer(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (SELECT role FROM profiles WHERE id = user_id) = 'organizer';
END;
$$;

-- Trigger function to create a profile for a new user.
-- SECURE: Sets a specific search_path.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role, phone)
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    (new.raw_user_meta_data->>'role')::public.user_role,
    new.raw_user_meta_data->>'phone'
  );
  RETURN new;
END;
$$;

-- Recreate the trigger on the auth.users table.
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Re-enable RLS on the profiles table, which might have been affected.
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Grant usage on the new functions to the authenticated role.
GRANT EXECUTE ON FUNCTION public.get_user_role(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_organizer(uuid) TO authenticated;
