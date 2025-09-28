import React, { useState, useEffect } from 'react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, LineChart, Line, PieChart, Pie, Cell } from 'recharts';
import { TrendingUp, Users, Calendar, DollarSign } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { supabase } from '../../lib/supabase';

interface AnalyticsData {
  bookingsTrend: Array<{ month: string; bookings: number }>;
  eventAttendance: Array<{ name: string; attendance: number; capacity: number }>;
  categoryDistribution: Array<{ name: string; value: number; color: string }>;
  kpis: {
    averageAttendance: number;
    mostPopularEvent: string;
    totalRevenue: number;
    totalEvents: number;
  };
}

const AnalysisPage: React.FC = () => {
  const { profile } = useAuth();
  const [data, setData] = useState<AnalyticsData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (profile && profile.role === 'organizer') {
      fetchAnalyticsData();
    }
  }, [profile]);

  const fetchAnalyticsData = async () => {
    if (!profile) return;

    try {
      // Fetch events and registrations
      const { data: events } = await supabase
        .from('events')
        .select(`
          *,
          registrations:event_registrations(*)
        `)
        .eq('organizer_id', profile.id);

      if (!events) return;

      // Process data for charts
      const bookingsTrend = processBookingsTrend(events);
      const eventAttendance = processEventAttendance(events);
      const categoryDistribution = processCategoryDistribution(events);
      const kpis = calculateKPIs(events);

      setData({
        bookingsTrend,
        eventAttendance,
        categoryDistribution,
        kpis,
      });
    } catch (error) {
      console.error('Error fetching analytics data:', error);
    } finally {
      setLoading(false);
    }
  };

  const processBookingsTrend = (events: any[]) => {
    const monthlyBookings: { [key: string]: number } = {};
    
    events.forEach(event => {
      if (event.registrations) {
        event.registrations.forEach((reg: any) => {
          const month = new Date(reg.registration_date).toLocaleDateString('en-US', { 
            year: 'numeric', 
            month: 'short' 
          });
          monthlyBookings[month] = (monthlyBookings[month] || 0) + 1;
        });
      }
    });

    return Object.entries(monthlyBookings).map(([month, bookings]) => ({
      month,
      bookings,
    }));
  };

  const processEventAttendance = (events: any[]) => {
    return events.slice(0, 5).map(event => ({
      name: event.title.length > 20 ? event.title.substring(0, 20) + '...' : event.title,
      attendance: event.registrations?.filter((r: any) => r.status === 'confirmed').length || 0,
      capacity: event.capacity,
    }));
  };

  const processCategoryDistribution = (events: any[]) => {
    const categories: { [key: string]: number } = {};
    
    events.forEach(event => {
      categories[event.category] = (categories[event.category] || 0) + 1;
    });

    const colors = ['#000000', '#4B5563', '#9CA3AF', '#D1D5DB', '#F3F4F6'];
    
    return Object.entries(categories).map(([name, value], index) => ({
      name,
      value,
      color: colors[index % colors.length],
    }));
  };

  const calculateKPIs = (events: any[]) => {
    let totalBookings = 0;
    let totalRevenue = 0;
    let mostPopularEvent = '';
    let maxBookings = 0;

    events.forEach(event => {
      const bookings = event.registrations?.filter((r: any) => r.status === 'confirmed').length || 0;
      totalBookings += bookings;
      totalRevenue += bookings * event.price;

      if (bookings > maxBookings) {
        maxBookings = bookings;
        mostPopularEvent = event.title;
      }
    });

    const averageAttendance = events.length > 0 ? (totalBookings / events.length) : 0;

    return {
      averageAttendance: Math.round(averageAttendance * 100) / 100,
      mostPopularEvent: mostPopularEvent || 'No events yet',
      totalRevenue,
      totalEvents: events.length,
    };
  };

  if (profile?.role !== 'organizer') {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <h2 className="text-2xl font-bold text-gray-900">Access Denied</h2>
          <p className="mt-2 text-gray-600">This page is only available to organizers.</p>
        </div>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-black mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading analytics...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="px-4 py-6 sm:px-0">
          <h1 className="text-3xl font-bold text-gray-900">Analytics</h1>
          <p className="mt-1 text-sm text-gray-600">
            Track your event performance and insights.
          </p>
        </div>

        {data && (
          <>
            {/* KPI Cards */}
            <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4 mb-8">
              <div className="bg-white overflow-hidden shadow rounded-lg">
                <div className="p-5">
                  <div className="flex items-center">
                    <div className="flex-shrink-0">
                      <Users className="h-6 w-6 text-gray-400" />
                    </div>
                    <div className="ml-5 w-0 flex-1">
                      <dl>
                        <dt className="text-sm font-medium text-gray-500 truncate">
                          Average Attendance
                        </dt>
                        <dd className="text-lg font-medium text-gray-900">
                          {data.kpis.averageAttendance}%
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
                      <TrendingUp className="h-6 w-6 text-gray-400" />
                    </div>
                    <div className="ml-5 w-0 flex-1">
                      <dl>
                        <dt className="text-sm font-medium text-gray-500 truncate">
                          Most Popular Event
                        </dt>
                        <dd className="text-sm font-medium text-gray-900 truncate">
                          {data.kpis.mostPopularEvent}
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
                      <DollarSign className="h-6 w-6 text-gray-400" />
                    </div>
                    <div className="ml-5 w-0 flex-1">
                      <dl>
                        <dt className="text-sm font-medium text-gray-500 truncate">
                          Total Revenue
                        </dt>
                        <dd className="text-lg font-medium text-gray-900">
                          ${data.kpis.totalRevenue.toFixed(2)}
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
                      <Calendar className="h-6 w-6 text-gray-400" />
                    </div>
                    <div className="ml-5 w-0 flex-1">
                      <dl>
                        <dt className="text-sm font-medium text-gray-500 truncate">
                          Total Events
                        </dt>
                        <dd className="text-lg font-medium text-gray-900">
                          {data.kpis.totalEvents}
                        </dd>
                      </dl>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Charts */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
              {/* Bookings Trend */}
              <div className="bg-white p-6 rounded-lg shadow">
                <h3 className="text-lg font-medium text-gray-900 mb-4">Bookings Trend</h3>
                <div className="h-64">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={data.bookingsTrend}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="month" />
                      <YAxis />
                      <Tooltip />
                      <Line type="monotone" dataKey="bookings" stroke="#000000" strokeWidth={2} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </div>

              {/* Event Attendance */}
              <div className="bg-white p-6 rounded-lg shadow">
                <h3 className="text-lg font-medium text-gray-900 mb-4">Event Attendance</h3>
                <div className="h-64">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={data.eventAttendance}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="name" />
                      <YAxis />
                      <Tooltip />
                      <Bar dataKey="attendance" fill="#000000" />
                      <Bar dataKey="capacity" fill="#E5E7EB" />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </div>

              {/* Category Distribution */}
              <div className="bg-white p-6 rounded-lg shadow lg:col-span-2">
                <h3 className="text-lg font-medium text-gray-900 mb-4">Event Category Distribution</h3>
                <div className="h-64">
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      <Pie
                        data={data.categoryDistribution}
                        cx="50%"
                        cy="50%"
                        labelLine={false}
                        label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                        outerRadius={80}
                        fill="#8884d8"
                        dataKey="value"
                      >
                        {data.categoryDistribution.map((entry, index) => (
                          <Cell key={`cell-${index}`} fill={entry.color} />
                        ))}
                      </Pie>
                      <Tooltip />
                    </PieChart>
                  </ResponsiveContainer>
                </div>
              </div>
            </div>

            {/* Insights */}
            <div className="mt-8 bg-white p-6 rounded-lg shadow">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Dynamic Insights</h3>
              <div className="space-y-2 text-sm text-gray-600">
                {data.bookingsTrend.length > 0 && (
                  <p>• Your events are gaining momentum with consistent booking patterns.</p>
                )}
                {data.kpis.averageAttendance > 75 && (
                  <p>• Excellent attendance rate! Your events are well-attended.</p>
                )}
                {data.categoryDistribution.length > 1 && (
                  <p>• You're hosting diverse event categories, appealing to various audiences.</p>
                )}
                {data.kpis.totalRevenue > 1000 && (
                  <p>• Strong revenue generation from your events!</p>
                )}
                {data.kpis.totalEvents < 5 && (
                  <p>• Consider creating more events to build a stronger presence.</p>
                )}
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

export default AnalysisPage;
