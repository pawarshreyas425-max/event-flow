/*
# [CRITICAL] Full Database Function & Policy Rebuild
This migration performs a complete teardown and rebuild of all custom database functions and Row Level Security (RLS) policies. This is a critical operation to resolve persistent dependency and security issues.

## Query Description:
This script will first DROP all custom functions and their dependent objects (like triggers and RLS policies) using CASCADE. It then recreates them with secure, corrected definitions. This is necessary to fix the "cannot drop function... because other objects depend on it" error and resolve all "Function Search Path Mutable" security warnings.

- Impact: All RLS policies will be temporarily removed and then reapplied. The `handle_new_user` trigger will be dropped and recreated.
- Risk: Medium. If the script fails midway, RLS could be left in an inconsistent state.
- Precaution: A database backup is strongly recommended before applying this migration.

## Metadata:
- Schema-Category: "Dangerous"
- Impact-Level: "High"
- Requires-Backup: true
- Reversible: false

## Structure Details:
- Functions Dropped & Recreated: `handle_new_user`, `get_user_role`, `is_organizer_of_event`
- Triggers Dropped & Recreated: `on_auth_user_created` on `auth.users`
- Policies Dropped & Recreated: All RLS policies on `profiles`, `events`, `event_registrations`, `volunteer_assignments`, `event_tasks`.

## Security Implications:
- RLS Status: Re-enabled and corrected.
- Policy Changes: Yes, all policies are redefined.
- Auth Requirements: This script modifies objects related to auth.
*/

-- Step 1: Drop all existing custom functions and their dependent objects (triggers, policies).
-- The CASCADE option is crucial to resolve the dependency errors.
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.get_user_role(p_user_id uuid) CASCADE;
DROP FUNCTION IF EXISTS public.is_organizer_of_event(p_event_id uuid, p_user_id uuid) CASCADE;


-- Step 2: Recreate the functions with secure and correct definitions.

-- Function to get a user's role from their profile.
CREATE OR REPLACE FUNCTION public.get_user_role(p_user_id uuid)
RETURNS public.user_role AS $$
DECLARE
  v_role public.user_role;
BEGIN
  SELECT role INTO v_role FROM public.profiles WHERE id = p_user_id;
  RETURN v_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Set a secure search path for the function.
ALTER FUNCTION public.get_user_role(p_user_id uuid) SET search_path = public;


-- Function to check if a user is the organizer of a specific event.
CREATE OR REPLACE FUNCTION public.is_organizer_of_event(p_event_id uuid, p_user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.events
    WHERE id = p_event_id AND organizer_id = p_user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Set a secure search path for the function.
ALTER FUNCTION public.is_organizer_of_event(p_event_id uuid, p_user_id uuid) SET search_path = public;


-- Function to create a new user profile when a new user signs up in auth.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Set a secure search path for the function.
ALTER FUNCTION public.handle_new_user() SET search_path = public;


-- Step 3: Recreate the trigger that was dropped by the CASCADE.
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();


-- Step 4: Re-enable RLS on all tables and recreate the policies that were dropped.

-- Table: profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Table: events
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Events are public to view" ON public.events
  FOR SELECT USING (true);
CREATE POLICY "Organizers can manage their own events" ON public.events
  FOR ALL USING (public.get_user_role(auth.uid()) = 'organizer' AND organizer_id = auth.uid())
  WITH CHECK (public.get_user_role(auth.uid()) = 'organizer' AND organizer_id = auth.uid());

-- Table: event_registrations
ALTER TABLE public.event_registrations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Attendees can view their own registrations" ON public.event_registrations
  FOR SELECT USING (auth.uid() = attendee_id);
CREATE POLICY "Organizers can view registrations for their events" ON public.event_registrations
  FOR SELECT USING (public.is_organizer_of_event(event_id, auth.uid()));
CREATE POLICY "Attendees can create registrations for themselves" ON public.event_registrations
  FOR INSERT WITH CHECK (public.get_user_role(auth.uid()) = 'attendee' AND auth.uid() = attendee_id);
CREATE POLICY "Attendees can cancel their own registrations" ON public.event_registrations
  FOR UPDATE USING (auth.uid() = attendee_id) WITH CHECK (auth.uid() = attendee_id);
CREATE POLICY "Organizers can manage check-ins for their events" ON public.event_registrations
  FOR UPDATE USING (public.is_organizer_of_event(event_id, auth.uid()));

-- Table: volunteer_assignments
ALTER TABLE public.volunteer_assignments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Volunteers can see their own assignments" ON public.volunteer_assignments
  FOR SELECT USING (auth.uid() = volunteer_id);
CREATE POLICY "Organizers can see assignments for their events" ON public.volunteer_assignments
  FOR SELECT USING (public.is_organizer_of_event(event_id, auth.uid()));
CREATE POLICY "Organizers can manage volunteer assignments" ON public.volunteer_assignments
  FOR ALL USING (public.is_organizer_of_event(event_id, auth.uid()));

-- Table: event_tasks
ALTER TABLE public.event_tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Volunteers can view and update their own tasks" ON public.event_tasks
  FOR ALL USING (auth.uid() = volunteer_id);
CREATE POLICY "Organizers can manage tasks for their events" ON public.event_tasks
  FOR ALL USING (public.is_organizer_of_event(event_id, auth.uid()));
