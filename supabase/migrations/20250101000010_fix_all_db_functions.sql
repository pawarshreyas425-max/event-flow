/*
# [CRITICAL FIX] Correct All Database Function Definitions
[This migration drops and recreates critical database functions to resolve a persistent naming conflict and apply necessary security settings. This is the definitive fix for the registration and authentication errors.]

## Query Description: [This operation will drop and recreate the 'get_user_role' and 'handle_new_user' functions. This is a safe operation as it only affects the function definitions, not the data itself. It is necessary to fix the "cannot change name of input parameter" error and secure the functions to resolve the long-standing registration issues.]

## Metadata:
- Schema-Category: ["Structural", "Safe"]
- Impact-Level: ["Low"]
- Requires-Backup: [false]
- Reversible: [false]

## Structure Details:
- Drops function: public.get_user_role(uuid)
- Creates function: public.get_user_role(auth_id uuid)
- Drops function: public.handle_new_user()
- Creates function: public.handle_new_user()
- Drops trigger: on_auth_user_created on auth.users
- Creates trigger: on_auth_user_created on auth.users

## Security Implications:
- RLS Status: [Enabled]
- Policy Changes: [No]
- Auth Requirements: [None]
- This migration explicitly sets the `search_path` and uses `SECURITY DEFINER` to fix the "Function Search Path Mutable" security warnings.

## Performance Impact:
- Indexes: [None]
- Triggers: [Recreated]
- Estimated Impact: [Negligible. A one-time redefinition of functions.]
*/

-- Drop the old, problematic function first as hinted by the error.
DROP FUNCTION IF EXISTS public.get_user_role(uuid);

-- Recreate the function with the correct parameter name and security settings.
CREATE OR REPLACE FUNCTION public.get_user_role(auth_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (
    SELECT role
    FROM public.profiles
    WHERE id = auth_id
  );
END;
$$;

-- Also fix the handle_new_user function to be secure.
DROP FUNCTION IF EXISTS public.handle_new_user();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, role, phone)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.email,
    (new.raw_user_meta_data->>'role')::public.user_role,
    new.raw_user_meta_data->>'phone'
  );
  RETURN new;
END;
$$;

-- Drop and recreate the trigger to ensure it's linked to the corrected function.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
