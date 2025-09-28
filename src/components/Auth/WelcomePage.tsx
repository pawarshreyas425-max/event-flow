import React from 'react';
import { Link } from 'react-router-dom';
import { Calendar, Users, Zap } from 'lucide-react';

const WelcomePage: React.FC = () => {
  return (
    <div className="min-h-screen bg-white flex flex-col items-center justify-center px-4">
      <div className="max-w-md w-full space-y-8 text-center">
        {/* Logo */}
        <div>
          <h1 className="text-4xl font-bold text-black mb-2">EventHub</h1>
          <p className="text-lg text-gray-600">Plan, manage, and attend events effortlessly.</p>
        </div>

        {/* Minimal Vector Illustration */}
        <div className="flex justify-center space-x-8 my-12">
          <div className="flex flex-col items-center">
            <div className="w-16 h-16 bg-black rounded-full flex items-center justify-center mb-2">
              <Calendar className="w-8 h-8 text-white" />
            </div>
            <span className="text-sm text-gray-600">Events</span>
          </div>
          <div className="flex flex-col items-center">
            <div className="w-16 h-16 bg-black rounded-full flex items-center justify-center mb-2">
              <Users className="w-8 h-8 text-white" />
            </div>
            <span className="text-sm text-gray-600">People</span>
          </div>
          <div className="flex flex-col items-center">
            <div className="w-16 h-16 bg-black rounded-full flex items-center justify-center mb-2">
              <Zap className="w-8 h-8 text-white" />
            </div>
            <span className="text-sm text-gray-600">Manage</span>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="space-y-4">
          <Link
            to="/login"
            className="w-full flex justify-center py-3 px-4 border border-black bg-black text-white text-sm font-medium rounded-md hover:bg-gray-800 transition-colors"
          >
            Login
          </Link>
          <Link
            to="/register"
            className="w-full flex justify-center py-3 px-4 border border-black bg-white text-black text-sm font-medium rounded-md hover:bg-gray-50 transition-colors"
          >
            Register
          </Link>
        </div>

        {/* Features */}
        <div className="mt-12 text-left">
          <h3 className="text-lg font-semibold text-black mb-4">Why EventHub?</h3>
          <ul className="space-y-2 text-sm text-gray-600">
            <li className="flex items-center">
              <div className="w-2 h-2 bg-black rounded-full mr-3"></div>
              Create and manage events seamlessly
            </li>
            <li className="flex items-center">
              <div className="w-2 h-2 bg-black rounded-full mr-3"></div>
              Volunteer coordination made simple
            </li>
            <li className="flex items-center">
              <div className="w-2 h-2 bg-black rounded-full mr-3"></div>
              Easy registration and ticketing
            </li>
            <li className="flex items-center">
              <div className="w-2 h-2 bg-black rounded-full mr-3"></div>
              Real-time analytics and insights
            </li>
          </ul>
        </div>
      </div>
    </div>
  );
};

export default WelcomePage;
