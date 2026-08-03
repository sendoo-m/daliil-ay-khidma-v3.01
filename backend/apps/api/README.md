# Daliil Ay Khidma - REST API

## 🎯 Overview

Comprehensive REST API for the Daliil Ay Khidma platform with JWT authentication.

## 🔑 Authentication

### JWT Authentication

The API uses JWT (JSON Web Tokens) for authentication.

#### Register New User
```bash
curl -X POST http://localhost:8008/api/v1/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "SecurePass123!",
    "password_confirm": "SecurePass123!"
  }'
```

#### Login
```bash
curl -X POST http://localhost:8008/api/v1/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "SecurePass123!"
  }'
```

Response:
```json
{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "user": {
    "id": 1,
    "username": "testuser",
    "email": "test@example.com"
  }
}
```

#### Use Token
```bash
curl http://localhost:8008/api/v1/businesses/ \
  -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc..."
```

## 📱 API Endpoints

### Authentication
```
POST   /api/v1/auth/login/
POST   /api/v1/auth/refresh/
POST   /api/v1/auth/register/
GET    /api/v1/auth/profile/
PUT    /api/v1/auth/profile/update/
POST   /api/v1/auth/change-password/
```

### Categories
```
GET    /api/v1/categories/
GET    /api/v1/categories/{id}/
```

### Businesses
```
GET    /api/v1/businesses/
POST   /api/v1/businesses/          # Auth required
GET    /api/v1/businesses/{id}/
PUT    /api/v1/businesses/{id}/     # Owner only
DELETE /api/v1/businesses/{id}/     # Owner only
```

### Products
```
GET    /api/v1/products/
POST   /api/v1/products/             # Auth required
GET    /api/v1/products/{id}/
PUT    /api/v1/products/{id}/        # Owner only
DELETE /api/v1/products/{id}/        # Owner only
```

### Deals
```
GET    /api/v1/deals/
POST   /api/v1/deals/                # Auth required
GET    /api/v1/deals/{id}/
PUT    /api/v1/deals/{id}/           # Owner only
DELETE /api/v1/deals/{id}/           # Owner only
POST   /api/v1/deals/{id}/use/       # Auth required
```

### Favorites
```
GET    /api/v1/favorites/            # Auth required
POST   /api/v1/favorites/            # Auth required
DELETE /api/v1/favorites/{id}/       # Auth required
```

### Subscriptions
```
GET    /api/v1/subscription-plans/
GET    /api/v1/subscriptions/        # Auth required
POST   /api/v1/subscriptions/        # Auth required
```

### Locations
```
GET    /api/v1/governorates/
GET    /api/v1/cities/
GET    /api/v1/districts/
```

## 🔍 Filtering & Search

### Search Businesses
```bash
curl "http://localhost:8008/api/v1/businesses/?search=restaurant"
```

### Filter by Category
```bash
curl "http://localhost:8008/api/v1/businesses/?category=1"
```

### Filter by City
```bash
curl "http://localhost:8008/api/v1/businesses/?city=الرياض"
```

### Combined Filters
```bash
curl "http://localhost:8008/api/v1/businesses/?category=1&city=الرياض&is_verified=true"
```

## 📄 Pagination

All list endpoints support pagination:

```bash
curl "http://localhost:8008/api/v1/businesses/?page=1&page_size=20"
```

Response:
```json
{
  "count": 150,
  "next": "http://localhost:8008/api/v1/businesses/?page=2",
  "previous": null,
  "results": [...]
}
```

## 📚 API Documentation

### Swagger UI (Interactive)
```
http://localhost:8008/api/v1/docs/
```

### ReDoc (Clean)
```
http://localhost:8008/api/v1/redoc/
```

### OpenAPI Schema
```
http://localhost:8008/api/v1/schema/
```

## 🛠️ Setup

### Install Dependencies
```bash
pip install -r requirements.txt
```

### Run Server
```bash
python manage.py runserver 0.0.0.0:8008
```

### Test API
```bash
# Get all categories
curl http://localhost:8008/api/v1/categories/

# Register user
curl -X POST http://localhost:8008/api/v1/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@test.com","password":"Test123!","password_confirm":"Test123!"}'
```

## 📱 Mobile App Integration

### Flutter Example
```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String baseUrl = 'http://your-domain.com/api/v1';
  String? accessToken;
  
  Future<void> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      accessToken = data['access'];
    }
  }
  
  Future<List<dynamic>> getBusinesses() async {
    final response = await http.get(
      Uri.parse('$baseUrl/businesses/'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['results'];
    }
    return [];
  }
}
```

### React Native Example
```javascript
import axios from 'axios';

const API_URL = 'http://your-domain.com/api/v1';
let accessToken = null;

const api = axios.create({
  baseURL: API_URL,
  headers: {'Content-Type': 'application/json'},
});

// Add token to requests
api.interceptors.request.use((config) => {
  if (accessToken) {
    config.headers.Authorization = `Bearer ${accessToken}`;
  }
  return config;
});

export const login = async (username, password) => {
  const response = await api.post('/auth/login/', {username, password});
  accessToken = response.data.access;
  return response.data;
};

export const getBusinesses = async () => {
  const response = await api.get('/businesses/');
  return response.data.results;
};
```

## ⚠️ Error Handling

### Error Response Format
```json
{
  "error": "Error message",
  "detail": "Additional details"
}
```

### HTTP Status Codes
- `200 OK` - Success
- `201 Created` - Resource created
- `400 Bad Request` - Invalid data
- `401 Unauthorized` - Authentication required
- `403 Forbidden` - Permission denied
- `404 Not Found` - Resource not found
- `500 Internal Server Error` - Server error

## 📝 Notes

1. All dates in ISO 8601 format: `YYYY-MM-DD`
2. All datetimes in ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`
3. Image uploads use multipart/form-data
4. Max file size: 5MB
5. Supported formats: JPG, PNG, WebP
6. JWT access token expires in 15 minutes
7. JWT refresh token expires in 7 days

## 🔗 Useful Links

- **API Root:** http://localhost:8008/api/v1/
- **API Docs:** http://localhost:8008/api/v1/docs/
- **Admin Panel:** http://localhost:8008/admin/
- **Dashboard:** http://localhost:8008/dashboard/

---

**Version:** 1.0 (Enhanced with JWT)  
**Last Updated:** February 2026
