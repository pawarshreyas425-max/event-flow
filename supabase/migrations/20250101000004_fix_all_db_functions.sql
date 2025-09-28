/*
          # [Fix All RLS Helper Functions]
          This migration secures all helper functions used by Row Level Security (RLS) policies by explicitly setting the `search_path`. The previous migration only fixed the user creation trigger, but not the functions that the RLS policies depend on, causing the user creation to fail silently within the database transaction. This script corrects the `is_organizer`, `is_volunteer`, and `is_attendee` functions.

          ## Query Description: [This operation modifies existing database functions to improve security and reliability. It sets a fixed `search_path` to prevent potential security vulnerabilities and resolve errors where functions cannot find the tables they need to operate on. This change is safe and essential for the correct functioning of user registration and data access. No data will be modified.]
          
          ## Metadata:
          - Schema-Category: "Safe"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - Modifies function: `public.is_organizer(user_id uuid)`
          - Modifies function: `public.is_volunteer(user_id uuid)`
          - Modifies function: `public.is_attendee(user_id uuid)`
          
          ## Security Implications:
          - RLS Status: Enabled
          - Policy Changes: No (but fixes the functions these policies rely on)
          - Auth Requirements: None
          
          ## Performance Impact:
          - Indexes: None
          - Triggers: None
          - Estimated Impact: Negligible. May slightly improve performance by providing a direct search path.
          */

-- Secure the is_organizer function
CREATE OR REPLACE FUNCTION public.is_organizer(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM profiles
    WHERE profiles.id = user_id AND profiles.role = 'organizer'
  );
END;
$$;

-- Secure the is_volunteer function
CREATE OR REPLACE FUNCTION public.is_volunteer(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM profiles
    WHERE profiles.id = user_id AND profiles.role = 'volunteer'
  );
END;
$$;

-- Secure the is_attendee function
CREATE OR REPLACE FUNCTION public.is_attendee(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM profiles
    WHERE profiles.id = user_id AND profiles.role = 'attendee'
  );
END;
$$;
