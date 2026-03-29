# Emergency Start FE to BE Handover

## Summary

The frontend now sends emergency context data in the authenticated SOS start request.

Endpoints:

- `POST /emergency/start`
- `POST /emergency/:sessionId/call/:contactIndex/attempt`
- `POST /emergency/:sessionId/call-119`

The existing auth behavior is unchanged:

- Header: `Authorization: Bearer <jwt>`
- Header: `Content-Type: application/json`

Guest mode is unchanged and still uses the device SMS and dialer apps directly. This handover only applies to the authenticated backend-driven emergency flow.

## New Request Body

The frontend now sends this JSON body on:

- `POST /emergency/start`
- `POST /emergency/:sessionId/call/:contactIndex/attempt`
- `POST /emergency/:sessionId/call-119`

For contact call attempts, `timeoutSec` is also included.

Example `POST /emergency/start` body:

```json
{
  "userName": "Jane Doe",
  "triggeredAt": "2026-03-21T14:32:10.123+05:30",
  "latitude": 6.92708,
  "longitude": 79.86124,
  "approximateAddress": "Colombo 02, Colombo, Western Province, Sri Lanka"
}
```

Example `POST /emergency/:sessionId/call/:contactIndex/attempt` body:

```json
{
  "userName": "Jane Doe",
  "triggeredAt": "2026-03-21T14:32:10.123+05:30",
  "latitude": 6.92708,
  "longitude": 79.86124,
  "approximateAddress": "Colombo 02, Colombo, Western Province, Sri Lanka",
  "timeoutSec": 30
}
```

Example `POST /emergency/:sessionId/call-119` body:

```json
{
  "userName": "Jane Doe",
  "triggeredAt": "2026-03-21T14:32:10.123+05:30",
  "latitude": 6.92708,
  "longitude": 79.86124,
  "approximateAddress": "Colombo 02, Colombo, Western Province, Sri Lanka"
}
```

All fields are optional from the frontend point of view. The backend must tolerate partial payloads.

## Field Definitions

- `userName`
  - Type: `string`
  - Source: logged-in user profile cached in the app
  - Fallback: omitted if unavailable

- `latitude`
  - Type: `number`
  - Source: device location at SOS start
  - Fallback: omitted if unavailable

- `triggeredAt`
  - Type: `string`
  - Format: ISO 8601 datetime string
  - Source: frontend SOS trigger time
  - Fallback: omitted if unavailable

- `longitude`
  - Type: `number`
  - Source: device location at SOS start
  - Fallback: omitted if unavailable

- `approximateAddress`
  - Type: `string`
  - Source: reverse geocoded device location
  - Fallback: omitted if unavailable

## Recommended Backend Handling

Update the emergency start and calling controllers so they:

1. Reads the optional request body fields.
2. Validates types without failing the whole request for missing location data.
3. Stores the fields on the emergency session record.
4. Uses them when generating:
   - emergency SMS content
   - emergency voice/call scripts
   - any provider payloads tied to the emergency session

Recommended validation rules:

- `userName`: trim string, allow empty -> treat as missing
- `triggeredAt`: parse as ISO 8601 string, allow empty -> treat as missing
- `latitude`: finite number between `-90` and `90`
- `longitude`: finite number between `-180` and `180`
- `approximateAddress`: trim string, allow empty -> treat as missing

## Message/Call Composition Guidance

The backend should build message content from the stored emergency session fields, not from hardcoded text only.

Suggested message template:

```text
Emergency alert from {{userName}}.
Triggered at: {{triggeredAt}}.
Approximate location: {{approximateAddress}}.
Coordinates: {{latitude}}, {{longitude}}.
Please contact me immediately or check on me now.
```

Suggested fallback behavior:

- If `userName` is missing, use `"a uSafe user"` or the backend profile name.
- If `triggeredAt` is missing, use the backend session creation time.
- If `approximateAddress` is missing but coordinates exist, use coordinates only.
- If coordinates are missing, omit that line.
- Do not fail emergency start just because address lookup was unavailable on the device.

## Expected Router/Controller Changes

Update the backend pieces that handle the authenticated emergency flow:

- Emergency router
  - Ensure `POST /emergency/start` accepts a JSON body.
  - Ensure `POST /emergency/:sessionId/call/:contactIndex/attempt` accepts a JSON body.
  - Ensure `POST /emergency/:sessionId/call-119` accepts a JSON body.

- Emergency start controller
  - Read `req.body.userName`
  - Read `req.body.triggeredAt`
  - Read `req.body.latitude`
  - Read `req.body.longitude`
  - Read `req.body.approximateAddress`
  - Pass these values into the emergency service layer

- Emergency contact-call controller
  - Read `req.body.userName`
  - Read `req.body.triggeredAt`
  - Read `req.body.latitude`
  - Read `req.body.longitude`
  - Read `req.body.approximateAddress`
  - Read `req.body.timeoutSec`
  - Use request values directly or fall back to the stored session fields

- Emergency 119 controller
  - Read `req.body.userName`
  - Read `req.body.triggeredAt`
  - Read `req.body.latitude`
  - Read `req.body.longitude`
  - Read `req.body.approximateAddress`
  - Use request values directly or fall back to the stored session fields

- Emergency service / session creation logic
  - Persist the new fields in the emergency session object or database row
  - Make them available to later steps:
    - contact messaging
    - contact calling
    - 119 escalation
    - status endpoints if needed

- Messaging feature
  - Replace static emergency text with generated content using the stored session fields

- Calling feature
  - If you generate TTS, call scripts, or provider text prompts, use the same stored session fields
  - For `call/:contactIndex/attempt` and `call-119`, accept the request body context and merge it with stored session context before provider calls

## Compatibility Note

The frontend still supports the previous backend behavior in the sense that it will send the request successfully even if the backend ignores the new body fields. However, to actually include user, time, and location details in emergency messages and calls, the backend must be updated to consume them on all three endpoints above.

## Frontend Source References

- [`lib/widgets/sos_screen.dart`](g:\VsProjects\usafe_front_end\lib\widgets\sos_screen.dart)
- [`lib/features/auth/auth_service.dart`](g:\VsProjects\usafe_front_end\lib\features\auth\auth_service.dart)
