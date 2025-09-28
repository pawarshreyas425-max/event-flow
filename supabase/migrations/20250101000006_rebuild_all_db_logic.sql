/*
# [Fix] Complete Database Logic Rebuild
This migration script completely rebuilds the custom functions, triggers, and Row Level Security (RLS) policies to resolve persistent dependency and permission errors. It ensures a clean and stable state for the application's database logic.

## Query Description:
This is a safe, idempotent operation. It uses `DROP ... IF EXISTS` to remove any old, potentially faulty database objects before recreating them from scratch with the correct, secure definitions. This resolves errors like "policy ... already exists" and "cannot drop function ... because other objects depend on it" by correctly managing the order of operations. It also fixes the "Function Search Path Mutable" security warnings.

## Metadata:
- Schema-Category: ["Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: false (but the script is idempotent)

## Structure Details:
- Drops and recreates functions: `get_user_role`, `is_organizer`, `is_volunteer`, `handle_new_user`.
- Drops and recreates RLS policies on tables: `profiles`, `events`, `event_registrations`, `volunteer_assignments`, `event_tasks`.
- Drops and recreates trigger: `on_auth_user_created` on `auth.users`.

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes (recreates all policies correctly)
- Auth Requirements: Supabase Auth

## Performance Impact:
- Indexes: None
- Triggers: Recreates one trigger
- Estimated Impact: Negligible. This is a one-time structural fix.
*/

-- Step 1: Drop existing objects in reverse order of dependency to avoid errors.
-- We use `IF EXISTS` to make the script runnable even if some objects are missing.

-- Drop the trigger on auth.users which depends on the handle_new_user function.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Drop RLS policies that depend on helper functions.
-- Policies on 'profiles'
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;

-- Policies on 'events'
DROP POLICY IF EXISTS "Organizers can manage their own events" ON public.events;
DROP POLICY IF EXISTS "Authenticated users can view published events" ON public.events;

-- Policies on 'event_registrations'
DROP POLICY IF EXISTS "Attendees can manage their own registrations" ON public.event_registrations;
DROP POLICY IF EXISTS "Organizers can view registrations for their events" ON public.event_registrations;

-- Policies on 'volunteer_assignments'
DROP POLICY IF EXISTS "Organizers can manage volunteer assignments for their events" ON public.volunteer_assignments;
DROP POLICY IF EXISTS "Volunteers can view their own assignments" ON public.volunteer_assignments;

-- Policies on 'event_tasks'
DROP POLICY IF EXISTS "Organizers can manage tasks for their events" ON public.event_tasks;
DROP POLICY IF EXISTS "Assigned volunteers can view and update their tasks" ON public.event_tasks;

-- Drop the functions.
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.get_user_role(p_user_id uuid);
DROP FUNCTION IF EXISTS public.is_organizer(p_user_id uuid);
DROP FUNCTION IF EXISTS public.is_volunteer(p_user_id uuid);

-- Step 2: Recreate all functions with secure settings.

-- Function to get a user's role from their profile.
CREATE OR REPLACE FUNCTION public.get_user_role(p_user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (SELECT role FROM public.profiles WHERE id = p_user_id);
END;
$$;

-- Function to check if a user is an organizer.
CREATE OR REPLACE FUNCTION public.is_organizer(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (SELECT public.get_user_role(p_user_id)) = 'organizer';
END;
$$;

-- Function to check if a user is a volunteer.
CREATE OR REPLACE FUNCTION public.is_volunteer(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (SELECT public.get_user_role(p_user_id)) = 'volunteer';
END;
$$;

-- Function to create a new user profile when a new user signs up in auth.users.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
$$;

-- Step 3: Recreate the trigger.
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Step 4: Recreate all RLS policies.

-- Enable RLS on all relevant tables if not already enabled.
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.volunteer_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_tasks ENABLE ROW LEVEL SECURITY;

-- Policies for 'profiles' table
CREATE POLICY "Users can view their own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Policies for 'events' table
CREATE POLICY "Organizers can manage their own events"
  ON public.events FOR ALL
  USING (public.is_organizer(auth.uid()) AND auth.uid() = organizer_id)
  WITH CHECK (public.is_organizer(auth.uid()) AND auth.uid() = organizer_id);

CREATE POLICY "Authenticated users can view published events"
  ON public.events FOR SELECT
  USING (status = 'published');

-- Policies for 'event_registrations' table
CREATE POLICY "Attendees can manage their own registrations"
  ON public.event_registrations FOR ALL
  USING (auth.uid() = attendee_id)
  WITH CHECK (auth.uid() = attendee_id);

CREATE POLICY "Organizers can view registrations for their events"
  ON public.event_registrations FOR SELECT
  USING (
    public.is_organizer(auth.uid()) AND
    event_id IN (SELECT id FROM public.events WHERE organizer_id = auth.uid())
  );

-- Policies for 'volunteer_assignments' table
CREATE POLICY "Organizers can manage volunteer assignments for their events"
  ON public.volunteer_assignments FOR ALL
  USING (
    public.is_organizer(auth.uid()) AND
    event_id IN (SELECT id FROM public.events WHERE organizer_id = auth.uid())
  )
  WITH CHECK (
    public.is_organizer(auth.uid()) AND
    event_id IN (SELECT id FROM public.events WHERE organizer_id = auth.uid())
  );

CREATE POLICY "Volunteers can view their own assignments"
  ON public.volunteer_assignments FOR SELECT
  USING (public.is_volunteer(auth.uid()) AND auth.uid() = volunteer_id);

-- Policies for 'event_tasks' table
CREATE POLICY "Organizers can manage tasks for their events"
  ON public.event_tasks FOR ALL
  USING (
    public.is_organizer(auth.uid()) AND
    event_id IN (SELECT id FROM public.events WHERE organizer_id = auth.uid())
  )
  WITH CHECK (
    public.is_organizer(auth.uid()) AND
    event_id IN (SELECT id FROM public.events WHERE organizer_id = auth.uid())
  );

CREATE POLICY "Assigned volunteers can view and update their tasks"
  ON public.event_tasks FOR ALL
  USING (public.is_volunteer(auth.uid()) AND auth.uid() = volunteer_id)
  WITH CHECK (public.is_volunteer(auth.uid()) AND auth.uid() = volunteer_id);
