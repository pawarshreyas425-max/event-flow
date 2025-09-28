/*
# [Function] Create get_user_role
This function retrieves the role of a user from the profiles table based on their user ID. It is essential for Row Level Security policies to determine a user's permissions, and its absence was causing the migration error.

## Query Description:
This operation creates a new, safe database function. It has no impact on existing data and is crucial for fixing the reported error "function public.get_user_role(uuid) does not exist". It resolves a missing dependency in the database schema.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (the function can be dropped)

## Structure Details:
- Creates function: `public.get_user_role(user_id uuid)`

## Security Implications:
- RLS Status: This function is used by RLS policies.
- Policy Changes: No
- Auth Requirements: The function uses the user's ID.
- Defines the function with `SECURITY DEFINER` to run with the permissions of the function owner.
- Sets a fixed `search_path` to prevent search path hijacking vulnerabilities, addressing previous security warnings.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible. The function performs a simple, indexed lookup.
*/

CREATE OR REPLACE FUNCTION public.get_user_role(user_id uuid)
RETURNS public.user_role AS $$
DECLARE
  user_role_result public.user_role;
BEGIN
  -- Select the role from the profiles table for the given user ID
  SELECT role INTO user_role_result FROM public.profiles WHERE id = user_id;
  RETURN user_role_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Set a secure search path for the function to prevent potential hijacking.
ALTER FUNCTION public.get_user_role(uuid) SET search_path = public;
