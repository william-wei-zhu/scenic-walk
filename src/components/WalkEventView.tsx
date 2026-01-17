import { useState, useEffect, useCallback } from 'react';
import { WalkMapComponent } from './WalkMapComponent';
import { OrganizerPinModal } from './OrganizerPinModal';
import { LocationBroadcaster } from './LocationBroadcaster';
import { Toast, useToast } from './Toast';
import { useLiveLocation } from '../hooks';
import { getWalkEvent, updateWalkEventStatus, clearOrganizerLocation } from '../services/firebase';
import type { WalkEvent } from '../types';

interface WalkEventViewProps {
  eventId: string;
  isOrganizerMode?: boolean;
  onClose?: () => void;
}

export const WalkEventView: React.FC<WalkEventViewProps> = ({
  eventId,
  isOrganizerMode = false,
  onClose,
}) => {
  const [event, setEvent] = useState<WalkEvent | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Organizer state
  const [showPinModal, setShowPinModal] = useState(false);
  const [isOrganizerVerified, setIsOrganizerVerified] = useState(false);
  const [pinError, setPinError] = useState<string | null>(null);
  const [isBroadcasting, setIsBroadcasting] = useState(false);
  const [isEndingEvent, setIsEndingEvent] = useState(false);

  // Live location subscription
  const { location, lastUpdateAgo, isStale } = useLiveLocation(eventId);

  // Toast notifications
  const { toast, showToast, hideToast } = useToast();

  // Fetch event data
  useEffect(() => {
    const fetchEvent = async () => {
      try {
        const eventData = await getWalkEvent(eventId);
        if (eventData) {
          setEvent(eventData);
          // Show PIN modal if organizer mode
          if (isOrganizerMode) {
            setShowPinModal(true);
          }
        } else {
          setError('Event not found');
        }
      } catch (err) {
        setError('Failed to load event');
        console.error('Fetch event error:', err);
      } finally {
        setIsLoading(false);
      }
    };

    fetchEvent();
  }, [eventId, isOrganizerMode]);

  // Handle PIN submission
  const handlePinSubmit = useCallback((enteredPin: string) => {
    if (event && enteredPin === event.organizerPin) {
      setIsOrganizerVerified(true);
      setShowPinModal(false);
      setPinError(null);
    } else {
      setPinError('Incorrect PIN');
    }
  }, [event]);

  // Handle broadcast status change
  const handleBroadcastStatus = useCallback((status: 'broadcasting' | 'stopped' | 'error') => {
    setIsBroadcasting(status === 'broadcasting');
  }, []);

  // Start/stop broadcasting
  const toggleBroadcasting = useCallback(async () => {
    const newState = !isBroadcasting;
    setIsBroadcasting(newState);

    // If stopping, clear the location from Firebase so the flag disappears
    if (!newState && event) {
      try {
        await clearOrganizerLocation(event.id);
      } catch (err) {
        console.error('Failed to clear location:', err);
      }
    }
  }, [isBroadcasting, event]);

  // End event (mark as ended and clear location)
  const handleEndEvent = useCallback(async () => {
    if (!event) return;

    const confirmed = window.confirm(
      'Are you sure you want to end this event? This will stop location sharing and mark the event as ended.'
    );
    if (!confirmed) return;

    setIsEndingEvent(true);
    try {
      // Stop broadcasting first
      setIsBroadcasting(false);
      // Update event status
      await updateWalkEventStatus(event.id, 'ended');
      // Clear the organizer location
      await clearOrganizerLocation(event.id);
      // Update local state
      setEvent({ ...event, status: 'ended' });
    } catch (err) {
      console.error('Failed to end event:', err);
      alert('Failed to end event. Please try again.');
    } finally {
      setIsEndingEvent(false);
    }
  }, [event]);

  // Reactivate event
  const handleReactivateEvent = useCallback(async () => {
    if (!event) return;

    setIsEndingEvent(true);
    try {
      await updateWalkEventStatus(event.id, 'active');
      setEvent({ ...event, status: 'active' });
    } catch (err) {
      console.error('Failed to reactivate event:', err);
      alert('Failed to reactivate event. Please try again.');
    } finally {
      setIsEndingEvent(false);
    }
  }, [event]);

  // Share event link
  const handleShare = useCallback(() => {
    const url = `${window.location.origin}/#/${eventId}`;
    if (navigator.share) {
      navigator.share({
        title: event?.name || 'Walk Event',
        url,
      });
    } else {
      navigator.clipboard.writeText(url);
      showToast('Link copied!', 'success');
    }
  }, [eventId, event?.name, showToast]);

  if (isLoading) {
    return (
      <div className="h-screen flex items-center justify-center bg-gray-100 dark:bg-gray-950">
        <div className="text-center">
          <div className="animate-spin w-12 h-12 border-4 border-green-600 border-t-transparent rounded-full mx-auto mb-4"></div>
          <p className="text-gray-600 dark:text-gray-400">Loading event...</p>
        </div>
      </div>
    );
  }

  if (error || !event) {
    return (
      <div className="h-screen flex items-center justify-center bg-gray-100 dark:bg-gray-950 p-4">
        <div className="bg-white dark:bg-gray-900 rounded-xl shadow-lg p-8 text-center max-w-md">
          <div className="text-5xl mb-4">😕</div>
          <h2 className="text-xl font-bold text-gray-800 dark:text-gray-100 mb-2">
            {error || 'Event not found'}
          </h2>
          <p className="text-gray-600 dark:text-gray-400 mb-6">
            This event may have been deleted or the link is incorrect.
          </p>
          <button
            onClick={() => window.location.hash = '/create'}
            className="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
          >
            Create New Event
          </button>
          {onClose && (
            <button
              onClick={onClose}
              className="block w-full mt-3 text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200"
            >
              Go Back
            </button>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="h-screen bg-gray-100 dark:bg-gray-950 flex flex-col overflow-hidden">
      {/* Header */}
      <header className="flex-shrink-0 bg-white dark:bg-gray-900 shadow-sm">
        <div className="px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              {onClose && (
                <button
                  onClick={onClose}
                  className="text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200 text-2xl"
                >
                  ←
                </button>
              )}
              <div>
                <h1 className="text-xl font-bold text-gray-800 dark:text-gray-100">{event.name}</h1>
                <p className="text-sm text-gray-500 dark:text-gray-400">
                  {event.route.length} points • {event.broadcastMode === 'continuous' ? 'Continuous' : 'On-demand'} updates
                </p>
              </div>
            </div>
            {isOrganizerVerified && (
              <div className="flex items-center gap-2">
                {isBroadcasting ? (
                  <>
                    <span className="w-4 h-4 rounded-full bg-green-500 animate-pulse flex items-center justify-center text-white text-[10px]">📡</span>
                    <span className="text-sm text-green-600 dark:text-green-400 font-medium">
                      Broadcasting
                    </span>
                  </>
                ) : (
                  <>
                    <span className="w-4 h-4 rounded-full bg-gray-300 dark:bg-gray-600 flex items-center justify-center text-[10px]">⏸</span>
                    <span className="text-sm text-gray-500 dark:text-gray-400">
                      Paused
                    </span>
                  </>
                )}
              </div>
            )}
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 flex flex-col md:flex-row overflow-hidden">
        {/* Map - larger height on mobile, flex-1 on desktop */}
        <div className="h-[65vh] md:h-auto md:flex-1">
          <WalkMapComponent
            route={event.route}
            organizerLocation={location}
            showCenterButton={isOrganizerVerified}
          />
        </div>

        {/* Sidebar - scrollable on mobile */}
        <div className="flex-1 md:flex-none w-full md:w-80 bg-white dark:bg-gray-900 shadow-lg p-4 space-y-4 overflow-y-auto">
          {/* Location Status */}
          <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4">
            <h3 className="font-medium text-gray-800 dark:text-gray-200 mb-2">Organizer Location</h3>
            {location ? (
              <div>
                <div className="flex items-center gap-2 mb-2">
                  {isStale ? (
                    <>
                      <span className="w-5 h-5 rounded-full bg-amber-500 flex items-center justify-center text-white text-xs">⏱</span>
                      <span className="text-sm text-amber-700 dark:text-amber-400 font-medium">
                        Stale
                      </span>
                    </>
                  ) : (
                    <>
                      <span className="w-5 h-5 rounded-full bg-green-500 flex items-center justify-center text-white text-xs">✓</span>
                      <span className="text-sm text-green-700 dark:text-green-400 font-medium">
                        Active
                      </span>
                    </>
                  )}
                </div>
                <p className="text-xs text-gray-500 dark:text-gray-400">
                  Updated {lastUpdateAgo}s ago
                </p>
                {location.accuracy && (
                  <p className="text-xs text-gray-400 dark:text-gray-500">
                    Accuracy: ±{Math.round(location.accuracy)}m
                  </p>
                )}
              </div>
            ) : (
              <div>
                <div className="flex items-center gap-2 mb-3">
                  <span className="w-5 h-5 rounded-full bg-gray-400 flex items-center justify-center text-white text-xs animate-pulse">○</span>
                  <span className="text-sm text-gray-600 dark:text-gray-400">
                    Waiting for organizer
                    <span className="inline-flex ml-1">
                      <span className="animate-bounce" style={{ animationDelay: '0ms' }}>.</span>
                      <span className="animate-bounce" style={{ animationDelay: '150ms' }}>.</span>
                      <span className="animate-bounce" style={{ animationDelay: '300ms' }}>.</span>
                    </span>
                  </span>
                </div>
                <p className="text-xs text-gray-500 dark:text-gray-400 bg-gray-100 dark:bg-gray-700/50 p-2 rounded">
                  The organizer will start sharing their location soon. You'll see their position on the map as an orange flag.
                </p>
              </div>
            )}
          </div>

          {/* Organizer Controls */}
          {isOrganizerVerified && (
            <div className="space-y-4">
              <div className="border-t dark:border-gray-700 pt-4">
                <h3 className="font-medium text-gray-800 dark:text-gray-200 mb-3">Organizer Controls</h3>

                {/* Event Status Banner */}
                {event.status === 'ended' && (
                  <div className="bg-gray-100 dark:bg-gray-800 rounded-lg p-3 mb-3 text-center">
                    <p className="text-gray-600 dark:text-gray-400 text-sm">
                      This event has ended
                    </p>
                  </div>
                )}

                {/* Broadcasting controls (only for active events) */}
                {event.status === 'active' && (
                  <button
                    onClick={toggleBroadcasting}
                    className={`w-full py-3 rounded-lg font-medium transition-colors ${
                      isBroadcasting
                        ? 'bg-red-600 hover:bg-red-700 text-white'
                        : 'bg-green-600 hover:bg-green-700 text-white'
                    }`}
                  >
                    {isBroadcasting ? '⏹️ Stop Broadcasting' : '▶️ Start Broadcasting'}
                  </button>
                )}

                {/* End/Reactivate Event Button */}
                <button
                  onClick={event.status === 'active' ? handleEndEvent : handleReactivateEvent}
                  disabled={isEndingEvent}
                  className={`w-full py-3 mt-3 rounded-lg font-medium transition-colors ${
                    event.status === 'active'
                      ? 'bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600'
                      : 'bg-green-600 hover:bg-green-700 text-white'
                  } disabled:opacity-50 disabled:cursor-not-allowed`}
                >
                  {isEndingEvent
                    ? 'Processing...'
                    : event.status === 'active'
                      ? '🏁 End Event'
                      : '🔄 Reactivate Event'
                  }
                </button>
              </div>

              {isBroadcasting && event.status === 'active' && (
                <LocationBroadcaster
                  event={event}
                  isActive={isBroadcasting}
                  onStatusChange={handleBroadcastStatus}
                />
              )}
            </div>
          )}

          {/* Event Status Notice */}
          {!isOrganizerVerified && event.status === 'ended' && (
            <div className="bg-gray-100 dark:bg-gray-800 rounded-lg p-4 text-center">
              <div className="text-2xl mb-2">🏁</div>
              <p className="text-sm font-medium text-gray-700 dark:text-gray-300">This event has ended</p>
              <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                The route is still visible on the map for reference.
              </p>
            </div>
          )}

          {/* Participant Instructions */}
          {!isOrganizerVerified && event.status === 'active' && (
            <div className="bg-green-50 dark:bg-green-900/20 rounded-lg p-4">
              <h3 className="font-medium text-green-800 dark:text-green-300 mb-2">How to use</h3>
              <ul className="text-sm text-green-700 dark:text-green-400 space-y-2">
                <li>• The orange flag shows the organizer's location</li>
                <li>• Green marker = route start</li>
                <li>• Red marker = route end</li>
                <li>• Location updates {event.broadcastMode === 'continuous' ? 'every ~10 seconds' : 'when organizer taps'}</li>
              </ul>
            </div>
          )}

          {/* Share Button */}
          <button
            onClick={handleShare}
            className="w-full py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800"
          >
            Share Event Link
          </button>
        </div>
      </main>

      {/* PIN Modal */}
      <OrganizerPinModal
        isOpen={showPinModal}
        onClose={() => {
          setShowPinModal(false);
          // Navigate to participant view if cancelled
          window.location.hash = `/${eventId}`;
        }}
        onSubmit={handlePinSubmit}
        error={pinError || undefined}
      />

      {/* Toast notifications */}
      <Toast
        message={toast.message}
        isVisible={toast.isVisible}
        onClose={hideToast}
        type={toast.type}
      />
    </div>
  );
};

export default WalkEventView;
