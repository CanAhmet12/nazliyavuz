<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Route;
use ReflectionClass;
use ReflectionMethod;

class GenerateApiDocs extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'app:generate-api-docs 
                            {--format=json : Output format (json|yaml)}
                            {--output=docs : Output directory}
                            {--include-routes : Include all routes in documentation}
                            {--exclude-patterns=* : Comma-separated patterns to exclude}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Generate comprehensive API documentation from OpenAPI annotations';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $this->info('🚀 Generating API Documentation...');

        $format = $this->option('format');
        $outputDir = $this->option('output');
        
        // Validate format
        if (!in_array($format, ['json', 'yaml'])) {
            $this->error('Invalid format. Use json or yaml.');
            return Command::FAILURE;
        }

        // Generate OpenAPI specification
        $this->info('📝 Generating OpenAPI specification...');
        $openApiSpec = $this->generateOpenApiSpec();
        
        // Save to file
        $filename = 'api-docs.' . $format;
        $filepath = base_path($outputDir . '/' . $filename);
        
        // Ensure output directory exists
        if (!File::exists(base_path($outputDir))) {
            File::makeDirectory(base_path($outputDir), 0755, true);
            $this->info("📁 Created directory: {$outputDir}");
        }
        
        // Generate content based on format
        if ($format === 'yaml') {
            $content = $this->arrayToYaml($openApiSpec);
        } else {
            $content = json_encode($openApiSpec, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        }
        
        File::put($filepath, $content);
        
        $this->info("✅ API documentation generated successfully!");
        $this->info("📄 File saved to: {$filepath}");
        
        // Generate additional documentation files
        $this->generateEndpointSummary();
        $this->generateApiGuide();
        $this->generatePostmanCollection($openApiSpec);
        
        // Display statistics
        $this->displayStats($openApiSpec);
        
        return Command::SUCCESS;
    }

    /**
     * Generate OpenAPI specification
     */
    private function generateOpenApiSpec(): array
    {
        return [
            'openapi' => '3.0.3',
            'info' => [
                'title' => 'Nazliyavuz Education Platform API',
                'description' => $this->getApiDescription(),
                'version' => '1.0.0',
                'contact' => [
                    'name' => 'API Support',
                    'email' => 'support@nazliyavuz.com',
                    'url' => 'https://nazliyavuz.com/support',
                ],
                'license' => [
                    'name' => 'MIT',
                    'url' => 'https://opensource.org/licenses/MIT',
                ],
            ],
            'servers' => [
                [
                    'url' => config('app.url') . '/api',
                    'description' => 'Production server',
                ],
                [
                    'url' => 'http://localhost:8000/api',
                    'description' => 'Development server',
                ],
            ],
            'security' => [
                [
                    'bearerAuth' => [],
                ],
            ],
            'paths' => $this->generatePaths(),
            'components' => [
                'securitySchemes' => $this->generateSecuritySchemes(),
                'schemas' => $this->generateSchemas(),
                'responses' => $this->generateCommonResponses(),
                'parameters' => $this->generateCommonParameters(),
            ],
            'tags' => $this->generateTags(),
            'externalDocs' => [
                'description' => 'Find more info here',
                'url' => 'https://nazliyavuz.com/docs',
            ],
        ];
    }

    /**
     * Get API description
     */
    private function getApiDescription(): string
    {
        return <<<'DESC'
# Nazliyavuz Education Platform API

A comprehensive REST API for the Nazliyavuz education platform that connects students with qualified teachers.

## Features

- **User Management**: Registration, authentication, profile management
- **Teacher Profiles**: Detailed teacher profiles with ratings and reviews
- **Reservation System**: Book lessons with teachers
- **Search & Discovery**: Advanced search with filters and AI-powered recommendations
- **Real-time Chat**: Instant messaging between students and teachers
- **Payment Integration**: Secure payment processing
- **Admin Panel**: Comprehensive admin tools and analytics

## Authentication

This API uses JWT (JSON Web Tokens) for authentication. Include the token in the Authorization header:

```
Authorization: Bearer your-jwt-token-here
```

## Rate Limiting

API requests are rate limited to ensure fair usage:
- **Authenticated users**: 1000 requests per hour
- **Unauthenticated users**: 100 requests per hour

## Error Handling

All errors follow a consistent format:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable error message",
    "details": "Additional error details (optional)"
  }
}
```
DESC;
    }

    /**
     * Generate API paths
     */
    private function generatePaths(): array
    {
        $paths = [];

        // Authentication endpoints
        $paths['/auth/register'] = [
            'post' => [
                'tags' => ['Authentication'],
                'summary' => 'Register new user',
                'description' => 'Create a new user account with email verification',
                'requestBody' => [
                    'required' => true,
                    'content' => [
                        'application/json' => [
                            'schema' => ['$ref' => '#/components/schemas/RegisterRequest'],
                        ],
                    ],
                ],
                'responses' => [
                    '201' => [
                        'description' => 'User registered successfully',
                        'content' => [
                            'application/json' => [
                                'schema' => ['$ref' => '#/components/schemas/AuthResponse'],
                            ],
                        ],
                    ],
                    '422' => ['$ref' => '#/components/responses/ValidationError'],
                ],
            ],
        ];

        $paths['/auth/login'] = [
            'post' => [
                'tags' => ['Authentication'],
                'summary' => 'User login',
                'description' => 'Authenticate user and return JWT token',
                'requestBody' => [
                    'required' => true,
                    'content' => [
                        'application/json' => [
                            'schema' => ['$ref' => '#/components/schemas/LoginRequest'],
                        ],
                    ],
                ],
                'responses' => [
                    '200' => [
                        'description' => 'Login successful',
                        'content' => [
                            'application/json' => [
                                'schema' => ['$ref' => '#/components/schemas/AuthResponse'],
                            ],
                        ],
                    ],
                    '401' => ['$ref' => '#/components/responses/UnauthorizedError'],
                ],
            ],
        ];

        // Social Auth endpoints
        $paths['/auth/social/google'] = [
            'post' => [
                'tags' => ['Social Auth'],
                'summary' => 'Google OAuth login',
                'description' => 'Authenticate using Google OAuth token',
                'requestBody' => [
                    'required' => true,
                    'content' => [
                        'application/json' => [
                            'schema' => ['$ref' => '#/components/schemas/SocialAuthRequest'],
                        ],
                    ],
                ],
                'responses' => [
                    '200' => [
                        'description' => 'Social login successful',
                        'content' => [
                            'application/json' => [
                                'schema' => ['$ref' => '#/components/schemas/AuthResponse'],
                            ],
                        ],
                    ],
                ],
            ],
        ];

        // Teacher endpoints
        $paths['/teachers'] = [
            'get' => [
                'tags' => ['Teachers'],
                'summary' => 'Get teachers list',
                'description' => 'Retrieve paginated list of teachers with filters',
                'parameters' => [
                    ['$ref' => '#/components/parameters/PageParam'],
                    ['$ref' => '#/components/parameters/PerPageParam'],
                ],
                'responses' => [
                    '200' => [
                        'description' => 'Teachers retrieved successfully',
                        'content' => [
                            'application/json' => [
                                'schema' => ['$ref' => '#/components/schemas/TeacherListResponse'],
                            ],
                        ],
                    ],
                ],
            ],
        ];

        // Search endpoints
        $paths['/search'] = [
            'get' => [
                'tags' => ['Search'],
                'summary' => 'Search teachers',
                'description' => 'Advanced search for teachers with multiple filters',
                'parameters' => [
                    ['$ref' => '#/components/parameters/SearchQueryParam'],
                ],
                'responses' => [
                    '200' => [
                        'description' => 'Search results',
                        'content' => [
                            'application/json' => [
                                'schema' => ['$ref' => '#/components/schemas/SearchResponse'],
                            ],
                        ],
                    ],
                ],
            ],
        ];

        return $paths;
    }

    /**
     * Generate security schemes
     */
    private function generateSecuritySchemes(): array
    {
        return [
            'bearerAuth' => [
                'type' => 'http',
                'scheme' => 'bearer',
                'bearerFormat' => 'JWT',
                'description' => 'JWT token obtained from login endpoint',
            ],
            'apiKey' => [
                'type' => 'apiKey',
                'in' => 'header',
                'name' => 'X-API-Key',
                'description' => 'API key for external integrations',
            ],
        ];
    }

    /**
     * Generate schemas
     */
    private function generateSchemas(): array
    {
        return [
            'User' => [
                'type' => 'object',
                'properties' => [
                    'id' => ['type' => 'integer', 'example' => 1],
                    'name' => ['type' => 'string', 'example' => 'John Doe'],
                    'email' => ['type' => 'string', 'format' => 'email', 'example' => 'john@example.com'],
                    'role' => ['type' => 'string', 'enum' => ['student', 'teacher', 'admin'], 'example' => 'student'],
                    'profile_photo_url' => ['type' => 'string', 'nullable' => true],
                    'email_verified_at' => ['type' => 'string', 'format' => 'date-time', 'nullable' => true],
                    'created_at' => ['type' => 'string', 'format' => 'date-time'],
                    'updated_at' => ['type' => 'string', 'format' => 'date-time'],
                ],
            ],
            'Teacher' => [
                'type' => 'object',
                'allOf' => [
                    ['$ref' => '#/components/schemas/User'],
                    [
                        'type' => 'object',
                        'properties' => [
                            'bio' => ['type' => 'string'],
                            'education' => ['type' => 'string'],
                            'experience_years' => ['type' => 'integer'],
                            'price_hour' => ['type' => 'number', 'format' => 'float'],
                            'rating_avg' => ['type' => 'number', 'format' => 'float'],
                            'total_ratings' => ['type' => 'integer'],
                            'languages' => ['type' => 'array', 'items' => ['type' => 'string']],
                            'categories' => ['type' => 'array', 'items' => ['$ref' => '#/components/schemas/Category']],
                        ],
                    ],
                ],
            ],
            'RegisterRequest' => [
                'type' => 'object',
                'required' => ['name', 'email', 'password', 'password_confirmation', 'role'],
                'properties' => [
                    'name' => ['type' => 'string', 'maxLength' => 255, 'example' => 'John Doe'],
                    'email' => ['type' => 'string', 'format' => 'email', 'example' => 'john@example.com'],
                    'password' => ['type' => 'string', 'minLength' => 8, 'example' => 'password123'],
                    'password_confirmation' => ['type' => 'string', 'example' => 'password123'],
                    'role' => ['type' => 'string', 'enum' => ['student', 'teacher'], 'example' => 'student'],
                ],
            ],
            'LoginRequest' => [
                'type' => 'object',
                'required' => ['email', 'password'],
                'properties' => [
                    'email' => ['type' => 'string', 'format' => 'email', 'example' => 'john@example.com'],
                    'password' => ['type' => 'string', 'example' => 'password123'],
                ],
            ],
            'SocialAuthRequest' => [
                'type' => 'object',
                'required' => ['access_token'],
                'properties' => [
                    'access_token' => ['type' => 'string', 'example' => 'ya29.a0AfH6SMC...'],
                    'id_token' => ['type' => 'string', 'example' => 'eyJhbGciOiJSUzI1NiIs...'],
                ],
            ],
            'AuthResponse' => [
                'type' => 'object',
                'properties' => [
                    'message' => ['type' => 'string', 'example' => 'Login successful'],
                    'user' => ['$ref' => '#/components/schemas/User'],
                    'token' => ['type' => 'string', 'example' => 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...'],
                    'is_new_user' => ['type' => 'boolean', 'example' => false],
                ],
            ],
            'Category' => [
                'type' => 'object',
                'properties' => [
                    'id' => ['type' => 'integer'],
                    'name' => ['type' => 'string'],
                    'slug' => ['type' => 'string'],
                    'description' => ['type' => 'string'],
                    'icon' => ['type' => 'string'],
                ],
            ],
            'ErrorResponse' => [
                'type' => 'object',
                'properties' => [
                    'error' => [
                        'type' => 'object',
                        'properties' => [
                            'code' => ['type' => 'string', 'example' => 'VALIDATION_ERROR'],
                            'message' => ['type' => 'string', 'example' => 'The given data was invalid'],
                            'details' => ['type' => 'object', 'nullable' => true],
                        ],
                    ],
                ],
            ],
        ];
    }

    /**
     * Generate common responses
     */
    private function generateCommonResponses(): array
    {
        return [
            'ValidationError' => [
                'description' => 'Validation error',
                'content' => [
                    'application/json' => [
                        'schema' => ['$ref' => '#/components/schemas/ErrorResponse'],
                    ],
                ],
            ],
            'UnauthorizedError' => [
                'description' => 'Unauthorized',
                'content' => [
                    'application/json' => [
                        'schema' => ['$ref' => '#/components/schemas/ErrorResponse'],
                    ],
                ],
            ],
            'NotFoundError' => [
                'description' => 'Resource not found',
                'content' => [
                    'application/json' => [
                        'schema' => ['$ref' => '#/components/schemas/ErrorResponse'],
                    ],
                ],
            ],
        ];
    }

    /**
     * Generate common parameters
     */
    private function generateCommonParameters(): array
    {
        return [
            'PageParam' => [
                'name' => 'page',
                'in' => 'query',
                'description' => 'Page number',
                'required' => false,
                'schema' => ['type' => 'integer', 'minimum' => 1, 'default' => 1],
            ],
            'PerPageParam' => [
                'name' => 'per_page',
                'in' => 'query',
                'description' => 'Items per page',
                'required' => false,
                'schema' => ['type' => 'integer', 'minimum' => 1, 'maximum' => 100, 'default' => 20],
            ],
            'SearchQueryParam' => [
                'name' => 'query',
                'in' => 'query',
                'description' => 'Search query',
                'required' => false,
                'schema' => ['type' => 'string', 'maxLength' => 255],
            ],
        ];
    }

    /**
     * Generate tags
     */
    private function generateTags(): array
    {
        return [
            [
                'name' => 'Authentication',
                'description' => 'User authentication and authorization',
            ],
            [
                'name' => 'Social Auth',
                'description' => 'Social media authentication (Google, Facebook, Apple)',
            ],
            [
                'name' => 'Teachers',
                'description' => 'Teacher profiles and management',
            ],
            [
                'name' => 'Students',
                'description' => 'Student profiles and management',
            ],
            [
                'name' => 'Reservations',
                'description' => 'Reservation management',
            ],
            [
                'name' => 'Search',
                'description' => 'Search and discovery features',
            ],
            [
                'name' => 'Chat',
                'description' => 'Real-time messaging',
            ],
            [
                'name' => 'Admin',
                'description' => 'Admin panel operations',
            ],
            [
                'name' => 'Files',
                'description' => 'File upload and management',
            ],
        ];
    }

    /**
     * Convert array to YAML
     */
    private function arrayToYaml(array $data): string
    {
        // Simple YAML conversion (in production, use a proper YAML library)
        $yaml = "openapi: 3.0.3\n";
        $yaml .= "info:\n";
        $yaml .= "  title: " . $data['info']['title'] . "\n";
        $yaml .= "  version: " . $data['info']['version'] . "\n";
        $yaml .= "  description: |\n";
        $yaml .= "    " . str_replace("\n", "\n    ", $data['info']['description']) . "\n";
        
        return $yaml;
    }

    /**
     * Generate endpoint summary
     */
    private function generateEndpointSummary(): void
    {
        $endpoints = [
            'Authentication' => [
                'POST /auth/register' => 'Register new user',
                'POST /auth/login' => 'User login',
                'POST /auth/logout' => 'User logout',
                'POST /auth/refresh' => 'Refresh token',
                'POST /auth/forgot-password' => 'Request password reset',
                'POST /auth/reset-password' => 'Reset password',
            ],
            'Social Authentication' => [
                'POST /auth/social/google' => 'Google OAuth login',
                'POST /auth/social/facebook' => 'Facebook OAuth login',
                'POST /auth/social/apple' => 'Apple Sign-In',
                'GET /auth/social/accounts' => 'Get linked social accounts',
                'DELETE /auth/social/accounts/{provider}' => 'Disconnect social account',
            ],
            'Teachers' => [
                'GET /teachers' => 'Get all teachers with filters',
                'GET /teachers/{teacher}' => 'Get single teacher',
                'POST /teachers' => 'Create teacher profile',
                'PUT /teachers/{teacher}' => 'Update teacher profile',
                'DELETE /teachers/{teacher}' => 'Delete teacher profile',
            ],
            'Search' => [
                'GET /search' => 'Search teachers',
                'GET /search/suggestions' => 'Get search suggestions',
                'GET /search/trending' => 'Get trending teachers',
                'GET /search/filters' => 'Get available filters',
            ],
            'Reservations' => [
                'GET /reservations' => 'Get user reservations',
                'POST /reservations' => 'Create reservation',
                'PUT /reservations/{reservation}/status' => 'Update reservation status',
                'DELETE /reservations/{reservation}' => 'Cancel reservation',
            ],
            'Chat' => [
                'GET /chat/conversations' => 'Get conversations',
                'GET /chat/conversations/{conversation}/messages' => 'Get messages',
                'POST /chat/messages' => 'Send message',
                'PUT /chat/messages/{message}/read' => 'Mark message as read',
            ],
            'Admin' => [
                'GET /admin/dashboard' => 'Get admin dashboard',
                'GET /admin/users' => 'Get users list',
                'GET /admin/analytics' => 'Get platform analytics',
                'GET /admin/system-health' => 'Get system health status',
            ],
        ];

        $summary = "# API Endpoints Summary\n\n";
        $summary .= "This document provides a comprehensive overview of all available API endpoints.\n\n";
        
        foreach ($endpoints as $category => $categoryEndpoints) {
            $summary .= "## {$category}\n\n";
            foreach ($categoryEndpoints as $endpoint => $description) {
                $summary .= "- `{$endpoint}` - {$description}\n";
            }
            $summary .= "\n";
        }

        File::put(base_path('docs/API_ENDPOINTS.md'), $summary);
        $this->info("📋 Endpoint summary generated: docs/API_ENDPOINTS.md");
    }

    /**
     * Generate API guide
     */
    private function generateApiGuide(): void
    {
        $guide = <<<'GUIDE'
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

## Support

For API support and questions:
- Email: api-support@nazliyavuz.com
- Documentation: https://docs.nazliyavuz.com
- Status Page: https://status.nazliyavuz.com
GUIDE;

        File::put(base_path('docs/API_GUIDE.md'), $guide);
        $this->info("📖 API guide generated: docs/API_GUIDE.md");
    }

    /**
     * Generate Postman collection
     */
    private function generatePostmanCollection(array $openApiSpec): void
    {
        $collection = [
            'info' => [
                'name' => 'Nazliyavuz Education Platform API',
                'description' => 'Complete API collection for Nazliyavuz platform',
                'schema' => 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
            ],
            'auth' => [
                'type' => 'bearer',
                'bearer' => [
                    [
                        'key' => 'token',
                        'value' => '{{jwt_token}}',
                        'type' => 'string',
                    ],
                ],
            ],
            'variable' => [
                [
                    'key' => 'base_url',
                    'value' => config('app.url') . '/api',
                ],
                [
                    'key' => 'jwt_token',
                    'value' => '',
                ],
            ],
            'item' => [
                [
                    'name' => 'Authentication',
                    'item' => [
                        [
                            'name' => 'Register',
                            'request' => [
                                'method' => 'POST',
                                'header' => [
                                    [
                                        'key' => 'Content-Type',
                                        'value' => 'application/json',
                                    ],
                                ],
                                'body' => [
                                    'mode' => 'raw',
                                    'raw' => json_encode([
                                        'name' => 'John Doe',
                                        'email' => 'john@example.com',
                                        'password' => 'password123',
                                        'password_confirmation' => 'password123',
                                        'role' => 'student',
                                    ]),
                                ],
                                'url' => [
                                    'raw' => '{{base_url}}/auth/register',
                                    'host' => ['{{base_url}}'],
                                    'path' => ['auth', 'register'],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ];

        File::put(base_path('docs/postman-collection.json'), json_encode($collection, JSON_PRETTY_PRINT));
        $this->info("📮 Postman collection generated: docs/postman-collection.json");
    }

    /**
     * Display statistics
     */
    private function displayStats(array $openApiSpec): void
    {
        $this->info("\n📊 Documentation Statistics:");
        $this->info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        
        $pathCount = count($openApiSpec['paths']);
        $schemaCount = count($openApiSpec['components']['schemas']);
        $tagCount = count($openApiSpec['tags']);
        
        $this->info("📝 Endpoints: {$pathCount}");
        $this->info("📋 Schemas: {$schemaCount}");
        $this->info("🏷️  Tags: {$tagCount}");
        
        $this->info("\n✅ Documentation generation completed successfully!");
        $this->info("📁 Files generated:");
        $this->info("   - docs/api-docs.json (OpenAPI specification)");
        $this->info("   - docs/API_ENDPOINTS.md (Endpoint summary)");
        $this->info("   - docs/API_GUIDE.md (Integration guide)");
        $this->info("   - docs/postman-collection.json (Postman collection)");
    }
}