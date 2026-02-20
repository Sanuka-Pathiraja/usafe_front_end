# Backend Integration Guide - USafe

## 📋 Overview

Your frontend is now properly configured to send JWT authentication tokens to your backend. Here's what needs to be implemented on the **backend side**.

---

## 🔐 Authentication Flow

### Current Frontend Behavior:

1. User logs in through the app
2. Frontend expects backend to return a JWT token
3. Frontend stores token locally
4. Frontend sends token in `Authorization: Bearer <token>` header for protected endpoints

---

## 🛠️ Backend Changes Required

### 1. **Login Endpoint** (Already exists, verify this)

**Endpoint:** `POST /login`

**Expected Request:**

```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Expected Response (200 OK):**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "user_123",
    "email": "user@example.com",
    "name": "Sanuka Pathiraja"
  }
}
```

**Important:** Backend MUST return a `token` field. The frontend will store this.

---

### 2. **Guardian Safety Score Endpoint**

**Endpoint:** `GET /api/guardian/safety-score?lat={lat}&lng={lng}`

**Authentication:** Optional (can work with or without token)

**Headers the frontend sends:**

```
Authorization: Bearer <jwt_token>
```

**Expected Response (200 OK):**

```json
{
  "score": 85
}
```

**Backend Changes:**

- If token is present, verify it (optional, but recommended for per-user analytics)
- Return safety score calculated from lat/lng
- If token is missing, still return score (public endpoint)

---

### 3. **Guardian Route Save Endpoint** ⚠️ **REQUIRES AUTH**

**Endpoint:** `POST /api/guardian/routes`

**Authentication:** **REQUIRED** (401 if missing/invalid token)

**Headers the frontend sends:**

```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**

```json
{
  "route_name": "Sarah to School",
  "name": "Sarah to School",
  "is_active": true,
  "checkpoints": [
    {
      "name": "Checkpoint 1",
      "lat": 6.9271,
      "lng": 79.8612,
      "safety_score": 85
    },
    {
      "name": "Checkpoint 2",
      "lat": 6.9301,
      "lng": 79.8642,
      "safety_score": 72
    }
  ]
}
```

**Expected Response (200 or 201):**

```json
{
  "route_id": "route_abc123",
  "message": "Route saved successfully"
}
```

**Backend Changes:**

1. **Verify JWT token** - Extract user ID from token
2. **Save route** to database with user association
3. **Return route_id** (used for alerts later)
4. **Return 401** if token is missing or invalid

**Python (Flask) Example:**

```python
from flask import request, jsonify
from functools import wraps
import jwt

SECRET_KEY = "your_secret_key"

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'error': 'Token is missing'}), 401
        try:
            token = token.replace('Bearer ', '')
            payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
            current_user_id = payload['user_id']
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        return f(current_user_id, *args, **kwargs)
    return decorated

@app.route('/api/guardian/routes', methods=['POST'])
@token_required
def save_guardian_route(current_user_id):
    data = request.json
    route_name = data.get('route_name')
    checkpoints = data.get('checkpoints')

    # Save to database
    route_id = db.save_route(current_user_id, route_name, checkpoints)

    return jsonify({'route_id': route_id}), 201
```

**Node.js (Express) Example:**

```javascript
const jwt = require("jsonwebtoken");

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1]; // Bearer TOKEN

  if (!token) {
    return res.status(401).json({ error: "Token is missing" });
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(401).json({ error: "Invalid or expired token" });
    }
    req.user = user;
    next();
  });
};

app.post("/api/guardian/routes", authenticateToken, (req, res) => {
  const userId = req.user.id;
  const { route_name, checkpoints } = req.body;

  // Save to database
  const routeId = db.saveRoute(userId, route_name, checkpoints);

  res.status(201).json({ route_id: routeId });
});
```

---

### 4. **Guardian Alert Endpoint** ⚠️ **REQUIRES AUTH**

**Endpoint:** `POST /api/guardian/alert`

**Authentication:** **REQUIRED**

**Headers:**

```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**

```json
{
  "route_id": "route_abc123",
  "checkpoint_index": 0,
  "lat": 6.9271,
  "lng": 79.8612
}
```

**Expected Response (200 or 201):**

```json
{
  "message": "Alert sent successfully"
}
```

**Backend Changes:**

1. **Verify JWT token**
2. **Look up route** by route_id
3. **Send notification** to parent/guardian (push notification, SMS, email, etc.)
4. **Log alert** in database
5. **Return 401** if no auth

---

### 5. **Incident Report Endpoint** ⚠️ **REQUIRES AUTH**

**Endpoint:** `POST /api/incidents/report`

**Authentication:** **REQUIRED**

**Headers:**

```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**

```json
{
  "incident_type": "harassment",
  "description": "Suspicious person following me near the park",
  "lat": 6.9271,
  "lng": 79.8612,
  "is_anonymous": false,
  "timestamp": "2026-02-20T14:30:00.000Z"
}
```

**Expected Response (200 or 201):**

```json
{
  "report_id": "incident_xyz789",
  "message": "Incident reported successfully"
}
```

**Backend Changes:**

1. **Verify JWT token** (optional: allow anonymous if `is_anonymous: true`)
2. **Save incident** to database
3. **Notify authorities** if severe
4. **Return confirmation**

---

## 🔧 Quick Start Implementation Checklist

### Backend Checklist:

- [ ] **Verify `/login` returns `token` field**
- [ ] **Add JWT verification middleware** (see examples above)
- [ ] **Protect `/api/guardian/routes` endpoint** with auth
- [ ] **Protect `/api/guardian/alert` endpoint** with auth
- [ ] **Protect `/api/incidents/report` endpoint** with auth
- [ ] **Return proper 401 responses** for missing/invalid tokens
- [ ] **Test with Postman** using the request/response formats above

---

## 🧪 Testing Your Backend

### 1. **Test Login:**

```bash
curl -X POST http://localhost:5000/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'
```

**Expected:** `{"token": "eyJ..."}`

---

### 2. **Test Guardian Route Save (with token):**

```bash
curl -X POST http://localhost:5000/api/guardian/routes \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "route_name": "Test Route",
    "checkpoints": [
      {"name": "Point 1", "lat": 6.9271, "lng": 79.8612, "safety_score": 85}
    ]
  }'
```

**Expected:** `{"route_id": "route_123"}`

---

### 3. **Test Guardian Route Save (without token):**

```bash
curl -X POST http://localhost:5000/api/guardian/routes \
  -H "Content-Type: application/json" \
  -d '{"route_name": "Test Route"}'
```

**Expected:** `401 Unauthorized` with `{"error": "Token is missing"}`

---

## 🚨 Common Issues & Solutions

### Issue 1: Frontend gets 401 even after login

**Cause:** Backend not returning `token` in login response  
**Fix:** Ensure `/login` returns `{"token": "..."}`

### Issue 2: Token verification fails

**Cause:** Secret key mismatch or expired tokens  
**Fix:** Use same secret key for encoding/decoding JWT

### Issue 3: Frontend doesn't send token

**Cause:** Token not stored after login  
**Fix:** Verify frontend login flow saves token (this is now fixed in the frontend)

---

## ✅ Frontend Changes Already Done

✅ JWT token storage after login  
✅ Token retrieval from storage  
✅ Token sent in `Authorization` header for all protected endpoints  
✅ Proper error handling for 401 responses

---

## 🎯 Summary

**What YOU need to do in the backend:**

1. **Make sure `/login` returns a JWT token**
2. **Add authentication middleware** (see Python/Node examples above)
3. **Protect these endpoints:**
   - `POST /api/guardian/routes` → return 401 if no token
   - `POST /api/guardian/alert` → return 401 if no token
   - `POST /api/incidents/report` → return 401 if no token
4. **Test with curl/Postman** to verify 401 errors work correctly

**The frontend will now:**

- Store the token after login
- Send it with every protected request
- Handle 401 errors gracefully

---

**Need help?** Check the code examples above or test your endpoints with Postman first!
