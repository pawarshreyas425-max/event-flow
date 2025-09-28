/*
# [Fix User Creation Trigger]
This migration fixes the `handle_new_user` function, which is responsible for creating a profile entry after a new user signs up. The original function was missing a `search_path`, causing it to fail intermittently and preventing new user registrations. This update makes the function secure and reliable.

## Query Description:
- This operation replaces the existing `handle_new_user` function with a corrected version.
- It explicitly sets the `search_path` to `public`, ensuring the function can always find the `profiles` table and `user_role` type.
- This is a non-destructive change that only affects the logic for *new* user sign-ups. Existing users and data are not affected.

## Metadata:
- Schema-Category: ["Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Modifies: `public.handle_new_user()` function

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: This function is a `security definer` and this change makes it more secure by preventing `search_path` manipulation.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible. This fixes a bug and has no negative performance impact.
*/

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
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

-- The trigger itself does not need to be recreated, as it already points to the function being replaced.
-- This comment is for clarity. The above function replacement is sufficient.
