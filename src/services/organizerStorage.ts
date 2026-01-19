/**
 * Local storage utility for organizer events
 * Allows organizers to return to their events after closing the browser
 */

const STORAGE_KEY = 'scenic-walk-organizer-events';

export interface SavedEvent {
  id: string;
  name: string;
  pin: string;
  createdAt: number;
}

/**
 * Get all organizer events from localStorage
 */
export function getOrganizerEvents(): SavedEvent[] {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (!stored) return [];
    return JSON.parse(stored) as SavedEvent[];
  } catch {
    return [];
  }
}

/**
 * Save a new organizer event to localStorage
 */
export function saveOrganizerEvent(event: SavedEvent): void {
  const events = getOrganizerEvents();
  // Avoid duplicates
  const filtered = events.filter(e => e.id !== event.id);
  filtered.unshift(event); // Add to front (most recent first)
  localStorage.setItem(STORAGE_KEY, JSON.stringify(filtered));
}

/**
 * Remove an organizer event from localStorage
 */
export function removeOrganizerEvent(eventId: string): void {
  const events = getOrganizerEvents();
  const filtered = events.filter(e => e.id !== eventId);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(filtered));
}

/**
 * Get a specific event's stored PIN (for auto-verification)
 */
export function getStoredPin(eventId: string): string | null {
  const events = getOrganizerEvents();
  const event = events.find(e => e.id === eventId);
  return event?.pin ?? null;
}
