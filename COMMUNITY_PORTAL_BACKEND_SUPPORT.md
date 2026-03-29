# Community Portal Backend Support

## What the frontend now supports

- A new `Community Reports` portal from the Safety Score screen.
- Social-style feed cards that show username, avatar, report text, issue tags, images, likes, and comments UI.
- Embedded SafePath Guardian style map picker inside the portal composer.
- Users can choose location by current location, searching a place, or pinning on the map.
- Posting still uses the existing `POST /report/add` endpoint.
- The portal already pulls the logged-in user's own reports from `GET /report/my-reports`.

## Backend still needed for a full real social portal

### 1. Public community feed endpoint

Need an endpoint like `GET /report/feed`.

Suggested response fields per post:

- `reportId`
- `reportContent`
- `location`
- `locationCoordinates`
- `reportDate_time`
- `images_proofs`
- `issueTypes`
- `likeCount`
- `commentCount`
- `isLikedByCurrentUser`
- `user`
- `user.userId`
- `user.name`
- `user.avatarUrl`
- `user.username`

Suggested query params:

- `page`
- `limit`
- `lat`
- `lng`
- `radiusKm`
- `issueType`

### 2. Like / unlike endpoints

Need endpoints like:

- `POST /report/:reportId/like`
- `DELETE /report/:reportId/like`

Suggested response:

- `success`
- `likeCount`
- `isLikedByCurrentUser`

### 3. Comments endpoints

Need endpoints like:

- `GET /report/:reportId/comments`
- `POST /report/:reportId/comments`

Suggested comment fields:

- `commentId`
- `text`
- `createdAt`
- `user.userId`
- `user.name`
- `user.avatarUrl`

### 4. Better image URLs in report payloads

Frontend works best if `images_proofs` returns absolute URLs such as:

- `http://10.0.2.2:5000/uploads/reports/abc.jpg`

### 5. Public-safe user profile fields

For portal cards, backend should expose only public-safe fields:

- `name`
- `avatarUrl`
- optional `username`

### 6. Optional improvements

- pagination / infinite scrolling
- report delete permission in feed for owner only
- comment delete permission for owner/admin
- moderation status
- abuse/spam reporting
- nearby feed filtering
- real-time updates via socket or push refresh

## Current limitation

Right now the frontend can show sample community feed posts plus the logged-in user's real submitted posts.

To make the portal fully real for all uSafe users, the main missing backend pieces are:

- a public community feed API
- like APIs
- comment APIs
