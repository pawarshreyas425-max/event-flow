/*
          # [Comprehensive Reset and Re-creation of DB Logic]
          This migration provides a complete and idempotent reset of all custom database functions, triggers, and Row Level Security (RLS) policies. It is designed to fix "object already exists" or "dependency" errors from previous failed migrations by ensuring a clean and correct state.

          ## Query Description: [This operation will safely drop and recreate all custom database logic. It first removes existing triggers and policies to avoid dependency conflicts, then rebuilds them with secure and correct definitions. This is a safe operation designed to stabilize the database schema and will not result in data loss.]
          
          ## Metadata:
          - Schema-Category: ["Structural"]
          - Impact-Level: ["Medium"]
          - Requires-Backup: [false]
          - Reversible: [false]
          
          ## Structure Details:
          - Drops and recreates the `on_auth_user_created` trigger.
          - Drops and recreates all custom functions: `handle_new_user`, `get_user_role`, `is_organizer`, `is_volunteer`, `is_attendee`.
          - Drops and recreates all RLS policies on tables: `profiles`, `events`, `event_registrations`, `volunteer_assignments`, `event_tasks`.
          
          ## Security Implications:
          - RLS Status: [Enabled]
          - Policy Changes: [Yes]
          - Auth Requirements: [This script fixes authentication-related database logic.]
          
          ## Performance Impact:
          - Indexes: [Not Affected]
          - Triggers: [Recreated]
          - Estimated Impact: [Low. This is a one-time structural fix.]
          */

-- Step 1: Drop the trigger that depends on the function we need to modify.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Step 2: Drop all related functions.
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.get_user_role(uuid);
DROP FUNCTION IF EXISTS public.is_organizer(uuid);
DROP FUNCTION IF EXISTS public.is_volunteer(uuid);
DROP FUNCTION IF EXISTS public.is_attendee(uuid);

-- Step 3: Drop all existing RLS policies on the affected tables.
-- This is the most critical part to fix the "policy ... already exists" error.
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Organizers can manage their own events" ON public.events;
DROP POLICY IF EXISTS "Authenticated users can view published events" ON public.events;
DROP POLICY IF EXISTS "Volunteers can view their assigned events" ON public.events;
DROP POLICY IF EXISTS "Attendees can manage their own registrations" ON public.event_registrations;
DROP POLICY IF EXISTS "Organizers can view registrations for their events" ON public.event_registrations;
DROP POLICY IF EXISTS "Organizers can manage volunteer assignments for their events" ON public.volunteer_assignments;
DROP POLICY IF EXISTS "Volunteers can view their own assignments" ON public.volunteer_assignments;
DROP POLICY IF EXISTS "Organizers can manage tasks for their events" ON public.event_tasks;
DROP POLICY IF EXISTS "Assigned volunteers can view and update their tasks" ON public.event_tasks;


-- Step 4: Recreate all functions with secure definitions.

-- Function to get a user's role from the profiles table.
CREATE OR REPLACE FUNCTION public.get_user_role(p_user_id uuid)
RETURNS public.user_role AS $$
DECLARE
  v_role public.user_role;
BEGIN
  SELECT role INTO v_role FROM public.profiles WHERE id = p_user_id;
  RETURN v_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Boolean helper functions for RLS policies.
CREATE OR REPLACE FUNCTION public.is_organizer(p_user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN public.get_user_role(p_user_id) = 'organizer';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.is_volunteer(p_user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN public.get_user_role(p_user_id) = 'volunteer';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.is_attendee(p_user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN public.get_user_role(p_user_id) = 'attendee';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Function to create a new user profile.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- Step 5: Recreate the trigger on the auth.users table.
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- Step 6: Recreate all RLS policies.

-- Policies for 'profiles' table
CREATE POLICY "Users can view their own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Policies for 'events' table
CREATE POLICY "Authenticated users can view published events" ON public.events
  FOR SELECT USING (status = 'published');

CREATE POLICY "Organizers can manage their own events" ON public.events
  FOR ALL USING (auth.uid() = organizer_id);

CREATE POLICY "Volunteers can view their assigned events" ON public.events
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.volunteer_assignments
      WHERE event_id = public.events.id AND volunteer_id = auth.uid()
    )
  );

-- Policies for 'event_registrations' table
CREATE POLICY "Attendees can manage their own registrations" ON public.event_registrations
  FOR ALL USING (auth.uid() = attendee_id);

CREATE POLICY "Organizers can view registrations for their events" ON public.event_registrations
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.events
      WHERE id = public.event_registrations.event_id AND organizer_id = auth.uid()
    )
  );

-- Policies for 'volunteer_assignments' table
CREATE POLICY "Organizers can manage volunteer assignments for their events" ON public.volunteer_assignments
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.events
      WHERE id = public.volunteer_assignments.event_id AND organizer_id = auth.uid()
    )
  );

CREATE POLICY "Volunteers can view their own assignments" ON public.volunteer_assignments
  FOR SELECT USING (auth.uid() = volunteer_id);

-- Policies for 'event_tasks' table
CREATE POLICY "Organizers can manage tasks for their events" ON public.event_tasks
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.events
      WHERE id = public.event_tasks.event_id AND organizer_id = auth.uid()
    )
  );

CREATE POLICY "Assigned volunteers can view and update their tasks" ON public.event_tasks
  FOR ALL USING (auth.uid() = volunteer_id);
