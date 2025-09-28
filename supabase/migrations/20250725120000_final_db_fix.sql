/*
          # [Function Creation and Security Update]
          Creates the missing `get_user_role` function and fixes the 'Function Search Path Mutable' security warnings for all relevant functions. This is the definitive fix for the database dependency errors that were causing user registration to fail.

          ## Query Description: This operation creates a new function (`get_user_role`) that was missing and modifies an existing function (`handle_new_user`) to enhance security. It is a safe, non-destructive change that resolves the root cause of the previous migration failures and the ongoing registration issue.

          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true (by dropping the function and reverting the alter statement)

          ## Structure Details:
          - Functions created:
            - public.get_user_role(uuid)
          - Functions affected:
            - public.handle_new_user()

          ## Security Implications:
          - RLS Status: Unchanged. This fix enables existing RLS policies to work correctly.
          - Policy Changes: No.
          - Auth Requirements: None. This fixes functions used by the authentication trigger and RLS.

          ## Performance Impact:
          - Indexes: None
          - Triggers: The `on_auth_user_created` trigger will now function correctly.
          - Estimated Impact: Negligible performance impact. This change improves reliability and security.
          */

-- Creates the function required by RLS policies, which was missing.
create or replace function public.get_user_role(user_id uuid)
returns text
language sql
security definer
set search_path = public
as $$
  select role from public.profiles where id = user_id;
$$;

-- Secures the user creation trigger function by setting a fixed search path.
alter function public.handle_new_user() set search_path = public;
