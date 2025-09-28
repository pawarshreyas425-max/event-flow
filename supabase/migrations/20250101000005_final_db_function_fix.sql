/*
# [CRITICAL] Final Database Function Security and Registration Fix
This migration provides a comprehensive and final fix for the user registration and database function security issues. It addresses the persistent "Function Search Path Mutable" warnings by securely redefining all necessary helper and trigger functions.

## Query Description:
This operation will replace the existing database functions (`handle_new_user`, `get_user_role`, `is_organizer_of_event`) with new, secure versions. This is a safe, non-destructive operation that corrects backend logic. It does not affect existing user data but is critical for allowing new user registrations to succeed.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Medium"
- Requires-Backup: false
- Reversible: true (by restoring previous function versions, though not recommended)

## Structure Details:
- Modifies function: `public.handle_new_user()`
- Modifies function: `public.get_user_role(uuid)`
- Modifies function: `public.is_organizer_of_event(uuid, uuid)`
- Affects trigger: `on_auth_user_created` on `auth.users`

## Security Implications:
- RLS Status: Enabled
- Policy Changes: No
- Auth Requirements: This fixes a core issue with the authentication trigger.
- Security Improvement: Explicitly sets `search_path` on all functions to resolve the "Function Search Path Mutable" security advisory.

## Performance Impact:
- Indexes: None
- Triggers: Replaces trigger logic to be more robust.
- Estimated Impact: Negligible performance impact. Improves reliability of user creation.
*/

-- 1. Securely redefine the function to get a user's role.
CREATE OR REPLACE FUNCTION public.get_user_role(p_user_id uuid)
RETURNS public."user_role"
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_role public."user_role";
BEGIN
  SELECT role INTO v_role
  FROM public.profiles
  WHERE id = p_user_id;
  RETURN v_role;
END;
$$;

-- 2. Securely redefine the function to check if a user is an event organizer.
CREATE OR REPLACE FUNCTION public.is_organizer_of_event(p_user_id uuid, p_event_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.events
    WHERE id = p_event_id AND organizer_id = p_user_id
  );
END;
$$;

-- 3. Securely redefine the trigger function to handle new user creation.
-- This is the most critical fix for the registration issue.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, role, phone)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.email,
    (new.raw_user_meta_data->>'role')::public."user_role",
    new.raw_user_meta_data->>'phone'
  );
  RETURN new;
END;
$$;

-- 4. Re-apply the trigger to ensure it uses the updated function.
-- This might be redundant if the trigger definition hasn't changed, but it's good practice to ensure it's linked correctly.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
