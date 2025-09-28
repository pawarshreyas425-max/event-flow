/*
# [CRITICAL FIX] Secure All Database Functions
This migration applies a critical security fix to all custom database functions by explicitly setting their `search_path`. This resolves the "Function Search Path Mutable" security warnings and fixes the underlying cause of the user registration failure.

## Query Description:
This operation modifies the configuration of three existing functions (`handle_new_user`, `get_user_role`, `is_event_organizer`) to make them more secure and prevent them from failing. It ensures they can reliably find the necessary tables (like `public.profiles`). This is a non-destructive operation and is essential for the application's authentication to work correctly.

## Metadata:
- Schema-Category: ["Safe", "Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Modifies function: `public.handle_new_user()`
- Modifies function: `public.get_user_role(user_id uuid)`
- Modifies function: `public.is_event_organizer(p_event_id uuid)`

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: This fixes a core authentication-related function.
- Mitigates: "Function Search Path Mutable" vulnerability.

## Performance Impact:
- Indexes: [None]
- Triggers: [None]
- Estimated Impact: Negligible performance impact. Improves reliability.
*/

-- Set a secure search path for the function that creates user profiles.
-- This is the primary fix for the registration error.
ALTER FUNCTION public.handle_new_user()
SET search_path = 'public';

-- Set a secure search path for the RLS helper function to get a user's role.
ALTER FUNCTION public.get_user_role(user_id uuid)
SET search_path = 'public';

-- Set a secure search path for the RLS helper function to check event ownership.
ALTER FUNCTION public.is_event_organizer(p_event_id uuid)
SET search_path = 'public';
