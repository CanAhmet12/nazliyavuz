<?php

namespace App\Services;

use App\Models\User;
use App\Models\Reservation;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Log;

class MailService
{
    /**
     * Mail gönderim durumunu kontrol et
     */
    public function isMailConfigured(): bool
    {
        $required = [
            'mail.mailers.smtp.host',
            'mail.mailers.smtp.port',
            'mail.mailers.smtp.username',
            'mail.mailers.smtp.password',
            'mail.from.address',
            'mail.from.name'
        ];
        
        foreach ($required as $config) {
            if (empty(config($config))) {
                return false;
            }
        }
        
        return true;
    }
    
    /**
     * Mail gönderimini test et
     */
    public function testMailConfiguration(): array
    {
        $result = [
            'configured' => $this->isMailConfigured(),
            'config' => [
                'driver' => config('mail.default'),
                'host' => config('mail.mailers.smtp.host'),
                'port' => config('mail.mailers.smtp.port'),
                'username' => config('mail.mailers.smtp.username') ? 'SET' : 'NOT_SET',
                'password' => config('mail.mailers.smtp.password') ? 'SET' : 'NOT_SET',
                'encryption' => config('mail.mailers.smtp.encryption'),
                'from_address' => config('mail.from.address'),
                'from_name' => config('mail.from.name'),
            ],
            'recommendations' => []
        ];
        
        if (!$result['configured']) {
            $result['recommendations'] = [
                'Gmail kullanın: smtp.gmail.com:587',
                '2FA aktif Gmail hesabı oluşturun',
                'Gmail App Password oluşturun',
                '.env dosyasında MAIL_* ayarlarını yapın'
            ];
        }
        
        return $result;
    }
    /**
     * Send email verification email
     */
    public function sendEmailVerification(User $user, string $token, string $verificationCode): bool
    {
        try {
            // Debug için log
            Log::info('Sending email verification with 6-digit code', [
                'user_id' => $user->id,
                'email' => $user->email,
                'verification_code' => $verificationCode,
                'mail_config' => [
                    'driver' => config('mail.default'),
                    'host' => config('mail.mailers.smtp.host'),
                    'port' => config('mail.mailers.smtp.port'),
                    'from_address' => config('mail.from.address'),
                    'from_name' => config('mail.from.name')
                ]
            ]);

            // Mail gönder
            Mail::send('emails.verify-email', [
                'user' => $user,
                'token' => $token,
                'verificationCode' => $verificationCode,
            ], function ($message) use ($user) {
                $message->to($user->email, $user->name)
                    ->subject('E-posta Doğrulama Kodu - Nazliyavuz Platform');
            });

            Log::info('Email verification code sent successfully', [
                'user_id' => $user->id, 
                'email' => $user->email,
                'verification_code' => $verificationCode
            ]);
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to send email verification code', [
                'user_id' => $user->id,
                'email' => $user->email,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);
            
            // Fallback: Eğer mail gönderilemezse, kodu log'a yaz
            Log::critical('EMAIL_VERIFICATION_CODE_FALLBACK', [
                'user_id' => $user->id,
                'email' => $user->email,
                'verification_code' => $verificationCode,
                'token' => $token
            ]);
            
            return false;
        }
    }

    /**
     * Send reservation confirmation email
     */
    public function sendReservationConfirmation(Reservation $reservation): bool
    {
        try {
            $student = $reservation->student;
            $teacher = $reservation->teacher->user;
            
            Mail::send('emails.reservation-confirmation', [
                'reservation' => $reservation,
                'student' => $student,
                'teacher' => $teacher,
                'platformUrl' => config('app.frontend_url'),
            ], function ($message) use ($student) {
                $message->to($student->email, $student->name)
                    ->subject('Rezervasyon Onaylandı - Nazliyavuz Platform');
            });

            Log::info('Reservation confirmation sent', [
                'reservation_id' => $reservation->id,
                'student_email' => $student->email
            ]);
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to send reservation confirmation', [
                'reservation_id' => $reservation->id,
                'error' => $e->getMessage()
            ]);
            return false;
        }
    }

    /**
     * Send reservation reminder email
     */
    public function sendReservationReminder(Reservation $reservation): bool
    {
        try {
            $student = $reservation->student;
            $teacher = $reservation->teacher->user;
            
            Mail::send('emails.reservation-reminder', [
                'reservation' => $reservation,
                'student' => $student,
                'teacher' => $teacher,
                'platformUrl' => config('app.frontend_url'),
            ], function ($message) use ($student) {
                $message->to($student->email, $student->name)
                    ->subject('Rezervasyon Hatırlatması - Nazliyavuz Platform');
            });

            Log::info('Reservation reminder sent', [
                'reservation_id' => $reservation->id,
                'student_email' => $student->email
            ]);
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to send reservation reminder', [
                'reservation_id' => $reservation->id,
                'error' => $e->getMessage()
            ]);
            return false;
        }
    }

    /**
     * Send new rating notification email
     */
    public function sendNewRatingNotification(User $teacher, User $student, float $rating, string $comment = null): bool
    {
        try {
            Mail::send('emails.new-rating', [
                'teacher' => $teacher,
                'student' => $student,
                'rating' => $rating,
                'comment' => $comment,
                'platformUrl' => config('app.frontend_url'),
            ], function ($message) use ($teacher) {
                $message->to($teacher->email, $teacher->name)
                    ->subject('Yeni Değerlendirme Aldınız - Nazliyavuz Platform');
            });

            Log::info('New rating notification sent', [
                'teacher_id' => $teacher->id,
                'student_id' => $student->id,
                'rating' => $rating
            ]);
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to send new rating notification', [
                'teacher_id' => $teacher->id,
                'error' => $e->getMessage()
            ]);
            return false;
        }
    }

    /**
     * Send welcome email to new users
     */
    public function sendWelcomeEmail(User $user): bool
    {
        try {
            Mail::send('emails.welcome', [
                'user' => $user,
                'platformUrl' => config('app.frontend_url'),
            ], function ($message) use ($user) {
                $message->to($user->email, $user->name)
                    ->subject('Nazliyavuz Platform\'a Hoş Geldiniz!');
            });

            Log::info('Welcome email sent', ['user_id' => $user->id, 'email' => $user->email]);
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to send welcome email', [
                'user_id' => $user->id,
                'email' => $user->email,
                'error' => $e->getMessage()
            ]);
            return false;
        }
    }

    /**
     * Send bulk notification email
     */
    public function sendBulkNotification(array $recipients, string $subject, string $template, array $data = []): array
    {
        $results = [
            'success' => 0,
            'failed' => 0,
            'errors' => []
        ];

        foreach ($recipients as $recipient) {
            try {
                Mail::send($template, array_merge($data, ['user' => $recipient]), function ($message) use ($recipient, $subject) {
                    $message->to($recipient->email, $recipient->name)
                        ->subject($subject);
                });
                $results['success']++;
            } catch (\Exception $e) {
                $results['failed']++;
                $results['errors'][] = [
                    'email' => $recipient->email,
                    'error' => $e->getMessage()
                ];
            }
        }

        Log::info('Bulk notification sent', [
            'total' => count($recipients),
            'success' => $results['success'],
            'failed' => $results['failed']
        ]);

        return $results;
    }
    public function sendPasswordReset(User $user, string $token): bool
    {
        try {
            Mail::send('emails.password-reset', [
                'user' => $user,
                'token' => $token,
                'resetUrl' => config('app.frontend_url') . '/reset-password?token=' . $token . '&email=' . urlencode($user->email),
            ], function ($message) use ($user) {
                $message->to($user->email, $user->name)
                    ->subject('Şifre Sıfırlama - Nazliyavuz Platform');
            });

            Log::info('Password reset email sent', ['user_id' => $user->id, 'email' => $user->email]);
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to send password reset email', [
                'user_id' => $user->id,
                'email' => $user->email,
                'error' => $e->getMessage()
            ]);
            return false;
        }
    }

    /**
     * Send reservation notification to teacher
     */
    public function sendReservationNotification(Reservation $reservation): bool
    {
        try {
            $teacher = $reservation->teacher->user;
            $student = $reservation->student;

            Mail::send('emails.reservation-notification', [
                'reservation' => $reservation,
                'teacher' => $teacher,
                'student' => $student,
            ], function ($message) use ($teacher) {
                $message->to($teacher->email, $teacher->name)
                    ->subject('Yeni Rezervasyon Talebi - Nazliyavuz Platform');
            });

            Log::info('Reservation notification sent', [
                'reservation_id' => $reservation->id,
                'teacher_id' => $teacher->id,
                'teacher_email' => $teacher->email
            ]);
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to send reservation notification', [
                'reservation_id' => $reservation->id,
                'error' => $e->getMessage()
            ]);
            return false;
        }
    }

    /**
     * Send reservation status update to student
     */
    public function sendReservationStatusUpdate(Reservation $reservation): bool
    {
        try {
            $student = $reservation->student;
            $teacher = $reservation->teacher->user;

            Mail::send('emails.reservation-status-update', [
                'reservation' => $reservation,
                'student' => $student,
                'teacher' => $teacher,
            ], function ($message) use ($student) {
                $message->to($student->email, $student->name)
                    ->subject('Rezervasyon Durumu Güncellendi - Nazliyavuz Platform');
            });

            Log::info('Reservation status update sent', [
                'reservation_id' => $reservation->id,
                'student_id' => $student->id,
                'student_email' => $student->email
            ]);
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to send reservation status update', [
                'reservation_id' => $reservation->id,
                'error' => $e->getMessage()
            ]);
            return false;
        }
    }

    /**
     * Send rating notification to teacher
     */
    public function sendRatingNotification(User $teacher, User $student, int $rating, ?string $review = null): bool
    {
        try {
            Mail::send('emails.rating-notification', [
                'teacher' => $teacher,
                'student' => $student,
                'rating' => $rating,
                'review' => $review,
            ], function ($message) use ($teacher) {
                $message->to($teacher->email, $teacher->name)
                    ->subject('Yeni Değerlendirme Aldınız - Nazliyavuz Platform');
            });

            Log::info('Rating notification sent', [
                'teacher_id' => $teacher->id,
                'teacher_email' => $teacher->email,
                'rating' => $rating
            ]);
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to send rating notification', [
                'teacher_id' => $teacher->id,
                'error' => $e->getMessage()
            ]);
            return false;
        }
    }

    /**
     * Send reservation cancellation notification
     */
    public function sendReservationCancellation(Reservation $reservation): bool
    {
        try {
            $student = $reservation->student;
            $teacher = $reservation->teacher;

            // Send notification to student
            Mail::send('emails.reservation-cancelled', [
                'reservation' => $reservation,
                'teacher' => $teacher,
                'student' => $student,
                'isStudent' => true,
            ], function ($mail) use ($student) {
                $mail->to($student->email)
                    ->subject('Ders Rezervasyonunuz İptal Edildi - Nazliyavuz Platform');
            });

            // Send notification to teacher
            Mail::send('emails.reservation-cancelled', [
                'reservation' => $reservation,
                'teacher' => $teacher,
                'student' => $student,
                'isStudent' => false,
            ], function ($mail) use ($teacher) {
                $mail->to($teacher->email)
                    ->subject('Ders Rezervasyonu İptal Edildi - Nazliyavuz Platform');
            });

            Log::info('Reservation cancellation notifications sent', [
                'reservation_id' => $reservation->id,
                'student_id' => $student->id,
                'teacher_id' => $teacher->id,
            ]);

            return true;
        } catch (\Exception $e) {
            Log::error('Failed to send reservation cancellation notifications', [
                'reservation_id' => $reservation->id,
                'error' => $e->getMessage()
            ]);
            return false;
        }
    }

    /**
     * Send admin notification
     */
    public function sendAdminNotification(string $subject, string $message, array $data = []): bool
    {
        try {
            $adminEmail = config('mail.admin_email', 'admin@nazliyavuz.com');

            Mail::send('emails.admin-notification', [
                'subject' => $subject,
                'message' => $message,
                'data' => $data,
            ], function ($mail) use ($adminEmail, $subject) {
                $mail->to($adminEmail)
                    ->subject($subject . ' - Nazliyavuz Platform');
            });

            Log::info('Admin notification sent', ['subject' => $subject]);
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to send admin notification', [
                'subject' => $subject,
                'error' => $e->getMessage()
            ]);
            return false;
        }
    }
}
