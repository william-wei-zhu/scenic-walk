import { useState, useEffect, lazy, Suspense } from 'react';
import { LoadingSpinner } from './components/LoadingSpinner';

// Lazy load components for code splitting
const CreateWalkEvent = lazy(() => import('./components/CreateWalkEvent'));
const WalkEventView = lazy(() => import('./components/WalkEventView'));

type RouteType =
  | { type: 'home' }
  | { type: 'create' }
  | { type: 'event'; eventId: string; isOrganizer: boolean };

/**
 * Parse hash-based route
 * Routes:
 *   #/create - Create new event
 *   #/:eventId - View event as participant
 *   #/:eventId?organizer=true - View event as organizer
 *   (empty or #/) - Home page
 */
function parseHashRoute(hash: string): RouteType {
  // Remove leading # and /
  const path = hash.replace(/^#\/?/, '');

  if (!path || path === '/') {
    return { type: 'home' };
  }

  if (path === 'create') {
    return { type: 'create' };
  }

  // Parse event ID and query params
  const [eventId, queryString] = path.split('?');
  if (eventId) {
    const params = new URLSearchParams(queryString || '');
    const isOrganizer = params.get('organizer') === 'true';
    return { type: 'event', eventId, isOrganizer };
  }

  return { type: 'home' };
}

function App() {
  // Dark mode state
  const [isDarkMode, setIsDarkMode] = useState(() => {
    const saved = localStorage.getItem('scenic-walk-dark-mode');
    if (saved !== null) {
      return saved === 'true';
    }
    return window.matchMedia('(prefers-color-scheme: dark)').matches;
  });

  // Route state
  const [route, setRoute] = useState<RouteType>(() => parseHashRoute(window.location.hash));

  // Google Maps loaded state
  const [mapsLoaded, setMapsLoaded] = useState(false);
  const [mapsError, setMapsError] = useState<string | null>(null);

  // Apply dark mode class to document
  useEffect(() => {
    document.documentElement.classList.toggle('dark', isDarkMode);
    localStorage.setItem('scenic-walk-dark-mode', String(isDarkMode));
  }, [isDarkMode]);

  // Listen for hash changes
  useEffect(() => {
    const handleHashChange = () => {
      setRoute(parseHashRoute(window.location.hash));
    };
    window.addEventListener('hashchange', handleHashChange);
    return () => window.removeEventListener('hashchange', handleHashChange);
  }, []);

  // Load Google Maps script
  useEffect(() => {
    const apiKey = import.meta.env.VITE_GOOGLE_MAPS_API_KEY;

    if (!apiKey) {
      setMapsError('Google Maps API key is not configured. Please add VITE_GOOGLE_MAPS_API_KEY to your .env file.');
      return;
    }

    // Check if already loaded
    if (window.google?.maps) {
      setMapsLoaded(true);
      return;
    }

    const script = document.createElement('script');
    script.src = `https://maps.googleapis.com/maps/api/js?key=${apiKey}&libraries=places,marker&v=weekly`;
    script.async = true;
    script.defer = true;

    script.onload = () => {
      setMapsLoaded(true);
    };

    script.onerror = () => {
      setMapsError('Failed to load Google Maps. Please check your API key and network connection.');
    };

    document.head.appendChild(script);

    return () => {
      // Cleanup not needed for Google Maps script
    };
  }, []);

  // Navigation helpers
  const navigateToCreate = () => {
    window.location.hash = '/create';
  };

  const navigateHome = () => {
    window.location.hash = '';
  };

  // Show error if Maps failed to load
  if (mapsError) {
    return (
      <div className="min-h-screen bg-gray-100 dark:bg-gray-950 flex items-center justify-center p-4">
        <div className="bg-white dark:bg-gray-900 rounded-xl shadow-lg p-8 max-w-md text-center">
          <div className="text-5xl mb-4">🗺️</div>
          <h2 className="text-xl font-bold text-gray-800 dark:text-gray-100 mb-2">
            Maps Error
          </h2>
          <p className="text-gray-600 dark:text-gray-400 mb-4">
            {mapsError}
          </p>
          <button
            onClick={() => window.location.reload()}
            className="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  // Show loading while Maps loads
  if (!mapsLoaded) {
    return <LoadingSpinner message="Loading maps..." />;
  }

  // Render based on route
  return (
    <Suspense fallback={<LoadingSpinner />}>
      {route.type === 'create' && (
        <CreateWalkEvent
          onEventCreated={(eventId) => {
            window.location.hash = `/${eventId}?organizer=true`;
          }}
          onClose={navigateHome}
        />
      )}

      {route.type === 'event' && (
        <WalkEventView
          eventId={route.eventId}
          isOrganizerMode={route.isOrganizer}
          onClose={navigateHome}
        />
      )}

      {route.type === 'home' && (
        <HomePage
          onCreateEvent={navigateToCreate}
          isDarkMode={isDarkMode}
          onToggleDarkMode={() => setIsDarkMode(!isDarkMode)}
        />
      )}
    </Suspense>
  );
}

// Home page component
interface HomePageProps {
  onCreateEvent: () => void;
  isDarkMode: boolean;
  onToggleDarkMode: () => void;
}

function HomePage({ onCreateEvent, isDarkMode, onToggleDarkMode }: HomePageProps) {
  return (
    <div className="min-h-screen bg-gradient-to-b from-green-50 to-white dark:from-gray-900 dark:to-gray-950">
      {/* Header */}
      <header className="p-4 flex justify-end">
        <button
          onClick={onToggleDarkMode}
          className="p-2 rounded-lg bg-white dark:bg-gray-800 shadow-sm hover:shadow transition-shadow"
          aria-label="Toggle dark mode"
        >
          {isDarkMode ? '☀️' : '🌙'}
        </button>
      </header>

      {/* Hero Section */}
      <main className="px-4 py-12 text-center">
        <div className="max-w-4xl mx-auto">
          <div className="mb-8">
            <img src="/logo.png" alt="Scenic Walk" className="w-28 h-28 mx-auto rounded-2xl shadow-lg" />
          </div>

          <h1 className="text-4xl md:text-5xl font-bold text-gray-900 dark:text-white mb-4">
            Scenic Walk
          </h1>

          <p className="text-xl text-gray-600 dark:text-gray-400 mb-8 max-w-2xl mx-auto">
            Create walking events and share your live location with participants.
            Perfect for group walks, tours, and outdoor activities.
          </p>

          <button
            onClick={onCreateEvent}
            className="px-8 py-4 bg-green-600 hover:bg-green-700 text-white text-lg font-semibold rounded-xl shadow-lg hover:shadow-xl transition-all transform hover:scale-105"
          >
            Create Walk Event
          </button>
        </div>

        {/* Features */}
        <div className="mt-16 grid md:grid-cols-3 gap-6 md:gap-8 max-w-6xl mx-auto">
          <div className="bg-white dark:bg-gray-800 rounded-xl p-6 shadow-md">
            <div className="text-4xl mb-4">📍</div>
            <h3 className="text-lg font-semibold text-gray-800 dark:text-gray-200 mb-2">
              Live Location Sharing
            </h3>
            <p className="text-gray-600 dark:text-gray-400">
              Broadcast your GPS location in real-time so participants always know where you are.
            </p>
          </div>

          <div className="bg-white dark:bg-gray-800 rounded-xl p-6 shadow-md">
            <div className="text-4xl mb-4">🗺️</div>
            <h3 className="text-lg font-semibold text-gray-800 dark:text-gray-200 mb-2">
              Draw Custom Routes
            </h3>
            <p className="text-gray-600 dark:text-gray-400">
              Plan your walk by drawing the route directly on the map with start and end points.
            </p>
          </div>

          <div className="bg-white dark:bg-gray-800 rounded-xl p-6 shadow-md">
            <div className="text-4xl mb-4">🔗</div>
            <h3 className="text-lg font-semibold text-gray-800 dark:text-gray-200 mb-2">
              Easy Sharing
            </h3>
            <p className="text-gray-600 dark:text-gray-400">
              Share a simple link with your group. No app downloads or sign-ups required.
            </p>
          </div>
        </div>

        {/* How It Works */}
        <div className="mt-16 max-w-6xl mx-auto">
          <h2 className="text-2xl font-bold text-gray-900 dark:text-white mb-8">
            How It Works
          </h2>

          <div className="grid md:grid-cols-4 gap-6 text-left">
            <div className="relative">
              <div className="w-10 h-10 bg-green-600 text-white rounded-full flex items-center justify-center font-bold mb-3">
                1
              </div>
              <h4 className="font-semibold text-gray-800 dark:text-gray-200 mb-1">Create Event</h4>
              <p className="text-sm text-gray-600 dark:text-gray-400">
                Draw your route and set up a PIN code.
              </p>
            </div>

            <div className="relative">
              <div className="w-10 h-10 bg-green-600 text-white rounded-full flex items-center justify-center font-bold mb-3">
                2
              </div>
              <h4 className="font-semibold text-gray-800 dark:text-gray-200 mb-1">Share Link</h4>
              <p className="text-sm text-gray-600 dark:text-gray-400">
                Send the participant link to your group.
              </p>
            </div>

            <div className="relative">
              <div className="w-10 h-10 bg-green-600 text-white rounded-full flex items-center justify-center font-bold mb-3">
                3
              </div>
              <h4 className="font-semibold text-gray-800 dark:text-gray-200 mb-1">Start Walk</h4>
              <p className="text-sm text-gray-600 dark:text-gray-400">
                Begin broadcasting your location with one tap.
              </p>
            </div>

            <div className="relative">
              <div className="w-10 h-10 bg-green-600 text-white rounded-full flex items-center justify-center font-bold mb-3">
                4
              </div>
              <h4 className="font-semibold text-gray-800 dark:text-gray-200 mb-1">Follow Along</h4>
              <p className="text-sm text-gray-600 dark:text-gray-400">
                Participants see your live location on the map.
              </p>
            </div>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="mt-16 py-8 border-t dark:border-gray-800">
        <div className="max-w-4xl mx-auto px-4 text-center text-gray-500 dark:text-gray-400">
          <p className="mb-2">
            Open source under AGPL-3.0 License
          </p>
          <p className="text-sm">
            <a
              href="https://github.com/william-wei-zhu/scenic-walk"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-green-600 dark:hover:text-green-400 underline"
            >
              View on GitHub
            </a>
          </p>
        </div>
      </footer>
    </div>
  );
}

export default App;
