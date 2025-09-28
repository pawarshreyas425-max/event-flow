import React, { useState, useEffect } from 'react';
import { Ticket, Download, Calendar, MapPin, QrCode, X } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { supabase, EventRegistration } from '../../lib/supabase';

const TicketsPage: React.FC = () => {
  const { profile } = useAuth();
  const [tickets, setTickets] = useState<EventRegistration[]>([]);
  const [pastTickets, setPastTickets] = useState<EventRegistration[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedTicket, setSelectedTicket] = useState<EventRegistration | null>(null);

  useEffect(() => {
    if (profile && profile.role === 'attendee') {
      fetchTickets();
    }
  }, [profile]);

  const fetchTickets = async () => {
    if (!profile) return;

    try {
      const { data, error } = await supabase
        .from('event_registrations')
        .select(`
          *,
          event:events(*)
        `)
        .eq('attendee_id', profile.id)
        .order('registration_date', { ascending: false });

      if (error) throw error;

      const now = new Date();
      const upcoming = data?.filter(ticket => 
        ticket.event && new Date(ticket.event.date_time) > now
      ) || [];
      const past = data?.filter(ticket => 
        ticket.event && new Date(ticket.event.date_time) <= now
      ) || [];

      setTickets(upcoming);
      setPastTickets(past);
    } catch (error) {
      console.error('Error fetching tickets:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleCancelBooking = async (ticketId: string) => {
    if (!confirm('Are you sure you want to cancel this booking?')) return;

    try {
      const { error } = await supabase
        .from('event_registrations')
        .update({ status: 'cancelled' })
        .eq('id', ticketId);

      if (error) throw error;

      setTickets(prev => prev.map(ticket => 
        ticket.id === ticketId 
          ? { ...ticket, status: 'cancelled' as const }
          : ticket
      ));

      alert('Booking cancelled successfully');
    } catch (error) {
      console.error('Error cancelling booking:', error);
      alert('Failed to cancel booking');
    }
  };

  const downloadTicket = (ticket: EventRegistration) => {
    // Generate a simple text-based ticket
    const ticketContent = `
EVENT TICKET - EventHub
========================

Event: ${ticket.event?.title}
Date: ${new Date(ticket.event?.date_time || '').toLocaleDateString()}
Time: ${new Date(ticket.event?.date_time || '').toLocaleTimeString()}
Venue: ${ticket.event?.venue}
Ticket #: ${ticket.ticket_number}
Status: ${ticket.status}

Present this ticket at the event entrance.
QR Code: ${ticket.ticket_number}
    `;

    const blob = new Blob([ticketContent], { type: 'text/plain' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `ticket-${ticket.ticket_number}.txt`;
    a.click();
    window.URL.revokeObjectURL(url);
  };

  if (profile?.role !== 'attendee') {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <h2 className="text-2xl font-bold text-gray-900">Access Denied</h2>
          <p className="mt-2 text-gray-600">This page is only available to attendees.</p>
        </div>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-black mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading tickets...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="px-4 py-6 sm:px-0">
          <h1 className="text-3xl font-bold text-gray-900">My Tickets</h1>
          <p className="mt-1 text-sm text-gray-600">
            Manage your event tickets and bookings.
          </p>
        </div>

        {/* Upcoming Tickets */}
        <div className="px-4 sm:px-0 mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">Upcoming Events</h2>
          {tickets.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {tickets.map((ticket) => (
                <div key={ticket.id} className="bg-white rounded-lg shadow-md overflow-hidden">
                  {ticket.event?.banner_url && (
                    <img
                      src={ticket.event.banner_url}
                      alt={ticket.event.title}
                      className="w-full h-32 object-cover"
                    />
                  )}
                  <div className="p-4">
                    <div className="flex justify-between items-start mb-2">
                      <h3 className="text-lg font-medium text-gray-900 truncate">
                        {ticket.event?.title}
                      </h3>
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        ticket.status === 'confirmed' ? 'bg-green-100 text-green-800' :
                        ticket.status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                        'bg-red-100 text-red-800'
                      }`}>
                        {ticket.status}
                      </span>
                    </div>

                    <div className="space-y-2 text-sm text-gray-600 mb-4">
                      <div className="flex items-center">
                        <Calendar className="w-4 h-4 mr-2" />
                        {new Date(ticket.event?.date_time || '').toLocaleDateString()} at{' '}
                        {new Date(ticket.event?.date_time || '').toLocaleTimeString([], { 
                          hour: '2-digit', 
                          minute: '2-digit' 
                        })}
                      </div>
                      <div className="flex items-center">
                        <MapPin className="w-4 h-4 mr-2" />
                        {ticket.event?.venue}
                      </div>
                      <div className="flex items-center">
                        <Ticket className="w-4 h-4 mr-2" />
                        #{ticket.ticket_number}
                      </div>
                    </div>

                    <div className="flex space-x-2">
                      <button
                        onClick={() => setSelectedTicket(ticket)}
                        className="flex-1 inline-flex items-center justify-center px-3 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                      >
                        <QrCode className="w-4 h-4 mr-1" />
                        View QR
                      </button>
                      <button
                        onClick={() => downloadTicket(ticket)}
                        className="flex-1 inline-flex items-center justify-center px-3 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                      >
                        <Download className="w-4 h-4 mr-1" />
                        Download
                      </button>
                    </div>

                    {ticket.status === 'confirmed' && (
                      <button
                        onClick={() => handleCancelBooking(ticket.id)}
                        className="w-full mt-2 text-sm text-red-600 hover:text-red-800"
                      >
                        Cancel Booking
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center py-12 bg-white rounded-lg">
              <Ticket className="mx-auto h-12 w-12 text-gray-400" />
              <h3 className="mt-2 text-sm font-medium text-gray-900">No upcoming tickets</h3>
              <p className="mt-1 text-sm text-gray-500">
                Browse events to book your first ticket!
              </p>
            </div>
          )}
        </div>

        {/* Past Tickets */}
        <div className="px-4 sm:px-0">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">Past Events</h2>
          {pastTickets.length > 0 ? (
            <div className="bg-white rounded-lg shadow overflow-hidden">
              <div className="px-4 py-5 sm:p-6">
                <div className="space-y-4">
                  {pastTickets.map((ticket) => (
                    <div key={ticket.id} className="border border-gray-200 rounded-lg p-4">
                      <div className="flex justify-between items-start">
                        <div className="flex-1">
                          <h4 className="text-lg font-medium text-gray-900">
                            {ticket.event?.title}
                          </h4>
                          <div className="flex items-center text-sm text-gray-500 mt-1">
                            <Calendar className="w-4 h-4 mr-1" />
                            {new Date(ticket.event?.date_time || '').toLocaleDateString()}
                          </div>
                          <div className="flex items-center text-sm text-gray-500 mt-1">
                            <Ticket className="w-4 h-4 mr-1" />
                            #{ticket.ticket_number}
                          </div>
                        </div>
                        <div className="text-right">
                          <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                            ticket.checked_in ? 'bg-blue-100 text-blue-800' : 'bg-gray-100 text-gray-800'
                          }`}>
                            {ticket.checked_in ? 'Attended' : 'Registered'}
                          </span>
                          <button className="block mt-2 text-sm text-black hover:underline">
                            Leave Feedback
                          </button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          ) : (
            <div className="text-center py-12 bg-white rounded-lg">
              <Calendar className="mx-auto h-12 w-12 text-gray-400" />
              <h3 className="mt-2 text-sm font-medium text-gray-900">No past events</h3>
              <p className="mt-1 text-sm text-gray-500">
                Your event history will appear here.
              </p>
            </div>
          )}
        </div>
      </div>

      {/* QR Code Modal */}
      {selectedTicket && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg max-w-md w-full p-6">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-medium text-gray-900">Ticket QR Code</h3>
              <button
                onClick={() => setSelectedTicket(null)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="text-center">
              <div className="w-48 h-48 bg-gray-100 mx-auto mb-4 flex items-center justify-center">
                <div className="text-center">
                  <QrCode className="w-16 h-16 text-gray-400 mx-auto mb-2" />
                  <p className="text-sm text-gray-500">QR Code</p>
                  <p className="text-xs text-gray-400 mt-1 font-mono">
                    {selectedTicket.ticket_number}
                  </p>
                </div>
              </div>

              <h4 className="font-medium text-gray-900">{selectedTicket.event?.title}</h4>
              <p className="text-sm text-gray-500 mt-1">
                {new Date(selectedTicket.event?.date_time || '').toLocaleDateString()}
              </p>
              <p className="text-xs text-gray-400 mt-2">
                Present this QR code at the event entrance
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default TicketsPage;
