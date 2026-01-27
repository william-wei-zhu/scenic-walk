/// <reference types="google.maps" />
import { useEffect, useRef, useState, useCallback } from 'react';
import type { Coordinates, OrganizerLocation } from '../types';

interface WalkMapComponentProps {
  route: Coordinates[];
  organizerLocation?: OrganizerLocation | null;
  isDrawingMode?: boolean;
  showCenterButton?: boolean;
  onRouteChange?: (route: Coordinates[]) => void;
  onMapReady?: () => void;
}

const DEFAULT_CENTER = { lat: 38.9072, lng: -77.0369 }; // Washington DC
const DEFAULT_ZOOM = 14;

// Arrow spacing constants
const ARROW_BASE_SPACING_METERS = 150;
const ARROW_MIN_COUNT = 3;
const ARROW_MAX_COUNT = 20;
const ARROW_FIRST_OFFSET_PERCENT = 30; // First arrow at 30% of first interval

// Calculate the total route length in meters using Haversine formula
function calculateRouteLength(route: Coordinates[]): number {
  if (route.length < 2) return 0;

  let totalLength = 0;
  for (let i = 0; i < route.length - 1; i++) {
    totalLength += haversineDistance(route[i], route[i + 1]);
  }
  return totalLength;
}

// Haversine distance between two points in meters
function haversineDistance(p1: Coordinates, p2: Coordinates): number {
  const R = 6371000; // Earth's radius in meters
  const lat1 = (p1.lat * Math.PI) / 180;
  const lat2 = (p2.lat * Math.PI) / 180;
  const deltaLat = ((p2.lat - p1.lat) * Math.PI) / 180;
  const deltaLng = ((p2.lng - p1.lng) * Math.PI) / 180;

  const a =
    Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(deltaLng / 2) * Math.sin(deltaLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

// Calculate arrow repeat distance as a percentage string for Google Maps
function calculateArrowRepeat(route: Coordinates[]): string {
  const routeLength = calculateRouteLength(route);
  if (routeLength === 0) return '20%';

  // Calculate number of arrows based on spacing
  let arrowCount = Math.floor(routeLength / ARROW_BASE_SPACING_METERS);
  arrowCount = Math.max(ARROW_MIN_COUNT, Math.min(ARROW_MAX_COUNT, arrowCount));

  // Convert to percentage
  const repeatPercent = 100 / arrowCount;
  return `${repeatPercent.toFixed(1)}%`;
}

// Calculate first arrow offset as a percentage
function calculateArrowOffset(route: Coordinates[]): string {
  const routeLength = calculateRouteLength(route);
  if (routeLength === 0) return '10%';

  let arrowCount = Math.floor(routeLength / ARROW_BASE_SPACING_METERS);
  arrowCount = Math.max(ARROW_MIN_COUNT, Math.min(ARROW_MAX_COUNT, arrowCount));

  const repeatPercent = 100 / arrowCount;
  const offsetPercent = (repeatPercent * ARROW_FIRST_OFFSET_PERCENT) / 100;
  return `${offsetPercent.toFixed(1)}%`;
}

export const WalkMapComponent: React.FC<WalkMapComponentProps> = ({
  route,
  organizerLocation,
  isDrawingMode = false,
  showCenterButton = false,
  onRouteChange,
  onMapReady,
}) => {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<google.maps.Map | null>(null);
  const polylineRef = useRef<google.maps.Polyline | null>(null);
  const markersRef = useRef<google.maps.marker.AdvancedMarkerElement[]>([]);
  const organizerMarkerRef = useRef<google.maps.marker.AdvancedMarkerElement | null>(null);
  const routeRef = useRef<Coordinates[]>(route);
  const [isMapReady, setIsMapReady] = useState(false);
  const hasAutoFitRef = useRef(false);

  // Center map on organizer location
  const centerOnOrganizer = useCallback(() => {
    if (!mapInstanceRef.current || !organizerLocation) return;
    mapInstanceRef.current.setCenter({ lat: organizerLocation.lat, lng: organizerLocation.lng });
    mapInstanceRef.current.setZoom(16);
  }, [organizerLocation]);

  // Fit bounds to include both route and organizer
  const fitBoundsWithOrganizer = useCallback(() => {
    if (!mapInstanceRef.current || !organizerLocation) return;

    const bounds = new google.maps.LatLngBounds();
    route.forEach(point => bounds.extend(point));
    bounds.extend({ lat: organizerLocation.lat, lng: organizerLocation.lng });
    mapInstanceRef.current.fitBounds(bounds, 50);
  }, [route, organizerLocation]);

  // Keep routeRef in sync with route prop
  useEffect(() => {
    routeRef.current = route;
  }, [route]);

  // Handle map click for drawing
  const handleMapClick = useCallback((e: google.maps.MapMouseEvent) => {
    if (e.latLng && onRouteChange) {
      const newPoint = {
        lat: e.latLng.lat(),
        lng: e.latLng.lng(),
      };
      onRouteChange([...routeRef.current, newPoint]);
    }
  }, [onRouteChange]);

  // Initialize map
  useEffect(() => {
    if (!mapRef.current || mapInstanceRef.current) return;

    const initMap = async () => {
      try {
        const { Map } = await google.maps.importLibrary('maps') as google.maps.MapsLibrary;
        await google.maps.importLibrary('marker');

        const mapId = import.meta.env.VITE_GOOGLE_MAPS_MAP_ID;

        const map = new Map(mapRef.current!, {
          center: DEFAULT_CENTER,
          zoom: DEFAULT_ZOOM,
          mapId: mapId,
          disableDefaultUI: false,
          zoomControl: true,
          mapTypeControl: false,
          streetViewControl: false,
          fullscreenControl: true,
        });

        mapInstanceRef.current = map;
        setIsMapReady(true);
        onMapReady?.();
      } catch (error) {
        console.error('Failed to initialize map:', error);
      }
    };

    initMap();
  }, [onMapReady]);

  // Add/remove click listener based on drawing mode
  useEffect(() => {
    const map = mapInstanceRef.current;
    if (!map || !isMapReady) return;

    let listener: google.maps.MapsEventListener | null = null;

    if (isDrawingMode) {
      listener = map.addListener('click', handleMapClick);
    }

    return () => {
      if (listener) {
        google.maps.event.removeListener(listener);
      }
    };
  }, [isDrawingMode, isMapReady, handleMapClick]);

  // Update polyline when route changes
  useEffect(() => {
    if (!mapInstanceRef.current || !isMapReady) return;

    // Clear existing polyline
    if (polylineRef.current) {
      polylineRef.current.setMap(null);
    }

    // Clear existing markers
    markersRef.current.forEach(marker => marker.map = null);
    markersRef.current = [];

    if (route.length === 0) return;

    // Create new polyline with directional arrows
    const polyline = new google.maps.Polyline({
      path: route,
      geodesic: true,
      strokeColor: '#16a34a',
      strokeOpacity: 1.0,
      strokeWeight: 4,
      map: mapInstanceRef.current,
      icons: [{
        icon: {
          path: google.maps.SymbolPath.FORWARD_CLOSED_ARROW,
          scale: 3,
          strokeColor: '#ffffff',
          strokeWeight: 2,
          fillColor: '#16a34a',
          fillOpacity: 1,
        },
        offset: calculateArrowOffset(route),
        repeat: calculateArrowRepeat(route),
      }],
    });

    polylineRef.current = polyline;

    // Add markers for start and end points
    if (route.length > 0) {
      // Start marker (green)
      const startMarker = createMarker(route[0], 'S', '#22c55e', mapInstanceRef.current!);
      markersRef.current.push(startMarker);

      // End marker (red) - only if different from start
      if (route.length > 1) {
        const endMarker = createMarker(route[route.length - 1], 'E', '#ef4444', mapInstanceRef.current!);
        markersRef.current.push(endMarker);
      }
    }

    // Only auto-fit bounds when NOT in drawing mode (i.e., when viewing an existing route)
    // During drawing mode, let the user control the map view
    if (!isDrawingMode) {
      if (route.length > 1) {
        const bounds = new google.maps.LatLngBounds();
        route.forEach(point => bounds.extend(point));
        mapInstanceRef.current.fitBounds(bounds, 50);
      } else if (route.length === 1) {
        mapInstanceRef.current.setCenter(route[0]);
      }
    }
  }, [route, isMapReady, isDrawingMode]);

  // Update organizer marker
  useEffect(() => {
    if (!mapInstanceRef.current || !isMapReady) return;

    // Clear existing organizer marker
    if (organizerMarkerRef.current) {
      organizerMarkerRef.current.map = null;
      organizerMarkerRef.current = null;
    }

    if (!organizerLocation) {
      hasAutoFitRef.current = false;
      return;
    }

    // Create large orange flag marker for organizer
    const markerContent = document.createElement('div');
    markerContent.innerHTML = `
      <div style="position: relative; transform: translate(-50%, -100%);">
        <div style="
          position: absolute;
          left: 50%;
          bottom: 0;
          width: 4px;
          height: 60px;
          background: linear-gradient(to bottom, #333, #666);
          transform: translateX(-50%);
          border-radius: 2px;
        "></div>
        <div style="
          position: absolute;
          left: calc(50% + 2px);
          bottom: 35px;
          width: 50px;
          height: 35px;
          background: linear-gradient(135deg, #ff6b00, #ff9500);
          border-radius: 0 4px 4px 0;
          box-shadow: 0 3px 10px rgba(0,0,0,0.3);
          display: flex;
          align-items: center;
          justify-content: center;
          animation: flagWave 2s ease-in-out infinite;
        ">
          <span style="font-size: 20px;">🚶</span>
        </div>
        <div style="
          position: absolute;
          left: 50%;
          bottom: -8px;
          width: 24px;
          height: 24px;
          background: #ff6b00;
          border: 3px solid white;
          border-radius: 50%;
          transform: translateX(-50%);
          box-shadow: 0 2px 8px rgba(255,107,0,0.5);
          animation: pulse 1.5s infinite;
        "></div>
        <div style="
          position: absolute;
          left: 50%;
          bottom: -14px;
          width: 36px;
          height: 36px;
          border: 3px solid #ff6b00;
          border-radius: 50%;
          transform: translateX(-50%);
          animation: pulseRing 1.5s infinite;
        "></div>
        <style>
          @keyframes pulse {
            0%, 100% { transform: translateX(-50%) scale(1); }
            50% { transform: translateX(-50%) scale(1.1); }
          }
          @keyframes pulseRing {
            0% { transform: translateX(-50%) scale(1); opacity: 1; }
            100% { transform: translateX(-50%) scale(2); opacity: 0; }
          }
          @keyframes flagWave {
            0%, 100% { transform: skewX(0deg); }
            25% { transform: skewX(2deg); }
            75% { transform: skewX(-2deg); }
          }
        </style>
      </div>
    `;

    const marker = new google.maps.marker.AdvancedMarkerElement({
      position: { lat: organizerLocation.lat, lng: organizerLocation.lng },
      map: mapInstanceRef.current,
      content: markerContent,
      title: 'Organizer Location',
    });

    organizerMarkerRef.current = marker;

    // Auto-fit bounds on first organizer location update
    if (!hasAutoFitRef.current) {
      hasAutoFitRef.current = true;
      const bounds = new google.maps.LatLngBounds();
      route.forEach(point => bounds.extend(point));
      bounds.extend({ lat: organizerLocation.lat, lng: organizerLocation.lng });
      mapInstanceRef.current.fitBounds(bounds, 50);
    }
  }, [organizerLocation, isMapReady, route]);

  return (
    <div className="relative w-full h-full" style={{ minHeight: '300px' }}>
      <div ref={mapRef} className="w-full h-full" />

      {/* Map controls for organizer */}
      {showCenterButton && organizerLocation && (
        <div className="absolute top-3 left-3 flex flex-col gap-2 z-10">
          <button
            onClick={centerOnOrganizer}
            className="px-3 py-2 bg-green-600 text-white text-sm font-medium rounded-lg shadow-lg hover:bg-green-700 transition-colors flex items-center gap-2"
          >
            <span>📍</span> Center on Me
          </button>
          <button
            onClick={fitBoundsWithOrganizer}
            className="px-3 py-2 bg-white text-gray-700 text-sm font-medium rounded-lg shadow-lg hover:bg-gray-50 transition-colors flex items-center gap-2 border"
          >
            <span>🗺️</span> Show All
          </button>
        </div>
      )}
    </div>
  );
};

// Helper function to create a marker with label
function createMarker(
  position: Coordinates,
  label: string,
  color: string,
  map: google.maps.Map
): google.maps.marker.AdvancedMarkerElement {
  const content = document.createElement('div');
  content.innerHTML = `
    <div style="
      width: 28px;
      height: 28px;
      background: ${color};
      border: 2px solid white;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
      font-weight: bold;
      font-size: 14px;
      box-shadow: 0 2px 6px rgba(0,0,0,0.3);
    ">${label}</div>
  `;

  return new google.maps.marker.AdvancedMarkerElement({
    position,
    map,
    content,
    title: label === 'S' ? 'Start' : 'End',
  });
}

export default WalkMapComponent;
