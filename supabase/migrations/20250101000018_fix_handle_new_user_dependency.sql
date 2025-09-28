/*
          # [Operation Name] Fix handle_new_user Function and Trigger Dependency
          [This operation safely replaces the handle_new_user function by first dropping the dependent trigger, then recreating both the function and the trigger correctly.]

          ## Query Description: [This script resolves a critical dependency error that prevented previous migrations from applying. It first removes the 'on_auth_user_created' trigger, then replaces the faulty 'handle_new_user' function with a secure and correct version, and finally recreates the trigger. This ensures the user profile creation process works reliably upon new user signup.]
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "High"
          - Requires-Backup: true
          - Reversible: false
          
          ## Structure Details:
          - Drops trigger: on_auth_user_created on auth.users
          - Drops function: public.handle_new_user()
          - Creates function: public.handle_new_user()
          - Creates trigger: on_auth_user_created on auth.users
          
          ## Security Implications:
          - RLS Status: Enabled
          - Policy Changes: No
          - Auth Requirements: This function is called by a trigger on the auth.users table.
          
          ## Performance Impact:
          - Indexes: None
          - Triggers: Replaces an existing trigger. No significant performance impact is expected.
          - Estimated Impact: [Low. This is a foundational fix for the authentication flow.]
          */

-- Step 1: Drop the existing trigger that depends on the function.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Step 2: Drop the old, faulty function.
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Step 3: Create the new, correct, and secure version of the function.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role, phone)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data ->> 'full_name',
    (NEW.raw_user_meta_data ->> 'role')::public.user_role,
    NEW.raw_user_meta_data ->> 'phone'
  );
  RETURN NEW;
END;
$$;

-- Step 4: Recreate the trigger to call the new function after a user is created.
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
