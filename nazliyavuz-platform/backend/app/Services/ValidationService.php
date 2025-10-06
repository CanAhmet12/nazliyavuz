<?php

namespace App\Services;

use Illuminate\Support\Facades\Validator;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class ValidationService
{
    /**
     * Validate teacher profile data
     */
    public function validateTeacherProfile(array $data): array
    {
        $validator = Validator::make($data, [
            'bio' => 'required|string|min:50|max:1000',
            'education' => 'required|array|min:1',
            'education.*.institution' => 'required|string|max:255',
            'education.*.degree' => 'required|string|max:255',
            'education.*.year' => 'required|integer|min:1950|max:' . date('Y'),
            'certifications' => 'nullable|array',
            'certifications.*.name' => 'required|string|max:255',
            'certifications.*.issuer' => 'required|string|max:255',
            'certifications.*.date' => 'required|date|before:today',
            'price_hour' => 'required|numeric|min:50|max:2000',
            'languages' => 'required|array|min:1',
            'languages.*' => 'required|string|in:Turkish,English,German,French,Spanish,Italian,Russian,Arabic,Chinese,Japanese',
            'categories' => 'required|array|min:1|max:5',
            'categories.*' => 'required|integer|exists:categories,id',
        ]);

        if ($validator->fails()) {
            Log::warning('Teacher profile validation failed', [
                'errors' => $validator->errors()->toArray(),
                'data' => $this->sanitizeDataForLog($data)
            ]);
            
            return [
                'success' => false,
                'errors' => $validator->errors()
            ];
        }

        return [
            'success' => true,
            'data' => $validator->validated()
        ];
    }

    /**
     * Validate reservation data
     */
    public function validateReservation(array $data): array
    {
        $validator = Validator::make($data, [
            'teacher_id' => 'required|integer|exists:teachers,id',
            'reservation_date' => 'required|date|after:now',
            'start_time' => 'required|date_format:H:i',
            'end_time' => 'required|date_format:H:i|after:start_time',
            'notes' => 'nullable|string|max:500',
            'type' => 'required|in:online,offline',
            'location' => 'required_if:type,offline|string|max:255',
        ]);

        if ($validator->fails()) {
            Log::warning('Reservation validation failed', [
                'errors' => $validator->errors()->toArray(),
                'data' => $this->sanitizeDataForLog($data)
            ]);
            
            return [
                'success' => false,
                'errors' => $validator->errors()
            ];
        }

        return [
            'success' => true,
            'data' => $validator->validated()
        ];
    }

    /**
     * Validate rating data
     */
    public function validateRating(array $data): array
    {
        $validator = Validator::make($data, [
            'reservation_id' => 'required|integer|exists:reservations,id',
            'rating' => 'required|integer|min:1|max:5',
            'review' => 'nullable|string|min:10|max:1000',
        ]);

        if ($validator->fails()) {
            Log::warning('Rating validation failed', [
                'errors' => $validator->errors()->toArray(),
                'data' => $this->sanitizeDataForLog($data)
            ]);
            
            return [
                'success' => false,
                'errors' => $validator->errors()
            ];
        }

        return [
            'success' => true,
            'data' => $validator->validated()
        ];
    }

    /**
     * Validate file upload data
     */
    public function validateFileUpload(Request $request, string $type = 'profile_photo'): array
    {
        $rules = [];
        
        switch ($type) {
            case 'profile_photo':
                $rules = [
                    'file' => 'required|file|image|mimes:jpeg,png,jpg,gif,webp|max:5120', // 5MB
                ];
                break;
            case 'document':
                $rules = [
                    'file' => 'required|file|mimes:pdf,doc,docx,txt|max:10240', // 10MB
                    'type' => 'required|string|in:certificate,diploma,id_document,other',
                ];
                break;
        }

        $validator = Validator::make($request->all(), $rules);

        if ($validator->fails()) {
            Log::warning('File upload validation failed', [
                'type' => $type,
                'errors' => $validator->errors()->toArray(),
                'file_size' => $request->file('file')?->getSize(),
                'file_type' => $request->file('file')?->getMimeType(),
            ]);
            
            return [
                'success' => false,
                'errors' => $validator->errors()
            ];
        }

        return [
            'success' => true,
            'data' => $validator->validated()
        ];
    }

    /**
     * Validate search parameters
     */
    public function validateSearchParameters(array $data): array
    {
        $validator = Validator::make($data, [
            'query' => 'nullable|string|max:100',
            'category' => 'nullable|string|exists:categories,slug',
            'price_min' => 'nullable|numeric|min:0|max:2000',
            'price_max' => 'nullable|numeric|min:0|max:2000|gte:price_min',
            'rating_min' => 'nullable|numeric|min:1|max:5',
            'language' => 'nullable|string|in:Turkish,English,German,French,Spanish,Italian,Russian,Arabic,Chinese,Japanese',
            'online_only' => 'nullable|boolean',
            'sort_by' => 'nullable|string|in:rating,price,name,created_at',
            'sort_order' => 'nullable|string|in:asc,desc',
            'page' => 'nullable|integer|min:1|max:100',
            'per_page' => 'nullable|integer|min:1|max:100',
        ]);

        if ($validator->fails()) {
            Log::warning('Search parameters validation failed', [
                'errors' => $validator->errors()->toArray(),
                'data' => $this->sanitizeDataForLog($data)
            ]);
            
            return [
                'success' => false,
                'errors' => $validator->errors()
            ];
        }

        return [
            'success' => true,
            'data' => $validator->validated()
        ];
    }

    /**
     * Sanitize input data
     */
    public function sanitizeInput(array $data): array
    {
        $sanitized = [];
        
        foreach ($data as $key => $value) {
            if (is_string($value)) {
                // Remove potentially dangerous characters
                $sanitized[$key] = strip_tags(trim($value));
                
                // Prevent XSS
                $sanitized[$key] = htmlspecialchars($sanitized[$key], ENT_QUOTES, 'UTF-8');
            } elseif (is_array($value)) {
                $sanitized[$key] = $this->sanitizeInput($value);
            } else {
                $sanitized[$key] = $value;
            }
        }
        
        return $sanitized;
    }

    /**
     * Validate email format
     */
    public function validateEmail(string $email): bool
    {
        return filter_var($email, FILTER_VALIDATE_EMAIL) !== false;
    }

    /**
     * Validate password strength
     */
    public function validatePasswordStrength(string $password): array
    {
        $errors = [];
        
        if (strlen($password) < 8) {
            $errors[] = 'Password must be at least 8 characters long';
        }
        
        if (!preg_match('/[A-Z]/', $password)) {
            $errors[] = 'Password must contain at least one uppercase letter';
        }
        
        if (!preg_match('/[a-z]/', $password)) {
            $errors[] = 'Password must contain at least one lowercase letter';
        }
        
        if (!preg_match('/[0-9]/', $password)) {
            $errors[] = 'Password must contain at least one number';
        }
        
        if (!preg_match('/[^A-Za-z0-9]/', $password)) {
            $errors[] = 'Password must contain at least one special character';
        }
        
        return [
            'valid' => empty($errors),
            'errors' => $errors
        ];
    }

    /**
     * Check for SQL injection patterns
     */
    public function detectSQLInjection(string $input): bool
    {
        $patterns = [
            '/(\bunion\b.*\bselect\b)/i',
            '/(\bselect\b.*\bfrom\b)/i',
            '/(\binsert\b.*\binto\b)/i',
            '/(\bupdate\b.*\bset\b)/i',
            '/(\bdelete\b.*\bfrom\b)/i',
            '/(\bdrop\b.*\btable\b)/i',
            '/(\balter\b.*\btable\b)/i',
            '/(\bexec\b|\bexecute\b)/i',
            '/(\bscript\b.*\b>)/i',
            '/(\bjavascript\b:)/i',
        ];
        
        foreach ($patterns as $pattern) {
            if (preg_match($pattern, $input)) {
                Log::warning('Potential SQL injection detected', [
                    'input' => substr($input, 0, 100),
                    'pattern' => $pattern
                ]);
                return true;
            }
        }
        
        return false;
    }

    /**
     * Sanitize data for logging (remove sensitive information)
     */
    private function sanitizeDataForLog(array $data): array
    {
        $sensitiveFields = ['password', 'password_confirmation', 'token', 'api_key', 'secret'];
        
        foreach ($data as $key => $value) {
            if (in_array(strtolower($key), $sensitiveFields)) {
                $data[$key] = '[REDACTED]';
            } elseif (is_array($value)) {
                $data[$key] = $this->sanitizeDataForLog($value);
            }
        }
        
        return $data;
    }
}
