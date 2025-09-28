import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Calendar, Users, BarChart3, User, Ticket, LogOut } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';

const Navigation: React.FC = () => {
  const { profile, signOut } = useAuth();
  const location = useLocation();

  if (!profile) return null;

  const getNavigationItems = () => {
    switch (profile.role) {
      case 'organizer':
        return [
          { name: 'Home', path: '/dashboard', icon: Calendar },
          { name: 'Events', path: '/events', icon: Calendar },
          { name: 'Analysis', path: '/analysis', icon: BarChart3 },
          { name: 'Profile', path: '/profile', icon: User },
        ];
      case 'volunteer':
        return [
          { name: 'Home', path: '/dashboard', icon: Calendar },
          { name: 'Events', path: '/events', icon: Calendar },
          { name: 'Profile', path: '/profile', icon: User },
        ];
      case 'attendee':
        return [
          { name: 'Home', path: '/dashboard', icon: Calendar },
          { name: 'Events', path: '/events', icon: Calendar },
          { name: 'Tickets', path: '/tickets', icon: Ticket },
          { name: 'Profile', path: '/profile', icon: User },
        ];
      default:
        return [];
    }
  };

  const navigationItems = getNavigationItems();

  return (
    <nav className="bg-white border-b border-gray-200">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          <div className="flex">
            <div className="flex-shrink-0 flex items-center">
              <Link to="/dashboard" className="text-xl font-bold text-black">
                EventHub
              </Link>
            </div>
            <div className="hidden sm:ml-6 sm:flex sm:space-x-8">
              {navigationItems.map((item) => {
                const Icon = item.icon;
                const isActive = location.pathname === item.path;
                return (
                  <Link
                    key={item.name}
                    to={item.path}
                    className={`inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium ${
                      isActive
                        ? 'border-black text-black'
                        : 'border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700'
                    }`}
                  >
                    <Icon className="w-4 h-4 mr-2" />
                    {item.name}
                  </Link>
                );
              })}
            </div>
          </div>
          <div className="flex items-center space-x-4">
            <span className="text-sm text-gray-500 capitalize">{profile.role}</span>
            <span className="text-sm font-medium text-gray-900">{profile.full_name}</span>
            <button
              onClick={() => signOut()}
              className="p-2 text-gray-400 hover:text-gray-600 transition-colors"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </nav>
  );
};

export default Navigation;
