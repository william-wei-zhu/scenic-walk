import { useState, useEffect, useCallback, useRef } from 'react';
import { useGeolocation } from '../hooks';
import { updateOrganizerLocation } from '../services/firebase';
import type { WalkEvent } from '../types';

interface LocationBroadcasterProps {
  event: WalkEvent;
  isActive: boolean;
  onStatusChange?: (status: 'broadcasting' | 'stopped' | 'error') => void;
}

export const LocationBroadcaster: React.FC<LocationBroadcasterProps> = ({
  event,
  isActive,
  onStatusChange,
}) => {
  const { position, error, isTracking, getCurrentPosition, startTracking, stopTracking } = useGeolocation();
  const [lastBroadcast, setLastBroadcast] = useState<Date | null>(null);
  const [broadcastError, setBroadcastError] = useState<string | null>(null);
  const intervalRef = useRef<number | null>(null);

  // Broadcast current position to Firebase
  const broadcastPosition = useCallback(async (pos: GeolocationPosition) => {
    try {
      await updateOrganizerLocation(event.id, {
        lat: pos.coords.latitude,
        lng: pos.coords.longitude,
        timestamp: Date.now(),
        accuracy: pos.coords.accuracy,
      });
      setLastBroadcast(new Date());
      setBroadcastError(null);
      onStatusChange?.('broadcasting');
    } catch (err) {
      setBroadcastError('Failed to broadcast location');
      onStatusChange?.('error');
    }
  }, [event.id, onStatusChange]);

  // Handle continuous mode - get initial position immediately
  useEffect(() => {
    if (!isActive || event.broadcastMode !== 'continuous') {
      stopTracking();
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
      return;
    }

    // Get initial position immediately, then start watching
    getCurrentPosition()
      .then((pos) => {
        broadcastPosition(pos);
      })
      .catch(() => {
        // Error handled by useGeolocation
      });

    startTracking();

    // Broadcast every 10 seconds
    intervalRef.current = window.setInterval(() => {
      if (position) {
        broadcastPosition(position);
      }
    }, 10000);

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, [isActive, event.broadcastMode, startTracking, stopTracking, position, broadcastPosition, getCurrentPosition]);

  // Broadcast when position updates in continuous mode
  useEffect(() => {
    if (isActive && event.broadcastMode === 'continuous' && position) {
      broadcastPosition(position);
    }
  }, [position, isActive, event.broadcastMode, broadcastPosition]);

  // Manual broadcast
  const handleManualBroadcast = useCallback(async () => {
    try {
      const pos = await getCurrentPosition();
      await broadcastPosition(pos);
    } catch (err) {
      setBroadcastError(error || 'Could not get location');
    }
  }, [getCurrentPosition, broadcastPosition, error]);

  if (!isActive) {
    return (
      <div className="bg-gray-100 dark:bg-gray-800 rounded-lg p-4 text-center">
        <p className="text-gray-500 dark:text-gray-400">Broadcasting is not active</p>
      </div>
    );
  }

  const isContinuous = event.broadcastMode === 'continuous';

  return (
    <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-4">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className={`w-3 h-3 rounded-full ${isTracking ? 'bg-green-500 animate-pulse' : 'bg-gray-300'}`} />
          <span className="font-medium text-gray-800 dark:text-gray-200">
            {isContinuous ? 'Auto Broadcasting' : 'Manual Mode'}
          </span>
        </div>
        {lastBroadcast && (
          <span className="text-xs text-gray-500 dark:text-gray-400">
            Last: {lastBroadcast.toLocaleTimeString()}
          </span>
        )}
      </div>

      {broadcastError && (
        <div className="bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 text-sm p-2 rounded mb-3">
          {broadcastError}
        </div>
      )}

      {error && (
        <div className="bg-amber-50 dark:bg-amber-900/20 text-amber-600 dark:text-amber-400 text-sm p-2 rounded mb-3">
          {error}
        </div>
      )}

      {isContinuous ? (
        <div className="text-center py-2">
          <p className="text-sm text-gray-600 dark:text-gray-400">
            Your location is being shared every 10 seconds
          </p>
          {position && (
            <p className="text-xs text-gray-400 dark:text-gray-500 mt-1">
              Accuracy: ±{Math.round(position.coords.accuracy)}m
            </p>
          )}
        </div>
      ) : (
        <button
          onClick={handleManualBroadcast}
          className="w-full py-3 bg-green-600 text-white rounded-lg font-medium hover:bg-green-700 transition-colors flex items-center justify-center gap-2"
        >
          <span className="text-xl">📍</span>
          Broadcast My Location
        </button>
      )}
    </div>
  );
};

export default LocationBroadcaster;
