<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;

class XssProtectionMiddleware
{
    /**
     * XSS patterns to detect
     */
    private array $xssPatterns = [
        // Script tags
        '/<script[^>]*>.*?<\/script>/is',
        '/<script[^>]*>/i',
        '/<\/script>/i',
        
        // JavaScript events
        '/on\w+\s*=/i',
        '/on\w+\s*:\s*["\']/i',
        
        // JavaScript protocol
        '/javascript\s*:/i',
        '/vbscript\s*:/i',
        '/data\s*:\s*text\/html/i',
        '/data\s*:\s*application\/javascript/i',
        
        // Iframe tags
        '/<iframe[^>]*>.*?<\/iframe>/is',
        '/<iframe[^>]*>/i',
        '/<\/iframe>/i',
        
        // Object and embed tags
        '/<object[^>]*>.*?<\/object>/is',
        '/<embed[^>]*>/i',
        '/<applet[^>]*>.*?<\/applet>/is',
        
        // Form tags with suspicious attributes
        '/<form[^>]*(action|method|target)\s*=/i',
        
        // Input tags with suspicious attributes
        '/<input[^>]*(on\w+|javascript\s*:)/i',
        
        // Link tags with javascript
        '/<a[^>]*href\s*=\s*["\']?\s*javascript\s*:/i',
        
        // Style tags with javascript
        '/<style[^>]*>.*?<\/style>/is',
        '/<link[^>]*>/i',
        
        // Meta refresh
        '/<meta[^>]*http-equiv\s*=\s*["\']?\s*refresh/i',
        
        // Base tag
        '/<base[^>]*>/i',
        
        // Expression in CSS
        '/expression\s*\(/i',
        '/url\s*\(\s*javascript\s*:/i',
        
        // VBScript
        '/vbscript\s*:/i',
        '/<script[^>]*language\s*=\s*["\']?\s*vbscript/i',
        
        // ActiveX
        '/<object[^>]*classid\s*=/i',
        
        // Flash
        '/<embed[^>]*type\s*=\s*["\']?\s*application\/x-shockwave-flash/i',
        
        // PHP tags (in case of server-side XSS)
        '/<\?php/i',
        '/<\?=/i',
        
        // HTML entities that might be decoded
        '/&#x?[0-9a-fA-F]+;/',
        
        // Unicode escape sequences
        '/\\u[0-9a-fA-F]{4}/',
        
        // Base64 encoded content
        '/data\s*:\s*[^;]*;base64/i',
        
        // SVG with script
        '/<svg[^>]*>.*?<script/i',
        
        // MathML with script
        '/<math[^>]*>.*?<script/i',
        
        // HTML5 event handlers
        '/on(load|error|click|mouseover|focus|blur|change|submit|reset|select|abort|beforeunload|error|hashchange|message|offline|online|pagehide|pageshow|popstate|resize|scroll|storage|unload)\s*=/i',
        
        // CSS expressions
        '/expression\s*\(\s*["\']?[^"\']*["\']?\s*\)/i',
        
        // Import statements
        '/@import/i',
        
        // URL imports
        '/url\s*\(\s*["\']?[^"\']*["\']?\s*\)/i',
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
                if ($this->detectXss($value, $key)) {
                    $this->logXssAttempt($request, $key, $value);
                    
                    return response()->json([
                        'success' => false,
                        'error' => [
                            'code' => 'SECURITY_VIOLATION',
                            'message' => 'Invalid input detected'
                        ]
                    ], 400);
                }
            } elseif (is_array($value)) {
                if ($this->detectXssInArray($value, $key)) {
                    $this->logXssAttempt($request, $key, $value);
                    
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
     * Detect XSS in string value
     */
    private function detectXss(string $value, string $key): bool
    {
        // Skip certain keys that might legitimately contain HTML-like content
        $skipKeys = ['password', 'password_confirmation', 'token', 'signature', 'bio', 'description', 'content'];
        if (in_array($key, $skipKeys)) {
            return false;
        }

        // Check for XSS patterns
        foreach ($this->xssPatterns as $pattern) {
            if (preg_match($pattern, $value)) {
                return true;
            }
        }

        // Additional checks for suspicious patterns
        if ($this->hasSuspiciousXssPatterns($value)) {
            return true;
        }

        return false;
    }

    /**
     * Detect XSS in array values
     */
    private function detectXssInArray(array $array, string $key): bool
    {
        foreach ($array as $subKey => $subValue) {
            if (is_string($subValue)) {
                if ($this->detectXss($subValue, $subKey)) {
                    return true;
                }
            } elseif (is_array($subValue)) {
                if ($this->detectXssInArray($subValue, $subKey)) {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * Check for suspicious XSS patterns
     */
    private function hasSuspiciousXssPatterns(string $value): bool
    {
        // Multiple angle brackets
        if (substr_count($value, '<') > 2 || substr_count($value, '>') > 2) {
            return true;
        }

        // Multiple quotes in suspicious context
        if (preg_match('/["\'][^"\']*["\'][^"\']*["\']/', $value)) {
            return true;
        }

        // Suspicious HTML entities
        if (preg_match('/&[#\w]+;/', $value) && preg_match('/<|>/', $value)) {
            return true;
        }

        // Encoded characters that might be decoded
        if (preg_match('/%[0-9a-fA-F]{2}/', $value) && preg_match('/<|>|javascript/i', $value)) {
            return true;
        }

        // Double encoding attempts
        if (preg_match('/%25[0-9a-fA-F]{2}/', $value)) {
            return true;
        }

        // Null bytes
        if (strpos($value, "\0") !== false) {
            return true;
        }

        // Control characters
        if (preg_match('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/', $value)) {
            return true;
        }

        // Suspicious Unicode
        if (preg_match('/[\u0000-\u001F\u007F-\u009F]/', $value)) {
            return true;
        }

        // Mixed case attempts to bypass filters
        if (preg_match('/[sS][cC][rR][iI][pP][tT]/', $value)) {
            return true;
        }

        // Whitespace obfuscation
        if (preg_match('/<[^>]*\s+[^>]*>/', $value)) {
            return true;
        }

        return false;
    }

    /**
     * Log XSS attempt
     */
    private function logXssAttempt(Request $request, string $key, $value): void
    {
        Log::critical('XSS attempt detected', [
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
