# Low Safety Score Push Notification Integration

Date: 2026-03-19
Base URL: `http://localhost:5000`
Auth: Required for all device-token endpoints (`Authorization: Bearer <jwt_token>`)
Delivery: Firebase Cloud Messaging (FCM) push notification

## Goal

When a user's latest safety score falls below `40`, USafe must send a real device notification from the USafe app, even if the app is in the background or fully closed.

This must not be implemented as an in-app banner only.

## Expected User Experience

If the backend determines the user's safety score is below `40`, the user should receive a device notification like:

- Title: `Safety Score Is Low`
- Body: `Your safety score dropped below 40. Activate Emergency now.`

The notification should appear in the OS notification tray as a USafe notification.

When the user taps the notification:

- the USafe app should open
- the app should route the user into the emergency/safety flow

## Core Requirement

The backend must own the low-score trigger and notification send.

The frontend will:

- register the device push token with the backend
- receive and display foreground notifications
- respond when the user taps the notification

The backend must:

- store device tokens for the authenticated user
- decide when the user's latest safety score is below `40`
- send the push notification through FCM

## Frontend Contract Needed From Backend

### 1) Register Device Push Token

Recommended endpoint:

`POST /notification/device-token`

Content type:

- `application/json`

Request body:

```json
{
  "token": "<fcm_device_token>",
  "platform": "android",
  "deviceName": "optional-device-name"
}
```

Notes:

- `token` is required
- `platform` should be one of `android`, `ios`, or `web`
- backend should upsert instead of duplicating tokens
- backend should associate the token with the authenticated user

Recommended success response:

```json
{
  "success": true,
  "message": "Device token registered successfully."
}
```

Recommended error responses:

- `400` invalid token
- `401` missing/invalid JWT
- `500` server error

### 2) Optional Remove Device Token on Logout

Recommended endpoint:

`DELETE /notification/device-token`

Content type:

- `application/json`

Request body:

```json
{
  "token": "<fcm_device_token>"
}
```

Recommended success response:

```json
{
  "success": true,
  "message": "Device token removed successfully."
}
```

This is recommended but not mandatory for the first version.

## Notification Trigger Rule

The backend must send the push notification when:

- the latest computed safety score is below `40`

The backend should avoid spamming the user repeatedly for the same unsafe state.

Recommended cooldown:

- do not send duplicate low-score notifications more than once within `15` to `30` minutes unless the state meaningfully changes

## Recommended Backend Notification Payload

The backend should send both:

- a visible `notification` payload for OS-level display
- a `data` payload so the app can route correctly after tap

Recommended FCM payload:

```json
{
  "token": "<fcm_token>",
  "notification": {
    "title": "Safety Score Is Low",
    "body": "Your safety score dropped below 40. Activate Emergency now."
  },
  "data": {
    "type": "low_safety_score",
    "score": "34",
    "threshold": "40",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  },
  "android": {
    "priority": "high",
    "notification": {
      "channel_id": "usafe_emergency_alerts"
    }
  },
  "apns": {
    "headers": {
      "apns-priority": "10"
    },
    "payload": {
      "aps": {
        "sound": "default"
      }
    }
  }
}
```

## Recommended Backend Behavior

### 1. Authenticate and store the device token

When the frontend sends `POST /notification/device-token`, the backend should:

- authenticate the user
- validate the token
- normalize platform/device metadata
- upsert the token for that user
- mark whether the token is active

### 2. Compute or receive the latest safety score

The backend may use:

- periodic background jobs
- safety telemetry updates
- location-triggered recalculation
- scheduled checks

Whatever mechanism is used, the backend must evaluate the current safety score server-side.

### 3. Trigger push when score is below `40`

When score `< 40`:

- create a low-safety notification event
- send push via FCM to all active tokens for that user
- apply duplicate suppression/cooldown

### 4. Log delivery attempts

Recommended fields:

- `userId`
- `token`
- `platform`
- `notificationType`
- `score`
- `threshold`
- `provider`
- `providerResponse`
- `status`
- `sentAt`

### 5. Disable invalid tokens

If FCM returns invalid/unregistered token errors, the backend should mark those tokens inactive.

## Suggested Database Model

Recommended device token record:

```json
{
  "userId": "123",
  "token": "<fcm_token>",
  "platform": "android",
  "deviceName": "Pixel 7",
  "isActive": true,
  "lastUsedAt": "2026-03-19T08:00:00.000Z",
  "createdAt": "2026-03-19T08:00:00.000Z",
  "updatedAt": "2026-03-19T08:00:00.000Z"
}
```

## Backend Response Guidelines

Use JSON with a clear `message` field for all responses.

Examples:

### Validation error

```json
{
  "success": false,
  "message": "Device token is required."
}
```

### Unauthorized

```json
{
  "success": false,
  "message": "Invalid or expired token."
}
```

### Push send failure

```json
{
  "success": false,
  "message": "Failed to send low safety score notification."
}
```

## Recommended Backend Areas To Implement

The backend Codex should look for and modify the equivalent of:

1. notification router
2. notification controller/service
3. JWT auth middleware
4. safety score evaluation job/service
5. Firebase Admin / FCM service
6. device-token persistence model/table
7. notification send log model/table

## Acceptance Criteria

The feature is complete when all of the following are true:

1. The frontend can register the device push token for the logged-in user.
2. The backend stores the token successfully.
3. The backend detects when a user's safety score drops below `40`.
4. The backend sends a real USafe device notification via FCM.
5. The notification appears even if the app is backgrounded or closed.
6. The notification title/body matches the low-safety emergency warning.
7. Duplicate notifications are rate-limited.
8. Invalid tokens are cleaned up automatically.

## Frontend Status

The frontend is being prepared to:

1. request notification permission
2. register the FCM token with backend
3. handle foreground push display
4. react when the user taps a low-safety notification

What the frontend cannot do alone:

- decide the true low-safety trigger while the app is closed
- send OS notifications from USafe by itself without backend push delivery

## Exact Backend Instruction

Use this brief with backend Codex:

```txt
Implement low safety score push notifications for USafe.

Create POST /notification/device-token with JWT auth to register an authenticated user's FCM token.
Optionally create DELETE /notification/device-token to remove a token on logout.

Store active device tokens per user.
When the backend computes a latest safety score below 40, send a real push notification through Firebase Cloud Messaging.

Notification text:
- title: Safety Score Is Low
- body: Your safety score dropped below 40. Activate Emergency now.

Include a data payload with:
- type=low_safety_score
- score=<current score>
- threshold=40

Add duplicate suppression so the same low-score notification is not sent repeatedly within a short cooldown window.
Disable invalid/unregistered tokens automatically.
Return clear JSON success/message responses from token registration endpoints.
```
