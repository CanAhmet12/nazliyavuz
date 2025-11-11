# API Integration Guide

## Getting Started

### 1. Authentication

First, register a new user or login with existing credentials:

```bash
# Register
curl -X POST https://api.nazliyavuz.com/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "password": "password123",
    "password_confirmation": "password123",
    "role": "student"
  }'

# Login
curl -X POST https://api.nazliyavuz.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "password123"
  }'
```

### 2. Using the Token

Include the JWT token in all authenticated requests:

```bash
curl -X GET https://api.nazliyavuz.com/teachers \
  -H "Authorization: Bearer your-jwt-token-here"
```

## Common Patterns

### Pagination

Most list endpoints support pagination:

```bash
GET /teachers?page=1&per_page=20
```

Response includes pagination metadata:

```json
{
  "data": [...],
  "meta": {
    "current_page": 1,
    "last_page": 10,
    "per_page": 20,
    "total": 200
  }
}
```

### Error Handling

Always check for errors in responses:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The given data was invalid",
    "details": {
      "email": ["The email field is required"]
    }
  }
}
```

## SDK Examples

### JavaScript/Node.js

```javascript
const axios = require('axios');

const api = axios.create({
  baseURL: 'https://api.nazliyavuz.com',
  headers: {
    'Content-Type': 'application/json'
  }
});

// Add token to requests
api.interceptors.request.use(config => {
  const token = localStorage.getItem('jwt_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Login
const login = async (email, password) => {
  const response = await api.post('/auth/login', { email, password });
  localStorage.setItem('jwt_token', response.data.token);
  return response.data;
};

// Get teachers
const getTeachers = async (filters = {}) => {
  const response = await api.get('/teachers', { params: filters });
  return response.data;
};
```

### PHP

```php
<?php

class NazliyavuzAPI {
    private $baseUrl = 'https://api.nazliyavuz.com';
    private $token;
    
    public function login($email, $password) {
        $response = $this->request('POST', '/auth/login', [
            'email' => $email,
            'password' => $password
        ]);
        
        $this->token = $response['token'];
        return $response;
    }
    
    public function getTeachers($filters = []) {
        return $this->request('GET', '/teachers', $filters);
    }
    
    private function request($method, $endpoint, $data = []) {
        $ch = curl_init();
        
        curl_setopt_array($ch, [
            CURLOPT_URL => $this->baseUrl . $endpoint,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                $this->token ? "Authorization: Bearer {$this->token}" : ''
            ]
        ]);
        
        if ($data) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }
        
        $response = curl_exec($ch);
        curl_close($ch);
        
        return json_decode($response, true);
    }
}
```

## Rate Limiting

- **Authenticated users**: 1000 requests/hour
- **Unauthenticated users**: 100 requests/hour

Rate limit headers are included in responses:

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1640995200
```

## Webhooks

The API supports webhooks for real-time notifications:

### Available Events

- `reservation.created`
- `reservation.updated`
- `message.sent`
- `rating.created`

### Webhook Payload

```json
{
  "event": "reservation.created",
  "data": {
    "id": 123,
    "student_id": 456,
    "teacher_id": 789,
    "status": "pending"
  },
  "timestamp": "2023-01-01T00:00:00Z"
}
```

## Notifications & Messaging

### Register Device Token

```bash
curl -X POST https://api.nazliyavuz.com/notifications/register-token \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "token": "fcm-device-token",
    "platform": "ios",
    "capabilities": ["push", "in_app"]
  }'
```

### Send Immediate Notification (Admin)

```bash
curl -X POST https://api.nazliyavuz.com/admin/notifications/send \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "channels": ["push", "email"],
    "segment": "active_students",
    "title": "Yeni Ödeme Duyurusu",
    "message": "Bugün saat 20:00’ye kadar ödeme yapanlara %10 indirim!"
  }'
```

### Schedule a Notification

```bash
curl -X POST https://api.nazliyavuz.com/admin/notifications/scheduled \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Haftalık Hatırlatma",
    "channels": ["push"],
    "payload": {
      "title": "Ders Hatırlatması",
      "message": "Yarın saat 18:00’de dersiniz var."
    },
    "schedule": {
      "cron": "0 12 * * 1",
      "timezone": "Europe/Istanbul"
    }
  }'
```

### Render & Test a Template

```bash
curl -X POST https://api.nazliyavuz.com/admin/notification-templates/{template_id}/render \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "variables": {
      "student_name": "Ece",
      "lesson_date": "2025-11-12 18:00"
    }
  }'
```

```bash
curl -X POST https://api.nazliyavuz.com/admin/notification-templates/{template_id}/test-send \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "recipient": "ece@example.com",
    "channels": ["email"]
  }'
```

> **Not:** Bildirimler kuyruğa alınır. Production ortamında `QUEUE_CONNECTION=database` gibi asenkron bir sürücü kullanın ve `queue:work --queue=notifications,default` işçisinin çalıştığından emin olun.

## Support

For API support and questions:
- Email: api-support@nazliyavuz.com
- Documentation: https://docs.nazliyavuz.com
- Status Page: https://status.nazliyavuz.com