/*
# [CRITICAL FIX] Recreate Database Helper Functions
[This migration corrects a critical error from previous migrations by safely dropping and recreating the `get_user_role` function. It also hardens the security of all related helper functions to resolve persistent authentication and authorization issues.]

## Query Description: [This operation will drop the existing `get_user_role` function and recreate it with the correct return type. It also replaces other helper functions to enforce strict security settings. This is a safe operation as it only affects function definitions and does not alter any table data. This is the definitive fix for the registration errors.]

## Metadata:
- Schema-Category: ["Structural"]
- Impact-Level: ["Medium"]
- Requires-Backup: [false]
- Reversible: [false]

## Structure Details:
- Drops function: `public.get_user_role(uuid)`
- Creates function: `public.get_user_role(uuid)`
- Replaces function: `public.is_organizer_of_event(uuid)`
- Replaces function: `public.is_volunteer_for_event(uuid)`

## Security Implications:
- RLS Status: [Enabled]
- Policy Changes: [No]
- Auth Requirements: [This fixes functions used by RLS policies.]
- All functions are set to `SECURITY DEFINER` with a fixed `search_path` to resolve security warnings.

## Performance Impact:
- Indexes: [None]
- Triggers: [None]
- Estimated Impact: [Low. Function recreation is a fast metadata operation.]
*/

-- Step 1: Drop the existing function that has the wrong return type.
-- This is necessary because PostgreSQL cannot change the return type of a function with CREATE OR REPLACE.
DROP FUNCTION IF EXISTS public.get_user_role(user_id uuid);

-- Step 2: Recreate the function with the correct return type (text).
-- This function retrieves the role of a user from their profile.
CREATE OR REPLACE FUNCTION public.get_user_role(user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (SELECT role FROM public.profiles WHERE id = user_id);
END;
$$;

-- Step 3: Recreate the organizer check function with security settings.
-- This function checks if the currently authenticated user is the organizer of a specific event.
CREATE OR REPLACE FUNCTION public.is_organizer_of_event(event_id_to_check uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.events
    WHERE id = event_id_to_check AND organizer_id = auth.uid()
  );
END;
$$;

-- Step 4: Recreate the volunteer check function with security settings.
-- This function checks if the currently authenticated user is a volunteer for a specific event.
CREATE OR REPLACE FUNCTION public.is_volunteer_for_event(event_id_to_check uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.volunteer_assignments
    WHERE event_id = event_id_to_check AND volunteer_id = auth.uid()
  );
END;
$$;

-- Step 5: Grant execute permissions to the necessary roles.
-- The `authenticated` role needs to be able to call these functions for RLS policies to work.
GRANT EXECUTE ON FUNCTION public.get_user_role(user_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_organizer_of_event(event_id_to_check uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_volunteer_for_event(event_id_to_check uuid) TO authenticated;
