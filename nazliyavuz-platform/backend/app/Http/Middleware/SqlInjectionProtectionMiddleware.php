<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;

class SqlInjectionProtectionMiddleware
{
    /**
     * SQL injection patterns to detect
     */
    private array $sqlPatterns = [
        // Basic SQL injection patterns
        '/(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|UNION|SCRIPT)\b)/i',
        '/(\b(OR|AND)\s+\d+\s*=\s*\d+)/i',
        '/(\b(OR|AND)\s+[\'"]?\w+[\'"]?\s*=\s*[\'"]?\w+[\'"]?)/i',
        '/(\bUNION\s+(ALL\s+)?SELECT)/i',
        '/(\bSELECT\s+.*\s+FROM\s+.*\s+WHERE)/i',
        '/(\bINSERT\s+INTO\s+.*\s+VALUES)/i',
        '/(\bUPDATE\s+.*\s+SET\s+.*\s+WHERE)/i',
        '/(\bDELETE\s+FROM\s+.*\s+WHERE)/i',
        '/(\bDROP\s+(TABLE|DATABASE|INDEX|VIEW))/i',
        '/(\bCREATE\s+(TABLE|DATABASE|INDEX|VIEW))/i',
        '/(\bALTER\s+(TABLE|DATABASE|INDEX|VIEW))/i',
        
        // Comment patterns
        '/(--|\#|\/\*|\*\/)/',
        
        // Quote manipulation
        '/(\'\s*;\s*--|\'\s*;\s*#|\'\s*;\s*\/\*)/i',
        '/(\'\s*OR\s*1\s*=\s*1|\'\s*AND\s*1\s*=\s*1)/i',
        '/(\'\s*OR\s*\'\w*\'\s*=\s*\'\w*|\'\s*AND\s*\'\w*\'\s*=\s*\'\w*)/i',
        
        // Time-based blind SQL injection
        '/(\bSLEEP\s*\(|\bWAITFOR\s+DELAY|\bBENCHMARK\s*\()/i',
        
        // Information schema attacks
        '/(\bINFORMATION_SCHEMA\b|\bSYS\.|\.SYS\.)/i',
        
        // Function calls
        '/(\bCONCAT\s*\(|\bSUBSTRING\s*\(|\bASCII\s*\(|\bCHAR\s*\()/i',
        
        // Error-based SQL injection
        '/(\bEXTRACTVALUE\s*\(|\bUPDATEXML\s*\()/i',
        
        // Boolean-based blind SQL injection
        '/(\bIF\s*\(|\bCASE\s+WHEN)/i',
        
        // Stacked queries
        '/(\b;\s*(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER))/i',
        
        // Hex encoding
        '/(0x[0-9a-fA-F]+)/',
        
        // Binary operations
        '/(\bBINARY\b|\bCHAR\s*\(|\bHEX\s*\()/i',
        
        // System functions
        '/(\bUSER\s*\(|\bDATABASE\s*\(|\bVERSION\s*\(|\bSYSTEM_USER\s*\()/i',
    ];

    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Check all request parameters
        $allInput = $request->all();
        
        foreach ($allInput as $key => $value) {
            if (is_string($value)) {
                if ($this->detectSqlInjection($value, $key)) {
                    $this->logSqlInjectionAttempt($request, $key, $value);
                    
                    return response()->json([
                        'success' => false,
                        'error' => [
                            'code' => 'SECURITY_VIOLATION',
                            'message' => 'Invalid input detected'
                        ]
                    ], 400);
                }
            } elseif (is_array($value)) {
                if ($this->detectSqlInjectionInArray($value, $key)) {
                    $this->logSqlInjectionAttempt($request, $key, $value);
                    
                    return response()->json([
                        'success' => false,
                        'error' => [
                            'code' => 'SECURITY_VIOLATION',
                            'message' => 'Invalid input detected'
                        ]
                    ], 400);
                }
            }
        }

        return $next($request);
    }

    /**
     * Detect SQL injection in string value
     */
    private function detectSqlInjection(string $value, string $key): bool
    {
        // Skip certain keys that might legitimately contain SQL-like content
        $skipKeys = ['password', 'password_confirmation', 'token', 'signature'];
        if (in_array($key, $skipKeys)) {
            return false;
        }

        // Check for SQL injection patterns
        foreach ($this->sqlPatterns as $pattern) {
            if (preg_match($pattern, $value)) {
                return true;
            }
        }

        // Additional checks for suspicious patterns
        if ($this->hasSuspiciousPatterns($value)) {
            return true;
        }

        return false;
    }

    /**
     * Detect SQL injection in array values
     */
    private function detectSqlInjectionInArray(array $array, string $key): bool
    {
        foreach ($array as $subKey => $subValue) {
            if (is_string($subValue)) {
                if ($this->detectSqlInjection($subValue, $subKey)) {
                    return true;
                }
            } elseif (is_array($subValue)) {
                if ($this->detectSqlInjectionInArray($subValue, $subKey)) {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * Check for suspicious patterns that might indicate SQL injection
     */
    private function hasSuspiciousPatterns(string $value): bool
    {
        // Multiple quotes
        if (substr_count($value, "'") > 2 || substr_count($value, '"') > 2) {
            return true;
        }

        // Multiple semicolons
        if (substr_count($value, ';') > 1) {
            return true;
        }

        // Multiple dashes (comments)
        if (substr_count($value, '--') > 0) {
            return true;
        }

        // Multiple hash symbols (comments)
        if (substr_count($value, '#') > 0) {
            return true;
        }

        // Parentheses with suspicious content
        if (preg_match('/\([^)]*(select|insert|update|delete|drop|create|alter)[^)]*\)/i', $value)) {
            return true;
        }

        // Brackets with suspicious content
        if (preg_match('/\[[^\]]*(select|insert|update|delete|drop|create|alter)[^\]]*\]/i', $value)) {
            return true;
        }

        // Percentage signs (wildcards)
        if (substr_count($value, '%') > 2) {
            return true;
        }

        // Underscores (wildcards)
        if (substr_count($value, '_') > 3) {
            return true;
        }

        return false;
    }

    /**
     * Log SQL injection attempt
     */
    private function logSqlInjectionAttempt(Request $request, string $key, $value): void
    {
        Log::critical('SQL Injection attempt detected', [
            'ip' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'user_id' => auth()->id(),
            'endpoint' => $request->path(),
            'method' => $request->method(),
            'parameter' => $key,
            'value' => is_string($value) ? $value : json_encode($value),
            'timestamp' => now(),
            'headers' => $request->headers->all(),
        ]);
    }
}
