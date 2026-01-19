/**
 * Firebase configuration and walk event operations
 */
import { initializeApp } from 'firebase/app';
import { getDatabase, ref, set, get, onValue } from 'firebase/database';
import type { WalkEvent, OrganizerLocation } from '../types';

// Firebase configuration from environment variables
const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
  databaseURL: import.meta.env.VITE_FIREBASE_DATABASE_URL,
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Firebase Realtime Database
const db = getDatabase(app);

// ============================================
// Walk Event CRUD Operations
// ============================================

/**
 * Create a new walk event
 */
export const createWalkEvent = async (event: WalkEvent): Promise<void> => {
  const eventRef = ref(db, `events/${event.id}`);
  await set(eventRef, event);
};

/**
 * Get a single walk event by ID
 */
export const getWalkEvent = async (eventId: string): Promise<WalkEvent | null> => {
  const eventRef = ref(db, `events/${eventId}`);
  const snapshot = await get(eventRef);
  return snapshot.exists() ? snapshot.val() as WalkEvent : null;
};

/**
 * Subscribe to walk event changes (real-time updates)
 */
export const subscribeToWalkEvent = (
  eventId: string,
  callback: (event: WalkEvent | null) => void
): (() => void) => {
  const eventRef = ref(db, `events/${eventId}`);
  const unsubscribe = onValue(eventRef, (snapshot) => {
    callback(snapshot.exists() ? snapshot.val() as WalkEvent : null);
  });
  return unsubscribe;
};

/**
 * Get all walk events, sorted by creation time (newest first)
 */
export const getAllWalkEvents = async (): Promise<WalkEvent[]> => {
  const eventsRef = ref(db, 'events');
  const snapshot = await get(eventsRef);
  if (!snapshot.exists()) return [];

  const eventsObj = snapshot.val() as Record<string, WalkEvent>;
  return Object.values(eventsObj).sort((a, b) => b.createdAt - a.createdAt);
};

/**
 * Update walk event status (active/ended)
 */
export const updateWalkEventStatus = async (
  eventId: string,
  status: 'active' | 'ended'
): Promise<void> => {
  const eventRef = ref(db, `events/${eventId}/status`);
  await set(eventRef, status);
};

/**
 * Delete a walk event and its associated location data
 */
export const deleteWalkEvent = async (eventId: string): Promise<void> => {
  const eventRef = ref(db, `events/${eventId}`);
  await set(eventRef, null);
  // Also clear any associated location data
  const locationRef = ref(db, `locations/${eventId}`);
  await set(locationRef, null);
};

// ============================================
// Organizer Location Operations
// ============================================

/**
 * Update organizer's current location
 */
export const updateOrganizerLocation = async (
  eventId: string,
  location: OrganizerLocation
): Promise<void> => {
  const locationRef = ref(db, `locations/${eventId}`);
  await set(locationRef, location);
};

/**
 * Subscribe to organizer's location updates (real-time)
 */
export const subscribeToOrganizerLocation = (
  eventId: string,
  callback: (location: OrganizerLocation | null) => void
): (() => void) => {
  const locationRef = ref(db, `locations/${eventId}`);
  const unsubscribe = onValue(locationRef, (snapshot) => {
    callback(snapshot.exists() ? snapshot.val() as OrganizerLocation : null);
  });
  return unsubscribe;
};

/**
 * Clear organizer's location (when stopping broadcast or ending event)
 */
export const clearOrganizerLocation = async (eventId: string): Promise<void> => {
  const locationRef = ref(db, `locations/${eventId}`);
  await set(locationRef, null);
};

export { db };
export default app;
