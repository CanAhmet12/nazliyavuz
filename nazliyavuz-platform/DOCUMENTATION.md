# Nazliyavuz Platform - Complete Documentation

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [API Documentation](#api-documentation)
4. [Frontend Guide](#frontend-guide)
5. [Backend Guide](#backend-guide)
6. [Database Schema](#database-schema)
7. [Deployment Guide](#deployment-guide)
8. [User Manual](#user-manual)
9. [Developer Guide](#developer-guide)
10. [Troubleshooting](#troubleshooting)

## 🎯 Overview

Nazliyavuz Platform is a comprehensive education platform that connects students with qualified teachers for personalized learning experiences.

### Key Features
- **User Management**: Registration, authentication, profile management
- **Teacher System**: Teacher profiles, certifications, availability management
- **Search & Filtering**: AI-powered search with advanced filtering
- **Reservation System**: Booking system with calendar integration
- **Rating & Review**: Comprehensive rating system with detailed feedback
- **Notification System**: Email and push notifications
- **File Upload**: Secure file upload with S3 integration
- **Security**: JWT authentication, rate limiting, input validation
- **Analytics**: Advanced analytics and reporting
- **Performance**: Redis caching, database optimization
- **Mobile App**: Flutter-based mobile application
- **DevOps**: Docker, CI/CD, monitoring

## 🏗️ Architecture

### System Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │     Backend     │    │    Database     │
│   (Flutter)     │◄──►│   (Laravel 11)  │◄──►│  (PostgreSQL)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Mobile App    │    │   Redis Cache   │    │   File Storage  │
│   (iOS/Android) │    │   (Caching)     │    │   (AWS S3)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Technology Stack
- **Backend**: Laravel 11, PHP 8.2, PostgreSQL, Redis
- **Frontend**: Flutter 3, Dart 3.0
- **Mobile**: iOS, Android
- **Database**: PostgreSQL 15
- **Cache**: Redis 7
- **File Storage**: AWS S3
- **Containerization**: Docker, Docker Compose
- **CI/CD**: GitHub Actions
- **Monitoring**: Prometheus, Grafana

## 📡 API Documentation

### Authentication Endpoints

#### POST /api/auth/register
Register a new user.

**Request Body:**
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "password123",
  "role": "student"
}
```

**Response:**
```json
{
  "message": "User registered successfully",
  "user": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "role": "student"
  },
  "token": "jwt_token_here"
}
```

#### POST /api/auth/login
Login user.

**Request Body:**
```json
{
  "email": "john@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "message": "Login successful",
  "user": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "role": "student"
  },
  "token": "jwt_token_here"
}
```

### Teacher Endpoints

#### GET /api/teachers
Get list of teachers with filtering.

**Query Parameters:**
- `category`: Filter by category slug
- `price_min`: Minimum price per hour
- `price_max`: Maximum price per hour
- `rating_min`: Minimum rating
- `online_only`: Show only online teachers
- `search`: Search query
- `sort`: Sort by (rating, price, name)
- `page`: Page number
- `per_page`: Items per page

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "user": {
        "name": "Jane Smith",
        "profile_photo_url": "https://example.com/photo.jpg"
      },
      "bio": "Experienced teacher...",
      "price_hour": 50.00,
      "rating_avg": 4.8,
      "rating_count": 25,
      "online_available": true,
      "categories": [
        {
          "id": 1,
          "name": "Mathematics",
          "slug": "mathematics"
        }
      ]
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 10,
    "per_page": 15,
    "total": 150
  }
}
```

#### GET /api/teachers/{id}
Get teacher details.

**Response:**
```json
{
  "id": 1,
  "user": {
    "name": "Jane Smith",
    "profile_photo_url": "https://example.com/photo.jpg"
  },
  "bio": "Experienced teacher...",
  "education": [
    {
      "degree": "Bachelor of Mathematics",
      "institution": "University of Example",
      "year": 2015
    }
  ],
  "certifications": [
    {
      "name": "Teaching Certificate",
      "institution": "Ministry of Education",
      "year": 2016
    }
  ],
  "price_hour": 50.00,
  "rating_avg": 4.8,
  "rating_count": 25,
  "online_available": true,
  "categories": [...],
  "recent_reservations": [...]
}
```

### Reservation Endpoints

#### POST /api/reservations
Create a new reservation.

**Request Body:**
```json
{
  "teacher_id": 1,
  "date": "2024-01-15",
  "time": "14:00",
  "type": "online",
  "notes": "Need help with calculus"
}
```

**Response:**
```json
{
  "message": "Reservation created successfully",
  "reservation": {
    "id": 1,
    "teacher_id": 1,
    "student_id": 2,
    "date": "2024-01-15",
    "time": "14:00",
    "type": "online",
    "status": "pending",
    "price": 50.00,
    "notes": "Need help with calculus"
  }
}
```

#### GET /api/reservations
Get user's reservations.

**Query Parameters:**
- `status`: Filter by status (pending, confirmed, completed, cancelled)
- `type`: Filter by type (online, offline)
- `page`: Page number
- `per_page`: Items per page

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "teacher": {
        "id": 1,
        "user": {
          "name": "Jane Smith"
        }
      },
      "date": "2024-01-15",
      "time": "14:00",
      "type": "online",
      "status": "confirmed",
      "price": 50.00
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 5,
    "per_page": 10,
    "total": 50
  }
}
```

### Rating Endpoints

#### POST /api/ratings
Create a rating for a teacher.

**Request Body:**
```json
{
  "teacher_id": 1,
  "reservation_id": 1,
  "rating": 5,
  "comment": "Excellent teacher!",
  "detailed_ratings": {
    "communication": 5,
    "knowledge": 5,
    "punctuality": 4,
    "teaching_method": 5,
    "patience": 5
  }
}
```

**Response:**
```json
{
  "message": "Rating created successfully",
  "rating": {
    "id": 1,
    "teacher_id": 1,
    "student_id": 2,
    "reservation_id": 1,
    "rating": 5,
    "comment": "Excellent teacher!",
    "detailed_ratings": {
      "communication": 5,
      "knowledge": 5,
      "punctuality": 4,
      "teaching_method": 5,
      "patience": 5
    },
    "created_at": "2024-01-15T10:00:00Z"
  }
}
```

## 🎨 Frontend Guide

### Project Structure
```
frontend/nazliyavuz_app/
├── lib/
│   ├── screens/          # UI screens
│   ├── widgets/          # Reusable widgets
│   ├── services/         # API services
│   ├── models/          # Data models
│   ├── utils/           # Utility functions
│   └── main.dart        # App entry point
├── assets/              # Images, fonts, etc.
├── test/                # Unit tests
└── pubspec.yaml         # Dependencies
```

### Key Screens
- **HomeScreen**: Main dashboard
- **SearchScreen**: Teacher search and filtering
- **TeacherProfileScreen**: Teacher details
- **ReservationScreen**: Booking interface
- **ProfileScreen**: User profile management
- **SettingsScreen**: App settings
- **AdminScreen**: Admin panel

### State Management
The app uses BLoC pattern for state management:
- **AuthBloc**: Authentication state
- **TeacherBloc**: Teacher data management
- **ReservationBloc**: Reservation management
- **SearchBloc**: Search functionality

### API Integration
All API calls are handled through `ApiService`:
```dart
class ApiService {
  static const String baseUrl = 'https://api.nazliyavuz.com';
  
  Future<Map<String, dynamic>> get(String endpoint) async {
    // Implementation
  }
  
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    // Implementation
  }
}
```

## 🔧 Backend Guide

### Project Structure
```
backend/
├── app/
│   ├── Http/
│   │   ├── Controllers/  # API controllers
│   │   ├── Middleware/   # Custom middleware
│   │   └── Requests/     # Form request validation
│   ├── Models/          # Eloquent models
│   ├── Services/         # Business logic services
│   ├── Jobs/            # Background jobs
│   └── Console/         # Artisan commands
├── database/
│   ├── migrations/      # Database migrations
│   ├── seeders/         # Database seeders
│   └── factories/       # Model factories
├── routes/              # Route definitions
├── config/              # Configuration files
└── tests/               # Test files
```

### Key Controllers
- **AuthController**: Authentication logic
- **TeacherController**: Teacher management
- **ReservationController**: Reservation handling
- **RatingController**: Rating system
- **AdminController**: Admin panel
- **SearchController**: Search functionality

### Services
- **MailService**: Email notifications
- **PushNotificationService**: Push notifications
- **CacheService**: Caching logic
- **FileUploadService**: File handling
- **ValidationService**: Input validation
- **MonitoringService**: System monitoring

### Middleware
- **AuthMiddleware**: JWT authentication
- **RoleMiddleware**: Role-based access control
- **RateLimitMiddleware**: API rate limiting
- **CacheResponseMiddleware**: Response caching
- **SecurityHeadersMiddleware**: Security headers

## 🗄️ Database Schema

### Core Tables
- **users**: User accounts
- **teachers**: Teacher profiles
- **categories**: Subject categories
- **reservations**: Booking records
- **ratings**: Teacher ratings
- **notifications**: System notifications
- **audit_logs**: System audit trail

### Relationships
- User hasMany Teachers
- Teacher belongsTo User
- Teacher belongsToMany Categories
- Reservation belongsTo Teacher and Student
- Rating belongsTo Teacher and Student

### Indexes
Performance indexes on frequently queried columns:
- users.email
- teachers.rating_avg
- reservations.status
- ratings.teacher_id

## 🚀 Deployment Guide

### Prerequisites
- Docker and Docker Compose
- AWS S3 bucket
- PostgreSQL database
- Redis server
- Domain name with SSL certificate

### Environment Setup
1. Copy `.env.example` to `.env`
2. Configure database credentials
3. Set AWS S3 credentials
4. Configure email settings
5. Set JWT secret key

### Docker Deployment
```bash
# Build and start containers
docker-compose up -d

# Run migrations
docker-compose exec backend php artisan migrate

# Seed database
docker-compose exec backend php artisan db:seed

# Generate API documentation
docker-compose exec backend php artisan api:docs
```

### Production Checklist
- [ ] SSL certificate installed
- [ ] Environment variables configured
- [ ] Database migrations run
- [ ] Cache cleared
- [ ] File permissions set
- [ ] Monitoring configured
- [ ] Backup strategy implemented

## 👥 User Manual

### For Students
1. **Registration**: Create account with email
2. **Profile Setup**: Complete profile information
3. **Search Teachers**: Use filters to find teachers
4. **Book Lessons**: Make reservations
5. **Rate Teachers**: Leave feedback after lessons

### For Teachers
1. **Teacher Profile**: Create detailed profile
2. **Set Availability**: Manage schedule
3. **Upload Documents**: Add certifications
4. **Manage Reservations**: Accept/decline bookings
5. **Track Performance**: View analytics

### For Administrators
1. **Dashboard**: View platform statistics
2. **User Management**: Manage users and teachers
3. **Content Management**: Manage categories and content
4. **Analytics**: View detailed reports
5. **System Monitoring**: Monitor platform health

## 👨‍💻 Developer Guide

### Getting Started
1. Clone repository
2. Install dependencies
3. Setup database
4. Run migrations
5. Start development server

### Code Standards
- Follow PSR-12 for PHP
- Use Dart style guide for Flutter
- Write comprehensive tests
- Document all public methods
- Use meaningful commit messages

### Testing
```bash
# Backend tests
php artisan test

# Frontend tests
flutter test

# Integration tests
php artisan test --testsuite=Feature
```

### Contributing
1. Fork repository
2. Create feature branch
3. Make changes
4. Write tests
5. Submit pull request

## 🔧 Troubleshooting

### Common Issues

#### Backend Issues
- **Database Connection**: Check credentials and network
- **JWT Token**: Verify secret key configuration
- **File Upload**: Check S3 credentials and permissions
- **Email**: Verify SMTP settings

#### Frontend Issues
- **API Calls**: Check base URL and authentication
- **State Management**: Verify BLoC implementation
- **UI Rendering**: Check widget tree and constraints
- **Performance**: Profile app and optimize

#### Deployment Issues
- **Container Startup**: Check logs and dependencies
- **Database Migration**: Verify connection and permissions
- **File Permissions**: Set correct ownership
- **SSL Certificate**: Verify domain and certificate

### Support
- Check documentation first
- Search existing issues
- Create detailed bug report
- Include logs and steps to reproduce

---

## 📞 Contact & Support

- **Email**: support@nazliyavuz.com
- **Documentation**: https://docs.nazliyavuz.com
- **API Reference**: https://api.nazliyavuz.com/docs
- **GitHub**: https://github.com/nazliyavuz/platform

---

*Last updated: January 2024*
*Version: 1.0.0*
