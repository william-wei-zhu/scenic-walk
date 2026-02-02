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
      // Listing all events is denied (no admin features yet)
      ".read": false,

      "$eventId": {
        // Anyone can read event data (needed for participants)
        ".read": true,

        // Allow create, update, and delete operations
        ".write": true,

        // Validate event structure (allows deletion when newData doesn't exist)
        ".validate": "!newData.exists() || newData.hasChildren(['id', 'name', 'organizerPin', 'route', 'status', 'createdAt'])",

        "id": {
          ".validate": "newData.val() == $eventId"
        },
        "name": {
          ".validate": "newData.isString() && newData.val().length > 0 && newData.val().length <= 100"
        },
        "organizerPin": {
          // PIN should be exactly 4 characters
          ".validate": "newData.isString() && newData.val().length == 4"
        },
        "route": {
          ".validate": "newData.exists()"
        },
        "status": {
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

        // Anyone can write/delete location (organizer broadcasts here)
        ".write": true,

        // Validate location structure (allows deletion when newData doesn't exist)
        ".validate": "!newData.exists() || newData.hasChildren(['lat', 'lng', 'timestamp'])",

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

3. **Event Mutability:** Events can be created, updated, and deleted by anyone with the event ID. This allows organizers to manage their events but means malicious users could potentially modify events if they know the ID.

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
| Write (update) | `/events/existing` | Yes |
| Delete | `/events/existing` | Yes |
| Read | `/locations/abc123` | Yes |
| Write | `/locations/abc123` | Yes |
| Delete | `/locations/abc123` | Yes |
| Read | `/other/path` | No |

## Monitoring

Enable Firebase Realtime Database monitoring to track:
- Read/write operations
- Denied operations (security rule violations)
- Data bandwidth usage

Go to **Realtime Database** > **Usage** in the Firebase Console.
