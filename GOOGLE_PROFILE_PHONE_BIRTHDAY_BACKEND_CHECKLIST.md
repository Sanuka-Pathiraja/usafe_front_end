# Google Profile Birthday/Phone Backend Checklist

Date: 2026-03-08  
Issue: Google login succeeds and avatar updates, but `phone` and `birthday` remain empty.

## Symptom Meaning

- Avatar updated => Google auth and `idToken` verification are working.
- Missing `phone`/`birthday` => usually People API scope, consent, token, or backend People API fetch issue.

## Expected Frontend Request

`POST /user/googleLogin`

Body:
```json
{
  "idToken": "<google_id_token>",
  "accessToken": "<google_access_token>"
}
```

## Step-by-Step Backend Checks

1. Confirm request payload arrives with `accessToken`
- Log incoming body keys in `/user/googleLogin`.
- Verify `accessToken` is present and not empty.
- If missing, return a clear message in response for debugging.

2. Verify backend Google config
- `GOOGLE_CLIENT_ID` is set in backend env.
- It matches the same Web Client ID used by frontend `serverClientId`.

3. Verify People API is enabled
- In Google Cloud Console, enable:
  - `Google People API`
- Project must be the same one used by OAuth client IDs.

4. Verify scopes granted to access token
- Backend should inspect token scope set (via Google tokeninfo or People API error payload).
- Required scopes:
  - `https://www.googleapis.com/auth/user.birthday.read`
  - `https://www.googleapis.com/auth/user.phonenumbers.read`

5. Verify People API call is executed server-side
- Ensure backend calls People API using `accessToken`.
- Typical endpoint example:
  - `GET https://people.googleapis.com/v1/people/me?personFields=birthdays,phoneNumbers`
- Include header:
  - `Authorization: Bearer <accessToken>`

6. Validate People API response parsing
- `birthdays` may exist in different forms:
  - full date (`year/month/day`)
  - partial date (`month/day`)
- `phoneNumbers` can contain multiple entries; choose primary first.
- If no values, store `null` and return explicit reason in debug logs.

7. Ensure backend returns merged user fields
- Final response should include:
  - `avatar`
  - `phone`
  - `birthday`
- Confirm response shape:
```json
{
  "success": true,
  "token": "...",
  "user": {
    "avatar": "...",
    "phone": "...",
    "birthday": "YYYY-MM-DD or MM-DD or null"
  }
}
```

8. Confirm `/user/get` consistency
- After Google login, `/user/get` should also return stored `phone` and `birthday`.
- If `/user/get` omits these fields, frontend can appear unchanged later.

## Minimal Backend Debug Logs to Add

Inside `POST /user/googleLogin`, log:

1. `hasIdToken`, `hasAccessToken`
2. Google token verification result (email, verified)
3. People API request status code
4. People API raw `birthdays` / `phoneNumbers` presence (not full sensitive payload)
5. Final DB values saved for `avatar`, `phone`, `birthday`
6. Final response `user` keys

## Fast Failure Map

- `avatar set`, `phone null`, `birthday null`:
  - Access token missing or People scopes not granted.
- `People API 403`:
  - API not enabled or scope not granted.
- `People API 401`:
  - Invalid/expired access token.
- `/user/googleLogin` has values but `/user/get` does not:
  - DB save or `/user/get` serializer issue.

## Backend Return Recommendation (Temporary for Debug)

Until fixed, include a non-production debug block:
```json
{
  "debug": {
    "hasAccessToken": true,
    "peopleApiStatus": 200,
    "birthdayFound": true,
    "phoneFound": false
  }
}
```

Remove debug fields in production.
