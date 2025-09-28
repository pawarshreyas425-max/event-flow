/*
# [CRITICAL] Full Database Function Security Patch
[This migration drops and recreates all custom database functions to enforce strict security and resolve the persistent "Function Search Path Mutable" warnings. This is the root cause of the user registration failures.]

## Query Description: [This operation will replace existing database helper functions. It is designed to be safe and non-destructive to data, but it is critical for fixing the authentication system. It ensures that all functions operate with the correct permissions and cannot access unintended schemas. This will resolve the "Database error saving new user" issue during registration.]

## Metadata:
- Schema-Category: ["Structural", "Security"]
- Impact-Level: ["High"]
- Requires-Backup: [false]
- Reversible: [false]

## Structure Details:
- Drops and recreates the following functions:
  - `public.get_user_role(uuid)`
  - `public.is_organizer_of_event(uuid)`
  - `public.is_assigned_volunteer(uuid)`
  - `public.handle_new_user()`

## Security Implications:
- RLS Status: [Enabled]
- Policy Changes: [No]
- Auth Requirements: [Fixes functions used by RLS policies]
- Resolves "Function Search Path Mutable" warnings by explicitly setting the `search_path`.

## Performance Impact:
- Indexes: [None]
- Triggers: [The `handle_new_user` trigger will now function correctly.]
- Estimated Impact: [Low performance impact. High positive impact on application stability.]
*/

-- Drop existing functions to allow for recreation with correct settings
DROP FUNCTION IF EXISTS public.get_user_role(user_id uuid);
DROP FUNCTION IF EXISTS public.is_organizer_of_event(event_id uuid);
DROP FUNCTION IF EXISTS public.is_assigned_volunteer(event_id uuid);
-- The trigger function is dropped by dropping the trigger itself
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();


-- Function to get a user's role from their profile
CREATE OR REPLACE FUNCTION public.get_user_role(user_id uuid)
RETURNS public.user_role AS $$
DECLARE
  user_role_result public.user_role;
BEGIN
  SELECT role INTO user_role_result FROM public.profiles WHERE id = user_id;
  RETURN user_role_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;


-- Function to check if the current user is the organizer of a specific event
CREATE OR REPLACE FUNCTION public.is_organizer_of_event(event_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.events
    WHERE id = event_id AND organizer_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;


-- Function to check if the current user is an assigned volunteer for a specific event
CREATE OR REPLACE FUNCTION public.is_assigned_volunteer(event_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.volunteer_assignments
    WHERE event_id = event_id AND volunteer_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;


-- Trigger function to create a profile for a new user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;


-- Recreate the trigger on the auth.users table
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
