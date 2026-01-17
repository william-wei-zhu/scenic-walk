import { useState, useCallback, useEffect } from 'react';
import { nanoid } from 'nanoid';
import { WalkMapComponent } from './WalkMapComponent';
import { Toast, useToast } from './Toast';
import { createWalkEvent, getAllWalkEvents } from '../services/firebase';
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
  const [confirmPin, setConfirmPin] = useState('');
  const [broadcastMode, setBroadcastMode] = useState<'continuous' | 'manual'>('continuous');
  const [isCreating, setIsCreating] = useState(false);
  const [createdEvent, setCreatedEvent] = useState<WalkEvent | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Existing events
  const [existingEvents, setExistingEvents] = useState<WalkEvent[]>([]);
  const [eventsFilter, setEventsFilter] = useState<'active' | 'ended'>('active');
  const [isLoadingEvents, setIsLoadingEvents] = useState(true);

  // Toast notifications
  const { toast, showToast, hideToast } = useToast();

  // Fetch existing events on mount
  useEffect(() => {
    const fetchEvents = async () => {
      try {
        const events = await getAllWalkEvents();
        setExistingEvents(events);
      } catch (err) {
        console.error('Failed to fetch events:', err);
      } finally {
        setIsLoadingEvents(false);
      }
    };
    fetchEvents();
  }, []);

  // Filter events based on status
  const filteredEvents = existingEvents.filter(e => e.status === eventsFilter);

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
    if (pin !== confirmPin) {
      setError('PINs do not match');
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
        broadcastMode,
      };

      await createWalkEvent(event);
      setCreatedEvent(event);
      onEventCreated?.(event.id);
    } catch (err) {
      setError('Failed to create event. Please try again.');
      console.error('Create event error:', err);
    } finally {
      setIsCreating(false);
    }
  }, [eventName, pin, route, broadcastMode, onEventCreated]);

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
    const organizerUrl = `${window.location.origin}/#/${createdEvent.id}?organizer=true`;

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

          <div className="space-y-4">
            {/* Participant Link */}
            <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4">
              <p className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Share with participants:
              </p>
              <div className="flex gap-2">
                <input
                  type="text"
                  value={participantUrl}
                  readOnly
                  className="flex-1 px-3 py-2 bg-white dark:bg-gray-700 border rounded text-sm text-gray-800 dark:text-gray-200"
                />
                <button
                  onClick={() => handleCopyUrl(participantUrl)}
                  className="px-3 py-2 bg-green-600 text-white rounded hover:bg-green-700 text-sm"
                >
                  Copy
                </button>
              </div>
              <button
                onClick={() => handleShare(participantUrl, createdEvent.name)}
                className="w-full mt-2 py-2 border border-gray-300 dark:border-gray-600 rounded text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 text-sm"
              >
                Share Link
              </button>
            </div>

            {/* Organizer Link */}
            <div className="bg-green-50 dark:bg-green-900/20 rounded-lg p-4">
              <p className="text-sm font-medium text-green-700 dark:text-green-300 mb-2">
                Your organizer link (keep private):
              </p>
              <div className="flex gap-2">
                <input
                  type="text"
                  value={organizerUrl}
                  readOnly
                  className="flex-1 px-3 py-2 bg-white dark:bg-gray-700 border rounded text-sm text-gray-800 dark:text-gray-200"
                />
                <button
                  onClick={() => handleCopyUrl(organizerUrl)}
                  className="px-3 py-2 bg-green-600 text-white rounded hover:bg-green-700 text-sm"
                >
                  Copy
                </button>
              </div>
              <p className="text-xs text-green-600 dark:text-green-400 mt-2">
                PIN: {createdEvent.organizerPin}
              </p>
            </div>
          </div>

          <button
            onClick={() => window.location.hash = `/${createdEvent.id}?organizer=true`}
            className="w-full mt-6 py-3 bg-green-600 text-white rounded-lg font-medium hover:bg-green-700"
          >
            Go to Organizer View
          </button>

          {onClose && (
            <button
              onClick={onClose}
              className="w-full mt-2 py-2 text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200"
            >
              Close
            </button>
          )}
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
              <div className="h-96 md:h-[500px]">
                <WalkMapComponent
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
              <div className="mb-4">
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

              {/* Confirm PIN */}
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Confirm PIN
                </label>
                <input
                  type="text"
                  inputMode="numeric"
                  pattern="[0-9]*"
                  maxLength={4}
                  value={confirmPin}
                  onChange={(e) => setConfirmPin(e.target.value.replace(/\D/g, ''))}
                  placeholder="1234"
                  className={`w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 ${
                    confirmPin && pin !== confirmPin
                      ? 'border-red-500 dark:border-red-500'
                      : 'dark:border-gray-600'
                  }`}
                />
                {confirmPin && pin !== confirmPin && (
                  <p className="text-xs text-red-500 mt-1">PINs do not match</p>
                )}
                {confirmPin && pin === confirmPin && pin.length === 4 && (
                  <p className="text-xs text-green-600 dark:text-green-400 mt-1">PINs match</p>
                )}
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                  You'll need this PIN to broadcast your location
                </p>
              </div>

              {/* Broadcast Mode */}
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Location Update Mode
                </label>
                <div className="space-y-2">
                  <label className={`flex items-start gap-3 p-3 border rounded-lg cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800 ${
                    broadcastMode === 'continuous'
                      ? 'border-green-500 bg-green-50 dark:bg-green-900/20'
                      : 'dark:border-gray-600'
                  }`}>
                    <input
                      type="radio"
                      name="broadcastMode"
                      checked={broadcastMode === 'continuous'}
                      onChange={() => setBroadcastMode('continuous')}
                      className="text-green-600 mt-1"
                    />
                    <div>
                      <p className="font-medium text-gray-800 dark:text-gray-200 flex items-center gap-2">
                        Continuous Updates
                        <span className="text-xs bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 px-2 py-0.5 rounded">Recommended</span>
                      </p>
                      <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                        Location shared every 10 seconds automatically. Best for most walks.
                      </p>
                    </div>
                  </label>
                  <label className={`flex items-start gap-3 p-3 border rounded-lg cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800 ${
                    broadcastMode === 'manual'
                      ? 'border-green-500 bg-green-50 dark:bg-green-900/20'
                      : 'dark:border-gray-600'
                  }`}>
                    <input
                      type="radio"
                      name="broadcastMode"
                      checked={broadcastMode === 'manual'}
                      onChange={() => setBroadcastMode('manual')}
                      className="text-green-600 mt-1"
                    />
                    <div>
                      <p className="font-medium text-gray-800 dark:text-gray-200">On-Demand Updates</p>
                      <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                        You control when to share your location. Better for battery life.
                      </p>
                    </div>
                  </label>
                </div>
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

            {/* Tips */}
            <div className="bg-green-50 dark:bg-green-900/20 rounded-lg p-4 text-sm">
              <h3 className="font-medium text-green-800 dark:text-green-300 mb-2">Tips</h3>
              <ul className="text-green-700 dark:text-green-400 space-y-1">
                <li>• Click on the map to add route points</li>
                <li>• Share the participant link with your group</li>
                <li>• Use the organizer link to broadcast your location</li>
              </ul>
            </div>
          </div>
        </div>

        {/* Existing Events Section */}
        <div className="mt-8">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-bold text-gray-800 dark:text-gray-100">Your Walk Events</h2>
            <div className="flex bg-gray-100 dark:bg-gray-800 rounded-lg p-1">
              <button
                onClick={() => setEventsFilter('active')}
                className={`px-4 py-1.5 text-sm font-medium rounded-md transition-colors ${
                  eventsFilter === 'active'
                    ? 'bg-white dark:bg-gray-700 text-green-600 dark:text-green-400 shadow-sm'
                    : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200'
                }`}
              >
                Active
              </button>
              <button
                onClick={() => setEventsFilter('ended')}
                className={`px-4 py-1.5 text-sm font-medium rounded-md transition-colors ${
                  eventsFilter === 'ended'
                    ? 'bg-white dark:bg-gray-700 text-gray-600 dark:text-gray-300 shadow-sm'
                    : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200'
                }`}
              >
                Ended
              </button>
            </div>
          </div>

          {isLoadingEvents ? (
            <div className="bg-white dark:bg-gray-900 rounded-lg p-8 text-center">
              <div className="animate-spin w-8 h-8 border-4 border-green-600 border-t-transparent rounded-full mx-auto mb-3"></div>
              <p className="text-gray-500 dark:text-gray-400">Loading events...</p>
            </div>
          ) : filteredEvents.length === 0 ? (
            <div className="bg-white dark:bg-gray-900 rounded-lg p-8 text-center">
              {eventsFilter === 'active' ? (
                <img src="/logo.png" alt="" className="w-16 h-16 mx-auto mb-3 rounded-lg opacity-50" />
              ) : (
                <div className="text-4xl mb-3">📋</div>
              )}
              <p className="text-gray-500 dark:text-gray-400">
                {eventsFilter === 'active' ? 'No active events. Create one above!' : 'No ended events yet.'}
              </p>
            </div>
          ) : (
            <div className="grid gap-4 md:grid-cols-2">
              {filteredEvents.map((event) => (
                <div
                  key={event.id}
                  className="bg-white dark:bg-gray-900 rounded-lg shadow p-4 hover:shadow-md transition-shadow"
                >
                  <div className="flex items-start justify-between mb-3">
                    <div>
                      <h3 className="font-semibold text-gray-800 dark:text-gray-100">{event.name}</h3>
                      <p className="text-xs text-gray-500 dark:text-gray-400">
                        Created {new Date(event.createdAt).toLocaleDateString()}
                      </p>
                    </div>
                    <span className={`px-2 py-1 text-xs font-medium rounded-full ${
                      event.status === 'active'
                        ? 'bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400'
                        : 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400'
                    }`}>
                      {event.status === 'active' ? '● Active' : 'Ended'}
                    </span>
                  </div>
                  <p className="text-sm text-gray-600 dark:text-gray-400 mb-3">
                    {event.route.length} points • {event.broadcastMode === 'continuous' ? 'Continuous' : 'On-demand'}
                  </p>
                  <div className="flex gap-2">
                    <button
                      onClick={() => { window.location.hash = `/${event.id}`; }}
                      className="flex-1 py-2 text-sm bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
                    >
                      View
                    </button>
                    <button
                      onClick={() => { window.location.hash = `/${event.id}?organizer=true`; }}
                      className="flex-1 py-2 text-sm bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
                    >
                      Manage
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
        </div>
      </main>
    </div>
  );
};

export default CreateWalkEvent;
