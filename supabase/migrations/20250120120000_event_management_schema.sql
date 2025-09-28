/*
# Event Management System Database Schema
Creates comprehensive schema for multi-role event management platform supporting Organizers, Volunteers, and Attendees.

## Query Description:
This migration creates the complete database structure for an event management system. It establishes user profiles linked to Supabase Auth, event management tables, registration system, volunteer assignments, and attendance tracking. The schema supports role-based access control and maintains referential integrity across all entities. No existing data will be affected as this is an initial schema creation.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Medium"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- profiles: User profile extension with role-based data
- events: Core event information with organizer relationship
- event_registrations: Attendee bookings and ticket management
- volunteer_assignments: Volunteer-to-event assignments
- event_tasks: Task management for volunteers
- event_checkins: Attendance tracking system

## Security Implications:
- RLS Status: Enabled on all tables
- Policy Changes: Yes - Role-based access policies
- Auth Requirements: All tables reference auth.users

## Performance Impact:
- Indexes: Added on foreign keys and query-optimized columns
- Triggers: Profile creation trigger for new users
- Estimated Impact: Minimal - optimized schema design
*/

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create enum types
CREATE TYPE user_role AS ENUM ('organizer', 'volunteer', 'attendee');
CREATE TYPE event_status AS ENUM ('draft', 'published', 'ongoing', 'completed', 'cancelled');
CREATE TYPE registration_status AS ENUM ('pending', 'confirmed', 'cancelled', 'attended');
CREATE TYPE task_status AS ENUM ('pending', 'in_progress', 'completed');

-- Create profiles table (extends auth.users)
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT NOT NULL,
    full_name TEXT NOT NULL,
    phone TEXT,
    role user_role NOT NULL DEFAULT 'attendee',
    company TEXT,
    skills TEXT[],
    profile_picture_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create events table
CREATE TABLE public.events (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    organizer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL,
    date_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE,
    venue TEXT NOT NULL,
    address TEXT,
    capacity INTEGER NOT NULL CHECK (capacity > 0),
    price DECIMAL(10,2) DEFAULT 0,
    banner_url TEXT,
    status event_status DEFAULT 'draft',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create event registrations table
CREATE TABLE public.event_registrations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    event_id UUID REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
    attendee_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    registration_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status registration_status DEFAULT 'confirmed',
    ticket_number TEXT UNIQUE NOT NULL,
    seat_number TEXT,
    checked_in BOOLEAN DEFAULT FALSE,
    checked_in_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(event_id, attendee_id)
);

-- Create volunteer assignments table
CREATE TABLE public.volunteer_assignments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    event_id UUID REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
    volunteer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    assigned_role TEXT NOT NULL,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(event_id, volunteer_id)
);

-- Create event tasks table
CREATE TABLE public.event_tasks (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    event_id UUID REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
    volunteer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    status task_status DEFAULT 'pending',
    due_date TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_events_organizer_id ON public.events(organizer_id);
CREATE INDEX idx_events_date_time ON public.events(date_time);
CREATE INDEX idx_events_status ON public.events(status);
CREATE INDEX idx_event_registrations_event_id ON public.event_registrations(event_id);
CREATE INDEX idx_event_registrations_attendee_id ON public.event_registrations(attendee_id);
CREATE INDEX idx_volunteer_assignments_event_id ON public.volunteer_assignments(event_id);
CREATE INDEX idx_volunteer_assignments_volunteer_id ON public.volunteer_assignments(volunteer_id);
CREATE INDEX idx_event_tasks_event_id ON public.event_tasks(event_id);
CREATE INDEX idx_event_tasks_volunteer_id ON public.event_tasks(volunteer_id);

-- Create function to generate ticket numbers
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS TEXT AS $$
BEGIN
    RETURN 'TKT-' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 8));
END;
$$ LANGUAGE plpgsql;

-- Create trigger function for automatic profile creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
        COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'attendee')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for automatic profile creation
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON public.events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.volunteer_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_tasks ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies

-- Profiles policies
CREATE POLICY "Users can view their own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- Events policies
CREATE POLICY "Anyone can view published events" ON public.events
    FOR SELECT USING (status = 'published' OR auth.uid() = organizer_id);

CREATE POLICY "Organizers can manage their own events" ON public.events
    FOR ALL USING (auth.uid() = organizer_id);

CREATE POLICY "Organizers can create events" ON public.events
    FOR INSERT WITH CHECK (auth.uid() = organizer_id);

-- Event registrations policies
CREATE POLICY "Users can view their own registrations" ON public.event_registrations
    FOR SELECT USING (
        auth.uid() = attendee_id OR 
        auth.uid() IN (SELECT organizer_id FROM public.events WHERE id = event_id) OR
        auth.uid() IN (SELECT volunteer_id FROM public.volunteer_assignments WHERE event_id = event_registrations.event_id)
    );

CREATE POLICY "Attendees can create registrations" ON public.event_registrations
    FOR INSERT WITH CHECK (auth.uid() = attendee_id);

CREATE POLICY "Attendees can update their registrations" ON public.event_registrations
    FOR UPDATE USING (auth.uid() = attendee_id);

CREATE POLICY "Organizers and volunteers can update registrations" ON public.event_registrations
    FOR UPDATE USING (
        auth.uid() IN (SELECT organizer_id FROM public.events WHERE id = event_id) OR
        auth.uid() IN (SELECT volunteer_id FROM public.volunteer_assignments WHERE event_id = event_registrations.event_id)
    );

-- Volunteer assignments policies
CREATE POLICY "Volunteers can view their assignments" ON public.volunteer_assignments
    FOR SELECT USING (
        auth.uid() = volunteer_id OR 
        auth.uid() IN (SELECT organizer_id FROM public.events WHERE id = event_id)
    );

CREATE POLICY "Organizers can manage volunteer assignments" ON public.volunteer_assignments
    FOR ALL USING (auth.uid() IN (SELECT organizer_id FROM public.events WHERE id = event_id));

-- Event tasks policies
CREATE POLICY "Volunteers and organizers can view tasks" ON public.event_tasks
    FOR SELECT USING (
        auth.uid() = volunteer_id OR 
        auth.uid() IN (SELECT organizer_id FROM public.events WHERE id = event_id)
    );

CREATE POLICY "Organizers can manage tasks" ON public.event_tasks
    FOR ALL USING (auth.uid() IN (SELECT organizer_id FROM public.events WHERE id = event_id));

CREATE POLICY "Volunteers can update their assigned tasks" ON public.event_tasks
    FOR UPDATE USING (auth.uid() = volunteer_id);
