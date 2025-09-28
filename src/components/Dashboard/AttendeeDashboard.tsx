import React, { useState, useEffect } from 'react';
import { Calendar, Ticket, Star, TrendingUp } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { supabase, EventRegistration, Event } from '../../lib/supabase';

const AttendeeDashboard: React.FC = () => {
  const { profile } = useAuth();
  const [registrations, setRegistrations] = useState<EventRegistration[]>([]);
  const [recommendedEvents, setRecommendedEvents] = useState<Event[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (profile) {
      fetchAttendeeData();
    }
  }, [profile]);

  const fetchAttendeeData = async () => {
    if (!profile) return;

    try {
      // Fetch user's registrations
      const { data: registrationsData } = await supabase
        .from('event_registrations')
        .select(`
          *,
          event:events(*)
        `)
        .eq('attendee_id', profile.id)
        .order('registration_date', { ascending: false });

      // Fetch recommended events (events user hasn't registered for)
      const registeredEventIds = registrationsData?.map(reg => reg.event_id) || [];
      
      let recommendedQuery = supabase
        .from('events')
        .select('*')
        .eq('status', 'published')
        .gt('date_time', new Date().toISOString())
        .limit(6);

      if (registeredEventIds.length > 0) {
        recommendedQuery = recommendedQuery.not('id', 'in', `(${registeredEventIds.join(',')})`);
      }

      const { data: recommendedData } = await recommendedQuery;

      setRegistrations(registrationsData || []);
      setRecommendedEvents(recommendedData || []);
    } catch (error) {
      console.error('Error fetching attendee data:', error);
    } finally {
      setLoading(false);
    }
  };

  const getUpcomingEvents = () => {
    const now = new Date().toISOString();
    return registrations
      .filter(reg => reg.event && reg.event.date_time > now && reg.status === 'confirmed')
      .slice(0, 3);
  };

  const getPastEvents = () => {
    const now = new Date().toISOString();
    return registrations
      .filter(reg => reg.event && reg.event.date_time <= now && reg.status === 'confirmed')
      .slice(0, 3);
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-black mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  const upcomingEvents = getUpcomingEvents();
  const pastEvents = getPastEvents();

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="px-4 py-6 sm:px-0">
          <h1 className="text-3xl font-bold text-gray-900">
            Welcome back, {profile?.full_name}
          </h1>
          <p className="mt-1 text-sm text-gray-600">
            Discover and manage your events.
          </p>
        </div>

        {/* Quick Stats */}
        <div className="grid grid-cols-1 gap-5 sm:grid-cols-3 mb-6">
          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <Calendar className="h-6 w-6 text-gray-400" />
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">
                      Upcoming Events
                    </dt>
                    <dd className="text-lg font-medium text-gray-900">
                      {upcomingEvents.length}
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <Ticket className="h-6 w-6 text-gray-400" />
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">
                      Total Tickets
                    </dt>
                    <dd className="text-lg font-medium text-gray-900">
                      {registrations.filter(reg => reg.status === 'confirmed').length}
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <Star className="h-6 w-6 text-gray-400" />
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">
                      Events Attended
                    </dt>
                    <dd className="text-lg font-medium text-gray-900">
                      {pastEvents.length}
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Upcoming Events */}
          <div className="bg-white shadow rounded-lg">
            <div className="px-4 py-5 sm:p-6">
              <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">
                Upcoming Events
              </h3>
              {upcomingEvents.length > 0 ? (
                <div className="space-y-4">
                  {upcomingEvents.map((registration) => (
                    <div key={registration.id} className="border border-gray-200 rounded-lg p-4">
                      {registration.event?.banner_url && (
                        <img
                          src={registration.event.banner_url}
                          alt={registration.event.title}
                          className="w-full h-32 object-cover rounded-md mb-3"
                        />
                      )}
                      <h4 className="text-lg font-medium text-gray-900">
                        {registration.event?.title}
                      </h4>
                      <div className="flex items-center text-sm text-gray-500 mt-2">
                        <Calendar className="w-4 h-4 mr-1" />
                        {new Date(registration.event?.date_time || '').toLocaleDateString()} at{' '}
                        {new Date(registration.event?.date_time || '').toLocaleTimeString([], { 
                          hour: '2-digit', 
                          minute: '2-digit' 
                        })}
                      </div>
                      <div className="flex justify-between items-center mt-3">
                        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                          registration.status === 'confirmed' 
                            ? 'bg-green-100 text-green-800'
                            : 'bg-yellow-100 text-yellow-800'
                        }`}>
                          {registration.status}
                        </span>
                        <span className="text-sm font-medium text-gray-900">
                          Ticket #{registration.ticket_number}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-6">
                  <Calendar className="mx-auto h-12 w-12 text-gray-400" />
                  <h3 className="mt-2 text-sm font-medium text-gray-900">No upcoming events</h3>
                  <p className="mt-1 text-sm text-gray-500">
                    Browse events to find something interesting!
                  </p>
                </div>
              )}
            </div>
          </div>

          {/* Past Events */}
          <div className="bg-white shadow rounded-lg">
            <div className="px-4 py-5 sm:p-6">
              <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">
                Past Events
              </h3>
              {pastEvents.length > 0 ? (
                <div className="space-y-4">
                  {pastEvents.map((registration) => (
                    <div key={registration.id} className="border border-gray-200 rounded-lg p-4">
                      <h4 className="text-lg font-medium text-gray-900">
                        {registration.event?.title}
                      </h4>
                      <div className="flex items-center text-sm text-gray-500 mt-2">
                        <Calendar className="w-4 h-4 mr-1" />
                        {new Date(registration.event?.date_time || '').toLocaleDateString()}
                      </div>
                      <div className="flex justify-between items-center mt-3">
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                          {registration.checked_in ? 'Attended' : 'Registered'}
                        </span>
                        <button className="text-sm text-black hover:underline">
                          Leave Feedback
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-6">
                  <Star className="mx-auto h-12 w-12 text-gray-400" />
                  <h3 className="mt-2 text-sm font-medium text-gray-900">No past events</h3>
                  <p className="mt-1 text-sm text-gray-500">
                    Your event history will appear here.
                  </p>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Recommendations */}
        <div className="mt-6">
          <div className="bg-white shadow rounded-lg">
            <div className="px-4 py-5 sm:p-6">
              <div className="flex items-center mb-4">
                <TrendingUp className="h-5 w-5 text-gray-400 mr-2" />
                <h3 className="text-lg leading-6 font-medium text-gray-900">
                  You might like these events
                </h3>
              </div>
              {recommendedEvents.length > 0 ? (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                  {recommendedEvents.map((event) => (
                    <div key={event.id} className="border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow">
                      {event.banner_url && (
                        <img
                          src={event.banner_url}
                          alt={event.title}
                          className="w-full h-32 object-cover rounded-md mb-3"
                        />
                      )}
                      <h4 className="text-lg font-medium text-gray-900 mb-2">
                        {event.title}
                      </h4>
                      <div className="flex items-center text-sm text-gray-500 mb-2">
                        <Calendar className="w-4 h-4 mr-1" />
                        {new Date(event.date_time).toLocaleDateString()}
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-sm font-medium text-gray-900">
                          ${event.price.toFixed(2)}
                        </span>
                        <button className="text-sm bg-black text-white px-3 py-1 rounded hover:bg-gray-800">
                          View Details
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-gray-500 text-center py-4">No recommendations available</p>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default AttendeeDashboard;
