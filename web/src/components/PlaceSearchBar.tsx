/// <reference types="google.maps" />
import { useEffect, useRef, useState, useCallback } from 'react';

interface PlaceSearchBarProps {
  onPlaceSelected: (location: { lat: number; lng: number }) => void;
}

interface Prediction {
  placeId: string;
  description: string;
  mainText: string;
  secondaryText: string;
}

export const PlaceSearchBar: React.FC<PlaceSearchBarProps> = ({ onPlaceSelected }) => {
  const inputRef = useRef<HTMLInputElement>(null);
  const autocompleteServiceRef = useRef<google.maps.places.AutocompleteService | null>(null);
  const placesServiceRef = useRef<google.maps.places.PlacesService | null>(null);
  const sessionTokenRef = useRef<google.maps.places.AutocompleteSessionToken | null>(null);

  const [inputValue, setInputValue] = useState('');
  const [predictions, setPredictions] = useState<Prediction[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [showDropdown, setShowDropdown] = useState(false);

  // Initialize services
  useEffect(() => {
    const initServices = async () => {
      try {
        const { AutocompleteService, AutocompleteSessionToken, PlacesService } =
          await google.maps.importLibrary('places') as google.maps.PlacesLibrary;

        autocompleteServiceRef.current = new AutocompleteService();
        sessionTokenRef.current = new AutocompleteSessionToken();

        // PlacesService requires a DOM element or map
        const dummyDiv = document.createElement('div');
        placesServiceRef.current = new PlacesService(dummyDiv);
      } catch (error) {
        console.error('Failed to initialize Places services:', error);
      }
    };

    initServices();
  }, []);

  // Debounced search
  useEffect(() => {
    if (!inputValue.trim()) {
      setPredictions([]);
      return;
    }

    const timeoutId = setTimeout(() => {
      searchPlaces(inputValue);
    }, 300);

    return () => clearTimeout(timeoutId);
  }, [inputValue]);

  const searchPlaces = async (query: string) => {
    if (!autocompleteServiceRef.current || !sessionTokenRef.current) return;

    setIsLoading(true);

    try {
      const request: google.maps.places.AutocompletionRequest = {
        input: query,
        sessionToken: sessionTokenRef.current,
      };

      autocompleteServiceRef.current.getPlacePredictions(
        request,
        (results, status) => {
          setIsLoading(false);

          if (status === google.maps.places.PlacesServiceStatus.OK && results) {
            const mapped: Prediction[] = results.map((p) => ({
              placeId: p.place_id,
              description: p.description,
              mainText: p.structured_formatting?.main_text || p.description,
              secondaryText: p.structured_formatting?.secondary_text || '',
            }));
            setPredictions(mapped);
            setShowDropdown(mapped.length > 0);
          } else {
            setPredictions([]);
            setShowDropdown(false);
          }
        }
      );
    } catch (error) {
      console.error('Places search error:', error);
      setIsLoading(false);
      setPredictions([]);
    }
  };

  const handlePredictionSelect = useCallback((prediction: Prediction) => {
    if (!placesServiceRef.current || !sessionTokenRef.current) return;

    setInputValue(prediction.mainText);
    setShowDropdown(false);
    setPredictions([]);
    setIsLoading(true);

    const request: google.maps.places.PlaceDetailsRequest = {
      placeId: prediction.placeId,
      fields: ['geometry'],
      sessionToken: sessionTokenRef.current,
    };

    placesServiceRef.current.getDetails(request, (place, status) => {
      setIsLoading(false);

      // Reset session token after place details (ends the session)
      sessionTokenRef.current = new google.maps.places.AutocompleteSessionToken();

      if (status === google.maps.places.PlacesServiceStatus.OK && place?.geometry?.location) {
        onPlaceSelected({
          lat: place.geometry.location.lat(),
          lng: place.geometry.location.lng(),
        });
      }
    });
  }, [onPlaceSelected]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setInputValue(e.target.value);
    if (e.target.value.trim()) {
      setShowDropdown(true);
    }
  };

  const handleClear = () => {
    setInputValue('');
    setPredictions([]);
    setShowDropdown(false);
    inputRef.current?.focus();
  };

  return (
    <div className="relative w-full">
      <div className="relative">
        <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400">
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
        </span>
        <input
          ref={inputRef}
          type="text"
          value={inputValue}
          onChange={handleInputChange}
          onFocus={() => predictions.length > 0 && setShowDropdown(true)}
          onBlur={() => setTimeout(() => setShowDropdown(false), 200)}
          placeholder="Search for a location..."
          className="w-full pl-9 pr-8 py-2 text-sm border dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
        />
        {isLoading ? (
          <span className="absolute right-3 top-1/2 -translate-y-1/2">
            <svg className="w-4 h-4 animate-spin text-gray-400" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
            </svg>
          </span>
        ) : inputValue && (
          <button
            onClick={handleClear}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        )}
      </div>

      {/* Dropdown */}
      {showDropdown && predictions.length > 0 && (
        <div className="absolute z-50 w-full mt-1 bg-white dark:bg-gray-800 border dark:border-gray-600 rounded-lg shadow-lg max-h-60 overflow-y-auto">
          {predictions.map((prediction) => (
            <button
              key={prediction.placeId}
              onClick={() => handlePredictionSelect(prediction)}
              className="w-full px-3 py-2 text-left hover:bg-gray-100 dark:hover:bg-gray-700 flex items-start gap-2 border-b dark:border-gray-700 last:border-0"
            >
              <span className="text-gray-400 mt-0.5">
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
              </span>
              <div className="flex-1 min-w-0">
                <div className="text-sm font-medium text-gray-900 dark:text-gray-100 truncate">
                  {prediction.mainText}
                </div>
                {prediction.secondaryText && (
                  <div className="text-xs text-gray-500 dark:text-gray-400 truncate">
                    {prediction.secondaryText}
                  </div>
                )}
              </div>
            </button>
          ))}
        </div>
      )}
    </div>
  );
};

export default PlaceSearchBar;
