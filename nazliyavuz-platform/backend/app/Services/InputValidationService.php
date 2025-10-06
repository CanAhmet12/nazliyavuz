<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;

class InputValidationService
{
    /**
     * Validate user registration data
     */
    public function validateRegistration(Request $request): array
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255|min:2',
            'email' => 'required|email|max:255|unique:users,email',
            'password' => 'required|string|min:8|max:255|confirmed',
            'password_confirmation' => 'required|string|min:8|max:255',
            'role' => 'required|in:student,teacher',
            'phone' => 'nullable|string|max:20|regex:/^[+]?[0-9\s\-\(\)]+$/',
            'date_of_birth' => 'nullable|date|before:today|after:1900-01-01',
            'terms_accepted' => 'required|accepted',
            'privacy_policy_accepted' => 'required|accepted',
        ], [
            'name.required' => 'İsim gereklidir',
            'name.min' => 'İsim en az 2 karakter olmalıdır',
            'name.max' => 'İsim en fazla 255 karakter olabilir',
            'email.required' => 'E-posta adresi gereklidir',
            'email.email' => 'Geçerli bir e-posta adresi giriniz',
            'email.unique' => 'Bu e-posta adresi zaten kullanılıyor',
            'password.required' => 'Şifre gereklidir',
            'password.min' => 'Şifre en az 8 karakter olmalıdır',
            'password.confirmed' => 'Şifre onayı eşleşmiyor',
            'role.required' => 'Rol seçimi gereklidir',
            'role.in' => 'Geçersiz rol seçimi',
            'phone.regex' => 'Geçerli bir telefon numarası giriniz',
            'date_of_birth.date' => 'Geçerli bir doğum tarihi giriniz',
            'date_of_birth.before' => 'Doğum tarihi bugünden önce olmalıdır',
            'terms_accepted.accepted' => 'Kullanım şartlarını kabul etmelisiniz',
            'privacy_policy_accepted.accepted' => 'Gizlilik politikasını kabul etmelisiniz',
        ]);

        if ($validator->fails()) {
            Log::warning('Registration validation failed', [
                'errors' => $validator->errors()->toArray(),
                'ip' => $request->ip(),
                'user_agent' => $request->userAgent(),
            ]);
            
            return [
                'success' => false,
                'errors' => $validator->errors(),
                'message' => 'Validation failed'
            ];
        }

        return ['success' => true];
    }

    /**
     * Validate user login data
     */
    public function validateLogin(Request $request): array
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|email|max:255',
            'password' => 'required|string|max:255',
            'remember_me' => 'nullable|boolean',
        ], [
            'email.required' => 'E-posta adresi gereklidir',
            'email.email' => 'Geçerli bir e-posta adresi giriniz',
            'password.required' => 'Şifre gereklidir',
        ]);

        if ($validator->fails()) {
            Log::warning('Login validation failed', [
                'errors' => $validator->errors()->toArray(),
                'ip' => $request->ip(),
                'email' => $request->email,
            ]);
            
            return [
                'success' => false,
                'errors' => $validator->errors(),
                'message' => 'Validation failed'
            ];
        }

        return ['success' => true];
    }

    /**
     * Validate reservation data
     */
    public function validateReservation(Request $request): array
    {
        $validator = Validator::make($request->all(), [
            'teacher_id' => 'required|integer|exists:users,id',
            'category_id' => 'required|integer|exists:categories,id',
            'subject' => 'required|string|max:255|min:3',
            'proposed_datetime' => 'required|date|after:now',
            'duration_minutes' => 'required|integer|min:15|max:480', // 15 minutes to 8 hours
            'notes' => 'nullable|string|max:1000',
        ], [
            'teacher_id.required' => 'Öğretmen seçimi gereklidir',
            'teacher_id.exists' => 'Seçilen öğretmen bulunamadı',
            'category_id.required' => 'Kategori seçimi gereklidir',
            'category_id.exists' => 'Seçilen kategori bulunamadı',
            'subject.required' => 'Konu gereklidir',
            'subject.min' => 'Konu en az 3 karakter olmalıdır',
            'subject.max' => 'Konu en fazla 255 karakter olabilir',
            'proposed_datetime.required' => 'Tarih ve saat gereklidir',
            'proposed_datetime.after' => 'Gelecek bir tarih seçiniz',
            'duration_minutes.required' => 'Süre gereklidir',
            'duration_minutes.min' => 'Minimum süre 15 dakikadır',
            'duration_minutes.max' => 'Maksimum süre 8 saattir',
            'notes.max' => 'Notlar en fazla 1000 karakter olabilir',
        ]);

        if ($validator->fails()) {
            Log::warning('Reservation validation failed', [
                'errors' => $validator->errors()->toArray(),
                'user_id' => auth()->id(),
                'ip' => $request->ip(),
            ]);
            
            return [
                'success' => false,
                'errors' => $validator->errors(),
                'message' => 'Validation failed'
            ];
        }

        return ['success' => true];
    }

    /**
     * Validate video call data
     */
    public function validateVideoCall(Request $request): array
    {
        $validator = Validator::make($request->all(), [
            'receiver_id' => 'required|integer|exists:users,id|different:' . auth()->id(),
            'call_type' => 'required|in:video,audio',
            'call_id' => 'nullable|string|max:255',
            'subject' => 'nullable|string|max:255',
            'reservation_id' => 'nullable|integer|exists:reservations,id',
        ], [
            'receiver_id.required' => 'Alıcı seçimi gereklidir',
            'receiver_id.exists' => 'Seçilen kullanıcı bulunamadı',
            'receiver_id.different' => 'Kendinizi arayamazsınız',
            'call_type.required' => 'Arama türü gereklidir',
            'call_type.in' => 'Geçersiz arama türü',
            'reservation_id.exists' => 'Seçilen rezervasyon bulunamadı',
        ]);

        if ($validator->fails()) {
            Log::warning('Video call validation failed', [
                'errors' => $validator->errors()->toArray(),
                'user_id' => auth()->id(),
                'ip' => $request->ip(),
            ]);
            
            return [
                'success' => false,
                'errors' => $validator->errors(),
                'message' => 'Validation failed'
            ];
        }

        return ['success' => true];
    }

    /**
     * Validate file upload data
     */
    public function validateFileUpload(Request $request): array
    {
        $validator = Validator::make($request->all(), [
            'file' => 'required|file|max:209715200|mimes:jpg,jpeg,png,gif,webp,pdf,doc,docx,xls,xlsx,ppt,pptx,txt,mp4,avi,mov,wmv,mp3,wav,aac,ogg,zip,rar,7z', // 200MB max
            'receiver_id' => 'required|integer|exists:users,id',
            'chat_id' => 'nullable|integer|exists:chats,id',
            'caption' => 'nullable|string|max:500',
            'metadata' => 'nullable|json',
        ], [
            'file.required' => 'Dosya gereklidir',
            'file.max' => 'Dosya boyutu en fazla 200MB olabilir',
            'file.mimes' => 'Desteklenmeyen dosya türü',
            'receiver_id.required' => 'Alıcı seçimi gereklidir',
            'receiver_id.exists' => 'Seçilen kullanıcı bulunamadı',
            'chat_id.exists' => 'Seçilen sohbet bulunamadı',
            'caption.max' => 'Açıklama en fazla 500 karakter olabilir',
            'metadata.json' => 'Metadata geçerli JSON formatında olmalıdır',
        ]);

        if ($validator->fails()) {
            Log::warning('File upload validation failed', [
                'errors' => $validator->errors()->toArray(),
                'user_id' => auth()->id(),
                'ip' => $request->ip(),
                'file_size' => $request->file('file')?->getSize(),
                'file_type' => $request->file('file')?->getMimeType(),
            ]);
            
            return [
                'success' => false,
                'errors' => $validator->errors(),
                'message' => 'Validation failed'
            ];
        }

        return ['success' => true];
    }

    /**
     * Validate message data
     */
    public function validateMessage(Request $request): array
    {
        $validator = Validator::make($request->all(), [
            'receiver_id' => 'required|integer|exists:users,id|different:' . auth()->id(),
            'content' => 'required|string|max:2000|min:1',
            'message_type' => 'required|in:text,image,file,audio,video',
            'chat_id' => 'nullable|integer|exists:chats,id',
            'reply_to_message_id' => 'nullable|integer|exists:messages,id',
        ], [
            'receiver_id.required' => 'Alıcı seçimi gereklidir',
            'receiver_id.exists' => 'Seçilen kullanıcı bulunamadı',
            'receiver_id.different' => 'Kendinize mesaj gönderemezsiniz',
            'content.required' => 'Mesaj içeriği gereklidir',
            'content.max' => 'Mesaj en fazla 2000 karakter olabilir',
            'content.min' => 'Mesaj en az 1 karakter olmalıdır',
            'message_type.required' => 'Mesaj türü gereklidir',
            'message_type.in' => 'Geçersiz mesaj türü',
            'chat_id.exists' => 'Seçilen sohbet bulunamadı',
            'reply_to_message_id.exists' => 'Yanıtlanan mesaj bulunamadı',
        ]);

        if ($validator->fails()) {
            Log::warning('Message validation failed', [
                'errors' => $validator->errors()->toArray(),
                'user_id' => auth()->id(),
                'ip' => $request->ip(),
            ]);
            
            return [
                'success' => false,
                'errors' => $validator->errors(),
                'message' => 'Validation failed'
            ];
        }

        return ['success' => true];
    }

    /**
     * Validate search data
     */
    public function validateSearch(Request $request): array
    {
        $validator = Validator::make($request->all(), [
            'query' => 'required|string|max:255|min:2',
            'category_id' => 'nullable|integer|exists:categories,id',
            'min_price' => 'nullable|numeric|min:0|max:1000',
            'max_price' => 'nullable|numeric|min:0|max:1000|gte:min_price',
            'rating' => 'nullable|numeric|min:1|max:5',
            'location' => 'nullable|string|max:255',
            'page' => 'nullable|integer|min:1|max:100',
            'limit' => 'nullable|integer|min:1|max:50',
        ], [
            'query.required' => 'Arama terimi gereklidir',
            'query.min' => 'Arama terimi en az 2 karakter olmalıdır',
            'query.max' => 'Arama terimi en fazla 255 karakter olabilir',
            'category_id.exists' => 'Seçilen kategori bulunamadı',
            'min_price.min' => 'Minimum fiyat 0\'dan küçük olamaz',
            'min_price.max' => 'Minimum fiyat 1000\'den büyük olamaz',
            'max_price.gte' => 'Maksimum fiyat minimum fiyattan küçük olamaz',
            'rating.min' => 'Minimum puan 1 olmalıdır',
            'rating.max' => 'Maksimum puan 5 olmalıdır',
            'location.max' => 'Konum en fazla 255 karakter olabilir',
            'page.min' => 'Sayfa numarası en az 1 olmalıdır',
            'page.max' => 'Sayfa numarası en fazla 100 olabilir',
            'limit.min' => 'Limit en az 1 olmalıdır',
            'limit.max' => 'Limit en fazla 50 olabilir',
        ]);

        if ($validator->fails()) {
            Log::warning('Search validation failed', [
                'errors' => $validator->errors()->toArray(),
                'user_id' => auth()->id(),
                'ip' => $request->ip(),
                'query' => $request->query,
            ]);
            
            return [
                'success' => false,
                'errors' => $validator->errors(),
                'message' => 'Validation failed'
            ];
        }

        return ['success' => true];
    }

    /**
     * Validate profile update data
     */
    public function validateProfileUpdate(Request $request): array
    {
        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|required|string|max:255|min:2',
            'phone' => 'nullable|string|max:20|regex:/^[+]?[0-9\s\-\(\)]+$/',
            'date_of_birth' => 'nullable|date|before:today|after:1900-01-01',
            'bio' => 'nullable|string|max:1000',
            'location' => 'nullable|string|max:255',
            'website' => 'nullable|url|max:255',
            'specialties' => 'nullable|array|max:10',
            'specialties.*' => 'string|max:100',
            'experience_years' => 'nullable|integer|min:0|max:50',
            'price_per_hour' => 'nullable|numeric|min:0|max:1000',
            'available_hours' => 'nullable|array',
            'available_hours.*.day' => 'required_with:available_hours|in:monday,tuesday,wednesday,thursday,friday,saturday,sunday',
            'available_hours.*.start_time' => 'required_with:available_hours|date_format:H:i',
            'available_hours.*.end_time' => 'required_with:available_hours|date_format:H:i|after:available_hours.*.start_time',
        ], [
            'name.min' => 'İsim en az 2 karakter olmalıdır',
            'name.max' => 'İsim en fazla 255 karakter olabilir',
            'phone.regex' => 'Geçerli bir telefon numarası giriniz',
            'date_of_birth.date' => 'Geçerli bir doğum tarihi giriniz',
            'bio.max' => 'Biyografi en fazla 1000 karakter olabilir',
            'location.max' => 'Konum en fazla 255 karakter olabilir',
            'website.url' => 'Geçerli bir web sitesi adresi giriniz',
            'specialties.max' => 'En fazla 10 uzmanlık alanı seçebilirsiniz',
            'experience_years.min' => 'Deneyim yılı 0\'dan küçük olamaz',
            'experience_years.max' => 'Deneyim yılı 50\'den büyük olamaz',
            'price_per_hour.min' => 'Saatlik ücret 0\'dan küçük olamaz',
            'price_per_hour.max' => 'Saatlik ücret 1000\'den büyük olamaz',
        ]);

        if ($validator->fails()) {
            Log::warning('Profile update validation failed', [
                'errors' => $validator->errors()->toArray(),
                'user_id' => auth()->id(),
                'ip' => $request->ip(),
            ]);
            
            return [
                'success' => false,
                'errors' => $validator->errors(),
                'message' => 'Validation failed'
            ];
        }

        return ['success' => true];
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
                $value = strip_tags($value);
                $value = trim($value);
                
                // Escape HTML entities
                $value = htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
                
                // Remove null bytes
                $value = str_replace("\0", '', $value);
            }
            
            $sanitized[$key] = $value;
        }
        
        return $sanitized;
    }

    /**
     * Validate and sanitize input
     */
    public function validateAndSanitize(Request $request, array $rules, array $messages = []): array
    {
        $validator = Validator::make($request->all(), $rules, $messages);
        
        if ($validator->fails()) {
            Log::warning('Input validation failed', [
                'errors' => $validator->errors()->toArray(),
                'user_id' => auth()->id(),
                'ip' => $request->ip(),
                'endpoint' => $request->path(),
            ]);
            
            return [
                'success' => false,
                'errors' => $validator->errors(),
                'message' => 'Validation failed'
            ];
        }
        
        // Sanitize validated data
        $sanitizedData = $this->sanitizeInput($validator->validated());
        
        return [
            'success' => true,
            'data' => $sanitizedData
        ];
    }
}
