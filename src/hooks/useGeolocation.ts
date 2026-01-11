import { useState, useCallback, useEffect, useRef } from 'react';

interface GeolocationState {
  position: GeolocationPosition | null;
  error: string | null;
  isTracking: boolean;
}

interface UseGeolocationOptions {
  enableHighAccuracy?: boolean;
  timeout?: number;
  maximumAge?: number;
}

/**
 * Hook for GPS tracking with continuous watch and single-shot modes
 */
export const useGeolocation = (options: UseGeolocationOptions = {}) => {
  const [state, setState] = useState<GeolocationState>({
    position: null,
    error: null,
    isTracking: false,
  });

  const watchIdRef = useRef<number | null>(null);

  const {
    enableHighAccuracy = true,
    timeout = 10000,
    maximumAge = 5000,
  } = options;

  const geolocationOptions: PositionOptions = {
    enableHighAccuracy,
    timeout,
    maximumAge,
  };

  // Get current position once
  const getCurrentPosition = useCallback(() => {
    return new Promise<GeolocationPosition>((resolve, reject) => {
      if (!navigator.geolocation) {
        reject(new Error('Geolocation not supported'));
        return;
      }

      navigator.geolocation.getCurrentPosition(
        (position) => {
          setState(prev => ({ ...prev, position, error: null }));
          resolve(position);
        },
        (error) => {
          const errorMsg = getErrorMessage(error);
          setState(prev => ({ ...prev, error: errorMsg }));
          reject(new Error(errorMsg));
        },
        geolocationOptions
      );
    });
  }, [enableHighAccuracy, timeout, maximumAge]);

  // Start continuous tracking
  const startTracking = useCallback(() => {
    if (!navigator.geolocation) {
      setState(prev => ({ ...prev, error: 'Geolocation not supported' }));
      return;
    }

    if (watchIdRef.current !== null) {
      return; // Already tracking
    }

    watchIdRef.current = navigator.geolocation.watchPosition(
      (position) => {
        setState(prev => ({ ...prev, position, error: null, isTracking: true }));
      },
      (error) => {
        const errorMsg = getErrorMessage(error);
        setState(prev => ({ ...prev, error: errorMsg, isTracking: false }));
      },
      geolocationOptions
    );

    setState(prev => ({ ...prev, isTracking: true }));
  }, [enableHighAccuracy, timeout, maximumAge]);

  // Stop continuous tracking
  const stopTracking = useCallback(() => {
    if (watchIdRef.current !== null) {
      navigator.geolocation.clearWatch(watchIdRef.current);
      watchIdRef.current = null;
    }
    setState(prev => ({ ...prev, isTracking: false }));
  }, []);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (watchIdRef.current !== null) {
        navigator.geolocation.clearWatch(watchIdRef.current);
      }
    };
  }, []);

  return {
    ...state,
    getCurrentPosition,
    startTracking,
    stopTracking,
  };
};

function getErrorMessage(error: GeolocationPositionError): string {
  switch (error.code) {
    case error.PERMISSION_DENIED:
      return 'Location permission denied. Please enable location access.';
    case error.POSITION_UNAVAILABLE:
      return 'Location unavailable. Please try again.';
    case error.TIMEOUT:
      return 'Location request timed out. Please try again.';
    default:
      return 'Unknown location error.';
  }
}
