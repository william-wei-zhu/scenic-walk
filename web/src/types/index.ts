/**
 * Type definitions for Scenic Walk
 */

export interface Coordinates {
  lat: number;
  lng: number;
}

/**
 * Walk event for live GPS tracking during group walks
 */
export interface WalkEvent {
  id: string;
  name: string;
  createdAt: number;
  organizerPin: string;
  route: Coordinates[];  // Planned route drawn by organizer
  status: 'active' | 'ended';
  broadcastMode: 'continuous' | 'manual';
}

/**
 * Organizer's live location during a walk event
 */
export interface OrganizerLocation {
  lat: number;
  lng: number;
  timestamp: number;
  accuracy?: number;
}
