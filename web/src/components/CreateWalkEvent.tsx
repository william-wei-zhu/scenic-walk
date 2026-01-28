import { useState, useCallback, useRef } from 'react';
import { nanoid } from 'nanoid';
import { WalkMapComponent, type WalkMapComponentRef } from './WalkMapComponent';
import { PlaceSearchBar } from './PlaceSearchBar';
import { Toast, useToast } from './Toast';
import { createWalkEvent } from '../services/firebase';
import { saveOrganizerEvent } from '../services/organizerStorage';
import type { Coordinates, WalkEvent } from '../types';

interface CreateWalkEventProps {
  onEventCreated?: (eventId: string) => void;
  onClose?: () => void;
}

export const CreateWalkEvent: React.FC<CreateWalkEventProps> = ({
  onEventCreated,
  onClose,
}) => {
  const [route, setRoute] = useState<Coordinates[]>([]);
  const [eventName, setEventName] = useState('');
  const [pin, setPin] = useState('');
  const [isCreating, setIsCreating] = useState(false);
  const [createdEvent, setCreatedEvent] = useState<WalkEvent | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Map ref for centering
  const mapRef = useRef<WalkMapComponentRef>(null);

  // Toast notifications
  const { toast, showToast, hideToast } = useToast();

  // Handle place selection from search bar
  const handlePlaceSelected = useCallback((location: { lat: number; lng: number }) => {
    mapRef.current?.centerOnLocation(location.lat, location.lng, 16);
  }, []);

  // Handle route change from drawing
  const handleRouteChange = useCallback((newRoute: Coordinates[]) => {
    setRoute(newRoute);
    setError(null);
  }, []);

  // Undo last point
  const handleUndo = useCallback(() => {
    setRoute(prev => prev.slice(0, -1));
  }, []);

  // Clear all points
  const handleClear = useCallback(() => {
    setRoute([]);
  }, []);

  // Create the event
  const handleCreate = useCallback(async () => {
    if (!eventName.trim()) {
      setError('Please enter an event name');
      return;
    }
    if (pin.length !== 4) {
      setError('Please enter a 4-digit PIN');
      return;
    }
    if (route.length < 2) {
      setError('Please draw a route with at least 2 points');
      return;
    }

    setIsCreating(true);
    setError(null);

    try {
      const event: WalkEvent = {
        id: nanoid(8),
        name: eventName.trim(),
        createdAt: Date.now(),
        organizerPin: pin,
        route,
        status: 'active',
        broadcastMode: 'continuous',
      };

      await createWalkEvent(event);

      // Save to localStorage for "My Events" list
      saveOrganizerEvent({
        id: event.id,
        name: event.name,
        pin: event.organizerPin,
        createdAt: event.createdAt,
      });

      setCreatedEvent(event);
      onEventCreated?.(event.id);
    } catch (err) {
      setError('Failed to create event. Please try again.');
      console.error('Create event error:', err);
    } finally {
      setIsCreating(false);
    }
  }, [eventName, pin, route, onEventCreated]);

  // Copy share URL
  const handleCopyUrl = useCallback((url: string) => {
    navigator.clipboard.writeText(url);
    showToast('Link copied!', 'success');
  }, [showToast]);

  // Share URL
  const handleShare = useCallback((url: string, name: string) => {
    if (navigator.share) {
      navigator.share({
        title: name,
        url,
      });
    } else {
      navigator.clipboard.writeText(url);
      showToast('Link copied!', 'success');
    }
  }, [showToast]);

  // Show success screen after creation
  if (createdEvent) {
    const participantUrl = `${window.location.origin}/#/${createdEvent.id}`;

    return (
      <div className="min-h-screen bg-gray-100 dark:bg-gray-950 flex items-center justify-center p-4">
        <div className="bg-white dark:bg-gray-900 rounded-xl shadow-lg p-6 w-full max-w-md">
          <div className="text-center mb-6">
            <div className="text-5xl mb-4">🎉</div>
            <h2 className="text-2xl font-bold text-gray-800 dark:text-gray-100">
              Event Created!
            </h2>
            <p className="text-gray-600 dark:text-gray-400 mt-2">
              {createdEvent.name}
            </p>
          </div>

          {/* Share Link */}
          <button
            onClick={() => handleShare(participantUrl, createdEvent.name)}
            className="w-full py-4 bg-green-600 text-white rounded-lg font-medium hover:bg-green-700 text-lg"
          >
            Share with Participants
          </button>

          <button
            onClick={() => window.location.hash = `/${createdEvent.id}?organizer=true`}
            className="w-full mt-3 py-3 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800"
          >
            Start Broadcasting
          </button>
        </div>
        <Toast
          message={toast.message}
          isVisible={toast.isVisible}
          onClose={hideToast}
          type={toast.type}
        />
      </div>
    );
  }

  return (
    <div className="h-screen flex flex-col bg-gray-100 dark:bg-gray-950 overflow-hidden">
      {/* Header - Fixed */}
      <header className="flex-shrink-0 bg-white dark:bg-gray-900 shadow-sm">
        <div className="px-4 md:px-6 py-4 flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-800 dark:text-gray-100">Create Walk Event</h1>
            <p className="text-gray-600 dark:text-gray-400 text-sm mt-1">
              Draw your route and share it with participants
            </p>
          </div>
          {onClose && (
            <button
              onClick={onClose}
              className="text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200 text-2xl"
            >
              ×
            </button>
          )}
        </div>
      </header>

      {/* Scrollable Content */}
      <main className="flex-1 overflow-y-auto">
        <div className="px-4 md:px-6 py-6">
        <div className="grid md:grid-cols-2 gap-6">
          {/* Left: Map and Route Drawing */}
          <div className="space-y-4">
            <div className="bg-white dark:bg-gray-900 rounded-lg shadow overflow-hidden">
              {/* Search bar */}
              <div className="p-3 border-b dark:border-gray-700">
                <PlaceSearchBar onPlaceSelected={handlePlaceSelected} />
              </div>
              <div className="h-96 md:h-[500px]">
                <WalkMapComponent
                  ref={mapRef}
                  route={route}
                  isDrawingMode={true}
                  onRouteChange={handleRouteChange}
                />
              </div>
              <div className="p-3 bg-gray-50 dark:bg-gray-800 border-t dark:border-gray-700 flex justify-between items-center">
                <span className="text-sm text-gray-600 dark:text-gray-400">
                  {route.length} points • Click map to add points
                </span>
                <div className="flex gap-2">
                  <button
                    onClick={handleUndo}
                    disabled={route.length === 0}
                    className="px-3 py-1 text-sm bg-gray-200 dark:bg-gray-700 rounded hover:bg-gray-300 dark:hover:bg-gray-600 disabled:opacity-50 text-gray-700 dark:text-gray-300"
                  >
                    Undo
                  </button>
                  <button
                    onClick={handleClear}
                    disabled={route.length === 0}
                    className="px-3 py-1 text-sm bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400 rounded hover:bg-red-200 dark:hover:bg-red-900/50 disabled:opacity-50"
                  >
                    Clear
                  </button>
                </div>
              </div>
            </div>
          </div>

          {/* Right: Event Details Form */}
          <div className="space-y-4">
            <div className="bg-white dark:bg-gray-900 rounded-lg p-6 shadow">
              <h2 className="text-lg font-semibold mb-4 text-gray-800 dark:text-gray-100">Event Details</h2>

              {/* Event Name */}
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Event Name
                </label>
                <input
                  type="text"
                  value={eventName}
                  onChange={(e) => setEventName(e.target.value)}
                  placeholder="Morning Walk at the Park"
                  className="w-full px-3 py-2 border dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
                />
              </div>

              {/* PIN */}
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Organizer PIN (4 digits)
                </label>
                <input
                  type="text"
                  inputMode="numeric"
                  pattern="[0-9]*"
                  maxLength={4}
                  value={pin}
                  onChange={(e) => setPin(e.target.value.replace(/\D/g, ''))}
                  placeholder="1234"
                  className="w-full px-3 py-2 border dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
                />
              </div>

              {/* Error */}
              {error && (
                <div className="mb-4 p-3 bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 rounded-lg text-sm">
                  {error}
                </div>
              )}

              {/* Create Button */}
              <button
                onClick={handleCreate}
                disabled={isCreating}
                className="w-full py-3 bg-green-600 text-white rounded-lg font-medium hover:bg-green-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
              >
                {isCreating ? 'Creating...' : 'Create Event'}
              </button>
            </div>
          </div>
        </div>
        </div>
      </main>
    </div>
  );
};

export default CreateWalkEvent;
