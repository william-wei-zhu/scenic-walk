import { useState, useEffect } from 'react';
import { subscribeToOrganizerLocation } from '../services/firebase';
import type { OrganizerLocation } from '../types';

/**
 * Hook to subscribe to organizer's live location updates via Firebase Realtime Database
 */
export const useLiveLocation = (eventId: string | null) => {
  const [location, setLocation] = useState<OrganizerLocation | null>(null);
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    if (!eventId) {
      setLocation(null);
      setIsConnected(false);
      return;
    }

    setIsConnected(true);

    const unsubscribe = subscribeToOrganizerLocation(eventId, (loc) => {
      setLocation(loc);
    });

    return () => {
      unsubscribe();
      setIsConnected(false);
    };
  }, [eventId]);

  // Calculate how fresh the location is
  const lastUpdateAgo = location
    ? Math.floor((Date.now() - location.timestamp) / 1000)
    : null;

  const isStale = lastUpdateAgo !== null && lastUpdateAgo > 60; // Over 1 minute old

  return {
    location,
    isConnected,
    lastUpdateAgo,
    isStale,
  };
};
