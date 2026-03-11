# Backend Integration: Contact Alert SMS via NotifyLk

## Goal

Replace device-based SMS sending with backend-based SMS delivery for the per-contact emergency `Alert` action in the USafe frontend.

The frontend has already been updated to stop using local device SMS capability for this flow. It now expects the backend to send the SMS through NotifyLk.

## Why this change is needed

The old frontend flow used `flutter_sms`, which depends on the user device having native SMS support. On devices without SMS capability, the app showed:

`SMS is not available on this device.`

The new flow must send SMS from the backend instead.

## Frontend contract

The frontend now calls an authenticated backend endpoint when a user taps `Alert` on a trusted contact.

### Endpoint lookup order currently used by frontend

The frontend tries these endpoints in order:

1. `POST /contact/contacts/:contactId/alert`
2. `POST /contact/alert`
3. `POST /emergency/contact-alert`
4. `POST /emergency/contacts/alert`

Recommended implementation:

`POST /contact/contacts/:contactId/alert`

If that route exists and returns success, the frontend will use it.

## Request format

### Headers

```http
Authorization: Bearer <jwt>
Content-Type: application/json
```

### Path params

```txt
contactId: string
```

### JSON body

```json
{
  "contactId": "67d0c1f234567890abcd1234",
  "phoneNumber": "+94771234567",
  "message": "This is an emergency. I may need help. Please contact me immediately or check my location."
}
```

Notes:

- `contactId` is also sent in the body, but the backend should trust the path param first.
- `phoneNumber` can be ignored if the backend always loads the contact from DB.
- `message` should be required.

## Success response

The frontend expects JSON and will display `message` in a snackbar.

Recommended response:

```json
{
  "success": true,
  "message": "Emergency alert sent successfully.",
  "provider": "notifylk",
  "contactId": "67d0c1f234567890abcd1234",
  "phoneNumber": "+94771234567",
  "providerMessageId": "optional-provider-message-id"
}
```

## Error responses

Use JSON with a clear `message` field. The frontend displays this directly.

### Unauthorized

```json
{
  "success": false,
  "message": "Invalid or expired token."
}
```

Status: `401`

### Contact not found

```json
{
  "success": false,
  "message": "Contact not found."
}
```

Status: `404`

### Validation failure

```json
{
  "success": false,
  "message": "Message is required."
}
```

Status: `400`

### NotifyLk/provider failure

```json
{
  "success": false,
  "message": "Failed to send emergency alert."
}
```

Status: `502` preferred, `500` acceptable

## Required backend behavior

### 1. Authenticate the user

Use the existing JWT auth middleware.

The request must be rejected if the token is missing or invalid.

### 2. Verify contact ownership

The `contactId` must belong to the authenticated user.

Do not allow users to send alerts to contacts they do not own.

### 3. Load the contact from the database

Fetch the trusted contact by:

- `contactId`
- `userId`

Use the database phone number as the source of truth.

### 4. Validate and normalize phone number

Normalize to a NotifyLk-compatible format before sending.

Recommended rules:

- trim whitespace
- keep digits and leading `+`
- convert local Sri Lankan numbers like `0771234567` to `94771234567` or `+94771234567` depending on NotifyLk requirement
- reject empty or invalid numbers

### 5. Validate message

Rules:

- required
- trim whitespace
- reject empty string
- optional max length check if provider has a limit

### 6. Send SMS through NotifyLk

The backend should call NotifyLk directly using server credentials from environment variables.

### 7. Persist logging

Recommended to store a send log with:

- `userId`
- `contactId`
- `phoneNumber`
- `message`
- `provider`
- `providerResponse`
- `status`
- `createdAt`

This is useful for debugging and auditability.

## Required environment variables

Add these to backend environment config:

```env
NOTIFYLK_USER_ID=your_notifylk_user_id
NOTIFYLK_API_KEY=your_notifylk_api_key
NOTIFYLK_SENDER_ID=your_sender_id
NOTIFYLK_BASE_URL=https://app.notify.lk/api/v1
```

If the backend already has a NotifyLk integration, reuse that existing service instead of creating a duplicate.

## Recommended route implementation

### Express route example

```js
router.post('/contact/contacts/:contactId/alert', authMiddleware, async (req, res) => {
  try {
    const { contactId } = req.params;
    const userId = req.user.id;
    const message = String(req.body.message ?? '').trim();

    if (!message) {
      return res.status(400).json({
        success: false,
        message: 'Message is required.',
      });
    }

    const contact = await Contact.findOne({ _id: contactId, userId });
    if (!contact) {
      return res.status(404).json({
        success: false,
        message: 'Contact not found.',
      });
    }

    const normalizedPhone = normalizePhoneNumber(contact.phone);
    if (!normalizedPhone) {
      return res.status(400).json({
        success: false,
        message: 'Valid phone number is required.',
      });
    }

    const notifyResult = await notifyLkService.sendSms({
      to: normalizedPhone,
      message,
    });

    await SmsLog.create({
      userId,
      contactId,
      phoneNumber: normalizedPhone,
      message,
      provider: 'notifylk',
      providerResponse: notifyResult,
      status: 'sent',
    });

    return res.status(200).json({
      success: true,
      message: 'Emergency alert sent successfully.',
      provider: 'notifylk',
      contactId,
      phoneNumber: normalizedPhone,
      providerMessageId: notifyResult?.messageId ?? null,
    });
  } catch (error) {
    return res.status(502).json({
      success: false,
      message: error.message || 'Failed to send emergency alert.',
    });
  }
});
```

## NotifyLk service example

Adjust payload keys if your current NotifyLk account or SDK expects a different schema.

```js
const axios = require('axios');

async function sendSms({ to, message }) {
  const baseUrl = process.env.NOTIFYLK_BASE_URL || 'https://app.notify.lk/api/v1';

  const payload = {
    user_id: process.env.NOTIFYLK_USER_ID,
    api_key: process.env.NOTIFYLK_API_KEY,
    sender_id: process.env.NOTIFYLK_SENDER_ID,
    to,
    message,
  };

  const response = await axios.post(`${baseUrl}/send`, payload, {
    headers: {
      'Content-Type': 'application/json',
    },
    timeout: 15000,
  });

  const data = response.data;

  if (!data || (data.status !== 'success' && data.success !== true)) {
    throw new Error(data?.message || 'NotifyLk send failed');
  }

  return {
    raw: data,
    messageId: data?.data?.message_id || data?.message_id || null,
  };
}

module.exports = {
  sendSms,
};
```

## Phone normalization example

Use the backend's canonical normalization logic if one already exists.

```js
function normalizePhoneNumber(value) {
  const raw = String(value || '').trim();
  if (!raw) return '';

  const cleaned = raw.replace(/[^\d+]/g, '');
  if (!cleaned) return '';

  if (cleaned.startsWith('+94')) {
    return cleaned;
  }

  if (cleaned.startsWith('94')) {
    return `+${cleaned}`;
  }

  if (cleaned.startsWith('0') && cleaned.length === 10) {
    return `+94${cleaned.slice(1)}`;
  }

  return cleaned.startsWith('+') ? cleaned : `+${cleaned}`;
}
```

## Files/backend areas likely to change

The backend Codex should look for and modify the equivalent of:

1. contact router
2. contact controller
3. auth middleware usage
4. NotifyLk SMS service
5. environment config
6. optional SMS log model/table

## Acceptance criteria

The feature is complete when all of the following are true:

1. Tapping `Alert` on a trusted contact does not depend on device SMS capability.
2. Backend sends the SMS using NotifyLk.
3. Only the logged-in user's own contacts can be targeted.
4. Frontend receives a JSON success response with a `message`.
5. Failures return clear JSON error messages.
6. The route works with JWT authentication.

## Frontend status

The frontend is already prepared for this integration.

It now sends alert requests through backend API instead of `flutter_sms`.

## Recommended instruction to backend Codex

Use this exact brief:

```txt
Implement backend support for per-contact emergency alert SMS via NotifyLk.

Create POST /contact/contacts/:contactId/alert with JWT auth.
Validate that the contact belongs to the authenticated user.
Load the contact phone from DB, normalize it, and send the provided message using NotifyLk.
Return JSON with success/message/provider/contactId/phoneNumber.
Use clear 400/401/404/502 error responses with a message field.
Add environment variables for NOTIFYLK_USER_ID, NOTIFYLK_API_KEY, NOTIFYLK_SENDER_ID, and NOTIFYLK_BASE_URL.
Reuse existing NotifyLk service if present; otherwise create one.
Add logging for each SMS attempt if practical.
```
