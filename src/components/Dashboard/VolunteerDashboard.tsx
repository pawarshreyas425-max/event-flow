import React, { useState, useEffect } from 'react';
import { Calendar, CheckSquare, Clock, MapPin } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { supabase, VolunteerAssignment, EventTask } from '../../lib/supabase';

const VolunteerDashboard: React.FC = () => {
  const { profile } = useAuth();
  const [assignments, setAssignments] = useState<VolunteerAssignment[]>([]);
  const [tasks, setTasks] = useState<EventTask[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (profile) {
      fetchVolunteerData();
    }
  }, [profile]);

  const fetchVolunteerData = async () => {
    if (!profile) return;

    try {
      // Fetch volunteer assignments
      const { data: assignmentsData } = await supabase
        .from('volunteer_assignments')
        .select(`
          *,
          event:events(*)
        `)
        .eq('volunteer_id', profile.id)
        .order('assigned_at', { ascending: false });

      // Fetch tasks
      const { data: tasksData } = await supabase
        .from('event_tasks')
        .select(`
          *,
          event:events(title)
        `)
        .eq('volunteer_id', profile.id)
        .order('created_at', { ascending: false });

      setAssignments(assignmentsData || []);
      setTasks(tasksData || []);
    } catch (error) {
      console.error('Error fetching volunteer data:', error);
    } finally {
      setLoading(false);
    }
  };

  const markTaskComplete = async (taskId: string) => {
    try {
      const { error } = await supabase
        .from('event_tasks')
        .update({ 
          status: 'completed',
          completed_at: new Date().toISOString()
        })
        .eq('id', taskId);

      if (!error) {
        setTasks(prev => prev.map(task => 
          task.id === taskId 
            ? { ...task, status: 'completed' as const, completed_at: new Date().toISOString() }
            : task
        ));
      }
    } catch (error) {
      console.error('Error updating task:', error);
    }
  };

  const getUpcomingEvents = () => {
    const now = new Date().toISOString();
    return assignments
      .filter(assignment => assignment.event && assignment.event.date_time > now)
      .slice(0, 3);
  };

  const getUpcomingTasks = () => {
    return tasks
      .filter(task => task.status !== 'completed')
      .slice(0, 5);
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
  const upcomingTasks = getUpcomingTasks();

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="px-4 py-6 sm:px-0">
          <h1 className="text-3xl font-bold text-gray-900">
            Welcome back, {profile?.full_name}
          </h1>
          <p className="mt-1 text-sm text-gray-600">
            Here are your volunteer assignments and tasks.
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Assigned Events */}
          <div className="lg:col-span-2">
            <div className="bg-white shadow rounded-lg">
              <div className="px-4 py-5 sm:p-6">
                <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">
                  Upcoming Events
                </h3>
                {upcomingEvents.length > 0 ? (
                  <div className="space-y-4">
                    {upcomingEvents.map((assignment) => (
                      <div key={assignment.id} className="border border-gray-200 rounded-lg p-4">
                        <div className="flex justify-between items-start">
                          <div className="flex-1">
                            <h4 className="text-lg font-medium text-gray-900">
                              {assignment.event?.title}
                            </h4>
                            <p className="text-sm text-gray-600 mt-1">
                              Role: <span className="font-medium">{assignment.assigned_role}</span>
                            </p>
                            <div className="flex items-center text-sm text-gray-500 mt-2">
                              <Calendar className="w-4 h-4 mr-1" />
                              {new Date(assignment.event?.date_time || '').toLocaleDateString()} at{' '}
                              {new Date(assignment.event?.date_time || '').toLocaleTimeString([], { 
                                hour: '2-digit', 
                                minute: '2-digit' 
                              })}
                            </div>
                            <div className="flex items-center text-sm text-gray-500 mt-1">
                              <MapPin className="w-4 h-4 mr-1" />
                              {assignment.event?.venue}
                            </div>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="text-center py-6">
                    <Calendar className="mx-auto h-12 w-12 text-gray-400" />
                    <h3 className="mt-2 text-sm font-medium text-gray-900">No upcoming events</h3>
                    <p className="mt-1 text-sm text-gray-500">
                      You don't have any upcoming event assignments.
                    </p>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Task List */}
          <div>
            <div className="bg-white shadow rounded-lg">
              <div className="px-4 py-5 sm:p-6">
                <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">
                  My Tasks
                </h3>
                {upcomingTasks.length > 0 ? (
                  <div className="space-y-3">
                    {upcomingTasks.map((task) => (
                      <div key={task.id} className="flex items-start space-x-3">
                        <button
                          onClick={() => markTaskComplete(task.id)}
                          className={`mt-1 flex-shrink-0 w-4 h-4 rounded border ${
                            task.status === 'completed'
                              ? 'bg-black border-black'
                              : 'border-gray-300 hover:border-black'
                          }`}
                        >
                          {task.status === 'completed' && (
                            <CheckSquare className="w-3 h-3 text-white" />
                          )}
                        </button>
                        <div className="flex-1 min-w-0">
                          <p className={`text-sm font-medium ${
                            task.status === 'completed' 
                              ? 'text-gray-500 line-through' 
                              : 'text-gray-900'
                          }`}>
                            {task.title}
                          </p>
                          <p className="text-xs text-gray-500">
                            {task.event?.title}
                          </p>
                          {task.due_date && (
                            <div className="flex items-center text-xs text-gray-400 mt-1">
                              <Clock className="w-3 h-3 mr-1" />
                              Due: {new Date(task.due_date).toLocaleDateString()}
                            </div>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="text-center py-6">
                    <CheckSquare className="mx-auto h-12 w-12 text-gray-400" />
                    <h3 className="mt-2 text-sm font-medium text-gray-900">No tasks</h3>
                    <p className="mt-1 text-sm text-gray-500">
                      You're all caught up!
                    </p>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Summary Stats */}
        <div className="mt-6 grid grid-cols-1 gap-5 sm:grid-cols-3">
          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <Calendar className="h-6 w-6 text-gray-400" />
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">
                      Total Assignments
                    </dt>
                    <dd className="text-lg font-medium text-gray-900">
                      {assignments.length}
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
                  <CheckSquare className="h-6 w-6 text-gray-400" />
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">
                      Completed Tasks
                    </dt>
                    <dd className="text-lg font-medium text-gray-900">
                      {tasks.filter(task => task.status === 'completed').length}
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
                  <Clock className="h-6 w-6 text-gray-400" />
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">
                      Pending Tasks
                    </dt>
                    <dd className="text-lg font-medium text-gray-900">
                      {tasks.filter(task => task.status !== 'completed').length}
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default VolunteerDashboard;
