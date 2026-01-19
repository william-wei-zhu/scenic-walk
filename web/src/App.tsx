import { useState, useEffect, lazy, Suspense } from 'react';
import { LoadingSpinner } from './components/LoadingSpinner';
import { getOrganizerEvents, removeOrganizerEvent, type SavedEvent } from './services/organizerStorage';
import { getWalkEvent } from './services/firebase';

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
  const [savedEvents, setSavedEvents] = useState<SavedEvent[]>([]);
  const [eventStatuses, setEventStatuses] = useState<Record<string, 'active' | 'ended' | 'loading'>>({});

  // Load saved events on mount
  useEffect(() => {
    const events = getOrganizerEvents();
    setSavedEvents(events);

    // Fetch status for each event
    events.forEach(async (event) => {
      setEventStatuses(prev => ({ ...prev, [event.id]: 'loading' }));
      try {
        const walkEvent = await getWalkEvent(event.id);
        setEventStatuses(prev => ({
          ...prev,
          [event.id]: walkEvent?.status || 'ended',
        }));
      } catch {
        setEventStatuses(prev => ({ ...prev, [event.id]: 'ended' }));
      }
    });
  }, []);

  const handleRemoveEvent = (eventId: string) => {
    removeOrganizerEvent(eventId);
    setSavedEvents(prev => prev.filter(e => e.id !== eventId));
  };

  const formatDate = (timestamp: number) => {
    return new Date(timestamp).toLocaleDateString(undefined, {
      month: 'short',
      day: 'numeric',
    });
  };

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
            <img src="/logo.svg" alt="Scenic Walk" className="w-48 h-48 mx-auto rounded-2xl shadow-lg" />
          </div>

          <h1 className="text-4xl md:text-5xl font-bold text-gray-900 dark:text-white mb-4">
            Scenic Walk
          </h1>

          <p className="text-xl text-gray-600 dark:text-gray-400 mb-8 max-w-2xl mx-auto">
            Never lose your walking group again.
          </p>

          <button
            onClick={onCreateEvent}
            className="px-8 py-4 bg-green-600 hover:bg-green-700 text-white text-lg font-semibold rounded-xl shadow-lg hover:shadow-xl transition-all transform hover:scale-105"
          >
            Create Walk Event
          </button>

          {/* My Events Section */}
          {savedEvents.length > 0 && (
            <div className="mt-12">
              <h2 className="text-lg font-semibold text-gray-700 dark:text-gray-300 mb-4">
                My Events
              </h2>
              <div className="space-y-2 max-w-md mx-auto">
                {savedEvents.map((event) => {
                  const status = eventStatuses[event.id];
                  return (
                    <div
                      key={event.id}
                      className="flex items-center justify-between bg-white dark:bg-gray-800 rounded-lg px-4 py-3 shadow-sm hover:shadow transition-shadow"
                    >
                      <button
                        onClick={() => window.location.hash = `/${event.id}?organizer=true`}
                        className="flex-1 text-left flex items-center gap-3"
                      >
                        <span className="text-gray-900 dark:text-gray-100 font-medium">
                          {event.name}
                        </span>
                        <span className="text-xs text-gray-500 dark:text-gray-400">
                          {formatDate(event.createdAt)}
                        </span>
                        {status === 'loading' ? (
                          <span className="text-xs text-gray-400">...</span>
                        ) : status === 'active' ? (
                          <span className="text-xs text-green-600 dark:text-green-400 font-medium">
                            Active
                          </span>
                        ) : (
                          <span className="text-xs text-gray-400">
                            Ended
                          </span>
                        )}
                      </button>
                      <button
                        onClick={() => handleRemoveEvent(event.id)}
                        className="ml-2 p-1 text-gray-400 hover:text-red-500 transition-colors"
                        title="Remove from list"
                      >
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </button>
                    </div>
                  );
                })}
              </div>
              <p className="mt-3 text-xs text-gray-500 dark:text-gray-500">
                Events are saved on this device only
              </p>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}

export default App;
