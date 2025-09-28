import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export type UserRole = 'organizer' | 'volunteer' | 'attendee';
export type EventStatus = 'draft' | 'published' | 'ongoing' | 'completed' | 'cancelled';
export type RegistrationStatus = 'pending' | 'confirmed' | 'cancelled' | 'attended';
export type TaskStatus = 'pending' | 'in_progress' | 'completed';

export interface Profile {
  id: string;
  email: string;
  full_name: string;
  phone?: string;
  role: UserRole;
  company?: string;
  skills?: string[];
  profile_picture_url?: string;
  created_at: string;
  updated_at: string;
}

export interface Event {
  id: string;
  organizer_id: string;
  title: string;
  description?: string;
  category: string;
  date_time: string;
  end_time?: string;
  venue: string;
  address?: string;
  capacity: number;
  price: number;
  banner_url?: string;
  status: EventStatus;
  created_at: string;
  updated_at: string;
  organizer?: Profile;
  registrations_count?: number;
  available_seats?: number;
}

export interface EventRegistration {
  id: string;
  event_id: string;
  attendee_id: string;
  registration_date: string;
  status: RegistrationStatus;
  ticket_number: string;
  seat_number?: string;
  checked_in: boolean;
  checked_in_at?: string;
  event?: Event;
  attendee?: Profile;
}

export interface VolunteerAssignment {
  id: string;
  event_id: string;
  volunteer_id: string;
  assigned_role: string;
  assigned_at: string;
  event?: Event;
  volunteer?: Profile;
}

export interface EventTask {
  id: string;
  event_id: string;
  volunteer_id?: string;
  title: string;
  description?: string;
  status: TaskStatus;
  due_date?: string;
  completed_at?: string;
  created_at: string;
  event?: Event;
  volunteer?: Profile;
}
