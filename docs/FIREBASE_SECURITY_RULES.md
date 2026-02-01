# Firebase Realtime Database Security Rules

## Overview

These security rules should be deployed to your Firebase Realtime Database to secure your production environment. The rules control who can read and write data.

## Production Rules

Copy and paste these rules into your Firebase Console at:
**Firebase Console > Realtime Database > Rules**

```json
{
  "rules": {
    // Events collection
    "events": {
      // Allow listing all events (for potential future admin features)
      ".read": false,

      "$eventId": {
        // Anyone can read event data (needed for participants)
        ".read": true,

        // Only allow creating new events, not updating existing ones
        // This prevents tampering with event data after creation
        ".write": "!data.exists() && newData.exists()",

        // Validate event structure
        ".validate": "newData.hasChildren(['id', 'name', 'organizerPin', 'route', 'status', 'createdAt'])",

        "id": {
          ".validate": "newData.val() == $eventId"
        },
        "name": {
          ".validate": "newData.isString() && newData.val().length > 0 && newData.val().length <= 100"
        },
        "organizerPin": {
          // PIN should be exactly 4 characters
          ".validate": "newData.isString() && newData.val().length == 4",
          // IMPORTANT: Consider hashing PINs in a future version
          // Currently stored in plaintext for simplicity
        },
        "route": {
          ".validate": "newData.isArray()"
        },
        "status": {
          // Allow updating status (for ending events)
          ".write": true,
          ".validate": "newData.val() == 'active' || newData.val() == 'ended'"
        },
        "createdAt": {
          ".validate": "newData.isNumber()"
        },
        "broadcastMode": {
          ".validate": "newData.val() == 'continuous' || newData.val() == 'manual'"
        }
      }
    },

    // Locations collection (organizer's live location)
    "locations": {
      "$eventId": {
        // Anyone can read location (needed for participants to see organizer)
        ".read": true,

        // Anyone can write location (organizer broadcasts here)
        // In production, you might want to validate this against the event's organizerPin
        // but that would require passing the PIN with each location update
        ".write": true,

        // Validate location structure
        ".validate": "newData.hasChildren(['lat', 'lng', 'timestamp'])",

        "lat": {
          ".validate": "newData.isNumber() && newData.val() >= -90 && newData.val() <= 90"
        },
        "lng": {
          ".validate": "newData.isNumber() && newData.val() >= -180 && newData.val() <= 180"
        },
        "timestamp": {
          ".validate": "newData.isNumber()"
        },
        "accuracy": {
          ".validate": "newData.isNumber() && newData.val() >= 0"
        }
      }
    },

    // Deny access to any other paths
    "$other": {
      ".read": false,
      ".write": false
    }
  }
}
```

## Development Rules (Less Restrictive)

For development/testing, you can use these more permissive rules:

```json
{
  "rules": {
    "events": {
      ".read": true,
      ".write": true
    },
    "locations": {
      ".read": true,
      ".write": true
    }
  }
}
```

**WARNING:** Never use development rules in production!

## Security Considerations

### Current Limitations

1. **PIN Storage:** Organizer PINs are stored in plaintext. Consider hashing them in a future version using Firebase Cloud Functions.

2. **Location Write Access:** Currently, anyone with the event ID can write location data. This is acceptable because:
   - Event IDs are random UUIDs (hard to guess)
   - Only the organizer app writes location data
   - Malicious location updates would be obvious to participants

3. **Event Immutability:** Events cannot be modified after creation (except status). This prevents tampering but means organizers can't edit event names or routes.

### Future Improvements

1. **PIN Hashing:** Use Firebase Cloud Functions to hash PINs on creation and verify them on updates.

2. **Custom Claims:** Implement Firebase Authentication with custom claims to identify organizers.

3. **Rate Limiting:** Add rate limiting rules to prevent abuse.

4. **Data Expiration:** Implement automatic cleanup of old events and location data.

## How to Deploy Rules

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project **scenic-walk-484001**
3. Navigate to **Realtime Database** > **Rules**
4. Replace the existing rules with the production rules above
5. Click **Publish**

## Testing Rules

Use the Firebase Rules Playground in the console to test your rules:

1. Go to **Realtime Database** > **Rules**
2. Click **Rules Playground**
3. Test read/write operations with different paths

### Test Cases

| Operation | Path | Should Succeed |
|-----------|------|----------------|
| Read | `/events/abc123` | Yes |
| Read | `/events` | No |
| Write (new) | `/events/newid` | Yes |
| Write (update) | `/events/existing` | No |
| Read | `/locations/abc123` | Yes |
| Write | `/locations/abc123` | Yes |
| Read | `/other/path` | No |

## Monitoring

Enable Firebase Realtime Database monitoring to track:
- Read/write operations
- Denied operations (security rule violations)
- Data bandwidth usage

Go to **Realtime Database** > **Usage** in the Firebase Console.
