import React, { useState } from 'react';
import { X, Calendar, MapPin, Users, DollarSign, Clock } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { supabase, Event } from '../../lib/supabase';

interface EventDetailModalProps {
  event: Event;
  onClose: () => void;
  onRegister: () => void;
}

const EventDetailModal: React.FC<EventDetailModalProps> = ({ event, onClose, onRegister }) => {
  const { profile } = useAuth();
  const [loading, setLoading] = useState(false);

  const handleRegister = async () => {
    if (!profile || profile.role !== 'attendee') return;

    setLoading(true);

    try {
      // Generate ticket number
      const ticketNumber = `TKT-${Date.now()}-${Math.random().toString(36).substr(2, 9).toUpperCase()}`;

      const { error } = await supabase
        .from('event_registrations')
        .insert([{
          event_id: event.id,
          attendee_id: profile.id,
          ticket_number: ticketNumber,
          status: 'confirmed',
          registration_date: new Date().toISOString(),
        }]);

      if (error) throw error;

      alert('Successfully registered for the event!');
      onRegister();
    } catch (error) {
      console.error('Error registering for event:', error);
      alert('Failed to register for event. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const isUpcoming = new Date(event.date_time) > new Date();
  const availableSeats = event.capacity - (event.registrations_count || 0);

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        <div className="relative">
          {event.banner_url && (
            <img
              src={event.banner_url}
              alt={event.title}
              className="w-full h-64 object-cover rounded-t-lg"
            />
          )}
          <button
            onClick={onClose}
            className="absolute top-4 right-4 bg-white bg-opacity-90 hover:bg-opacity-100 rounded-full p-2"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-6">
          <div className="flex justify-between items-start mb-4">
            <div>
              <h2 className="text-2xl font-bold text-gray-900">{event.title}</h2>
              <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium mt-2 ${
                event.status === 'published' ? 'bg-green-100 text-green-800' :
                event.status === 'draft' ? 'bg-yellow-100 text-yellow-800' :
                event.status === 'cancelled' ? 'bg-red-100 text-red-800' :
                'bg-gray-100 text-gray-800'
              }`}>
                {event.status}
              </span>
            </div>
            <div className="text-right">
              <div className="text-2xl font-bold text-gray-900">
                ${event.price.toFixed(2)}
              </div>
              <div className="text-sm text-gray-500">per ticket</div>
            </div>
          </div>

          {event.description && (
            <div className="mb-6">
              <h3 className="text-lg font-medium text-gray-900 mb-2">Description</h3>
              <p className="text-gray-600">{event.description}</p>
            </div>
          )}

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
            <div className="space-y-4">
              <div className="flex items-center text-gray-600">
                <Calendar className="w-5 h-5 mr-3" />
                <div>
                  <div className="font-medium">
                    {new Date(event.date_time).toLocaleDateString('en-US', {
                      weekday: 'long',
                      year: 'numeric',
                      month: 'long',
                      day: 'numeric'
                    })}
                  </div>
                  <div className="text-sm">
                    {new Date(event.date_time).toLocaleTimeString([], { 
                      hour: '2-digit', 
                      minute: '2-digit' 
                    })}
                    {event.end_time && (
                      <> - {new Date(event.end_time).toLocaleTimeString([], { 
                        hour: '2-digit', 
                        minute: '2-digit' 
                      })}</>
                    )}
                  </div>
                </div>
              </div>

              <div className="flex items-center text-gray-600">
                <MapPin className="w-5 h-5 mr-3" />
                <div>
                  <div className="font-medium">{event.venue}</div>
                  {event.address && (
                    <div className="text-sm">{event.address}</div>
                  )}
                </div>
              </div>
            </div>

            <div className="space-y-4">
              <div className="flex items-center text-gray-600">
                <Users className="w-5 h-5 mr-3" />
                <div>
                  <div className="font-medium">Capacity</div>
                  <div className="text-sm">
                    {availableSeats} / {event.capacity} seats available
                  </div>
                </div>
              </div>

              <div className="flex items-center text-gray-600">
                <Clock className="w-5 h-5 mr-3" />
                <div>
                  <div className="font-medium">Category</div>
                  <div className="text-sm">{event.category}</div>
                </div>
              </div>
            </div>
          </div>

          {profile?.role === 'attendee' && isUpcoming && availableSeats > 0 && (
            <div className="border-t pt-6">
              <button
                onClick={handleRegister}
                disabled={loading}
                className="w-full bg-black text-white py-3 px-4 rounded-md hover:bg-gray-800 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? 'Registering...' : 'Register for Event'}
              </button>
            </div>
          )}

          {profile?.role === 'attendee' && !isUpcoming && (
            <div className="border-t pt-6">
              <div className="text-center text-gray-500">
                This event has already passed
              </div>
            </div>
          )}

          {profile?.role === 'attendee' && availableSeats <= 0 && (
            <div className="border-t pt-6">
              <div className="text-center text-red-600 font-medium">
                This event is fully booked
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default EventDetailModal;
