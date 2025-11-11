<?php

namespace App\Services;

use App\Models\Notification;
use App\Models\User;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

class NotificationService
{
    protected PushNotificationService $pushNotificationService;

    public function __construct(PushNotificationService $pushNotificationService)
    {
        $this->pushNotificationService = $pushNotificationService;
    }
    /**
     * Create a new notification
     */
    public function createNotification(User $user, string $type, string $title, string $message, array $data = [], string $actionUrl = null, string $actionText = null): Notification
    {
        try {
            $notification = Notification::create([
                'user_id' => $user->id,
                'type' => $type,
                'title' => $title,
                'message' => $message,
                'data' => $data,
                'action_url' => $actionUrl,
                'action_text' => $actionText,
            ]);

            Log::info('Notification created', [
                'user_id' => $user->id,
                'type' => $type,
                'title' => $title,
            ]);

            return $notification;
        } catch (\Exception $e) {
            Log::error('Failed to create notification', [
                'user_id' => $user->id,
                'type' => $type,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /**
     * Send notification to multiple users
     */
    public function sendBulkNotification(array $userIds, string $type, string $title, string $message, array $data = [], string $actionUrl = null, string $actionText = null): int
    {
        $count = 0;
        
        foreach ($userIds as $userId) {
            try {
                $user = User::find($userId);
                if ($user) {
                    $this->createNotification($user, $type, $title, $message, $data, $actionUrl, $actionText);
                    $count++;
                }
            } catch (\Exception $e) {
                Log::error('Failed to send bulk notification to user', [
                    'user_id' => $userId,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        Log::info('Bulk notification sent', [
            'total_users' => count($userIds),
            'successful' => $count,
            'type' => $type,
        ]);

        return $count;
    }

    /**
     * Send email notification
     */
    public function sendEmailNotification(User $user, string $subject, string $template, array $data = []): bool
    {
        try {
            Mail::send($template, $data, function ($message) use ($user, $subject) {
                $message->to($user->email, $user->name)
                        ->subject($subject);
            });

            Log::info('Email notification sent', [
                'user_id' => $user->id,
                'email' => $user->email,
                'subject' => $subject,
            ]);

            return true;
        } catch (\Exception $e) {
            Log::error('Failed to send email notification', [
                'user_id' => $user->id,
                'email' => $user->email,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    /**
     * Mark notification as read
     */
    public function markAsRead(Notification $notification): bool
    {
        try {
            $notification->markAsRead();
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to mark notification as read', [
                'notification_id' => $notification->id,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    /**
     * Mark all notifications as read for user
     */
    public function markAllAsRead(User $user): int
    {
        try {
            $count = Notification::where('user_id', $user->id)
                ->where('is_read', false)
                ->update([
                    'is_read' => true,
                    'read_at' => now(),
                ]);

            Log::info('All notifications marked as read', [
                'user_id' => $user->id,
                'count' => $count,
            ]);

            return $count;
        } catch (\Exception $e) {
            Log::error('Failed to mark all notifications as read', [
                'user_id' => $user->id,
                'error' => $e->getMessage(),
            ]);
            return 0;
        }
    }

    /**
     * Delete notification
     */
    public function deleteNotification(Notification $notification): bool
    {
        try {
            $notification->delete();
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to delete notification', [
                'notification_id' => $notification->id,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    /**
     * Get notification statistics for user
     */
    public function getStatistics(User $user): array
    {
        try {
            $total = Notification::where('user_id', $user->id)->count();
            $unread = Notification::where('user_id', $user->id)->where('is_read', false)->count();
            $read = $total - $unread;

            // Get notifications by type
            $byType = Notification::where('user_id', $user->id)
                ->selectRaw('type, COUNT(*) as count')
                ->groupBy('type')
                ->get()
                ->pluck('count', 'type');

            return [
                'total' => $total,
                'unread' => $unread,
                'read' => $read,
                'by_type' => $byType,
            ];
        } catch (\Exception $e) {
            Log::error('Failed to get notification statistics', [
                'user_id' => $user->id,
                'error' => $e->getMessage(),
            ]);
            return [
                'total' => 0,
                'unread' => 0,
                'read' => 0,
                'by_type' => [],
            ];
        }
    }

    /**
     * Send complete notification (in-app + push + email)
     * Tüm kanalları kontrol eder ve kullanıcı tercihlerine göre gönderir
     */
    public function sendCompleteNotification(
        User $user,
        string $type,
        string $title,
        string $message,
        array $data = [],
        string $actionUrl = null,
        string $actionText = null,
        bool $forcePush = false
    ): void {
        try {
            // 1. In-app notification oluştur (her zaman)
            $this->createNotification($user, $type, $title, $message, $data, $actionUrl, $actionText);

            // 2. Push notification gönder (kullanıcı tercihleri kontrol et)
            $preferences = $user->notification_preferences ?? [];
            $pushEnabled = $preferences['push_notifications'] ?? true;
            $typeEnabled = $preferences["{$type}_notifications"] ?? true;

            if ($forcePush || ($pushEnabled && $typeEnabled)) {
                $this->pushNotificationService->sendToUser($user, $title, $message, $data);
            }

            // 3. Email notification (belirli durumlarda)
            $emailEnabled = $preferences['email_notifications'] ?? false;
            $importantTypes = ['reservation_accepted', 'teacher_approved', 'assignment_graded'];
            
            if ($emailEnabled && in_array($type, $importantTypes)) {
                // Email gönder (mail configured ise)
                $this->sendEmailNotification($user, $title, 'emails.notification', [
                    'title' => $title,
                    'message' => $message,
                    'action_url' => $actionUrl,
                    'action_text' => $actionText,
                ]);
            }

            Log::info('Complete notification sent', [
                'user_id' => $user->id,
                'type' => $type,
                'title' => $title,
                'push_sent' => $pushEnabled && $typeEnabled,
                'email_sent' => $emailEnabled && in_array($type, $importantTypes),
            ]);

        } catch (\Exception $e) {
            Log::error('Failed to send complete notification', [
                'user_id' => $user->id,
                'type' => $type,
                'error' => $e->getMessage()
            ]);
        }
    }

    /**
     * Send video call notification
     */
    public function sendVideoCallNotification(int $receiverId, string $callerName, string $callType, string $callId): void
    {
        try {
            $user = User::find($receiverId);
            if (!$user) {
                Log::warning('Video call notification: User not found', ['receiver_id' => $receiverId]);
                return;
            }

            $title = "📞 Video Çağrısı";
            $message = "{$callerName} size bir " . ($callType === 'video' ? 'görüntülü' : 'sesli') . " arama gönderdi";
            
            $this->sendCompleteNotification(
                $user,
                'video_call',
                $title,
                $message,
                [
                    'call_id' => $callId,
                    'call_type' => $callType,
                    'caller_name' => $callerName,
                    'action' => 'video_call_invitation'
                ],
                "/video-call/{$callId}",
                "Çağrıyı Yanıtla",
                true // Force push (critical!)
            );

        } catch (\Exception $e) {
            Log::error('Failed to send video call notification', [
                'receiver_id' => $receiverId,
                'error' => $e->getMessage()
            ]);
        }
    }

    /**
     * Send reservation notifications
     */
    public function sendReservationCreatedNotification(User $teacher, User $student, $reservation): void
    {
        $title = "📚 Yeni Rezervasyon Talebi";
        $message = "{$student->name} size bir rezervasyon talebi gönderdi";
        
        $this->sendCompleteNotification(
            $teacher,
            'reservation',
            $title,
            $message,
            [
                'reservation_id' => $reservation->id,
                'student_name' => $student->name,
                'subject' => $reservation->subject,
                'date' => $reservation->proposed_datetime->format('d M Y H:i'),
            ],
            "/reservations/{$reservation->id}",
            "Rezervasyonu Görüntüle"
        );
    }

    public function sendReservationAcceptedNotification(User $student, User $teacher, $reservation): void
    {
        $title = "✅ Rezervasyon Onaylandı!";
        $message = "{$teacher->name} rezervasyonunuzu onayladı";
        
        $this->sendCompleteNotification(
            $student,
            'reservation',
            $title,
            $message,
            [
                'reservation_id' => $reservation->id,
                'teacher_name' => $teacher->name,
                'date' => $reservation->proposed_datetime->format('d M Y H:i'),
            ],
            "/reservations/{$reservation->id}",
            "Detayları Gör"
        );
    }

    public function sendReservationRejectedNotification(User $student, User $teacher, $reservation): void
    {
        $title = "❌ Rezervasyon Reddedildi";
        $message = "{$teacher->name} rezervasyonunuzu reddetti";
        
        $this->sendCompleteNotification(
            $student,
            'reservation',
            $title,
            $message,
            [
                'reservation_id' => $reservation->id,
                'teacher_name' => $teacher->name,
            ],
            "/teachers",
            "Başka Öğretmen Ara"
        );
    }

    /**
     * Send message notification
     */
    public function sendNewMessageNotification(User $receiver, User $sender, string $messageContent): void
    {
        $title = "💬 Yeni Mesaj";
        $preview = substr($messageContent, 0, 50) . (strlen($messageContent) > 50 ? '...' : '');
        $message = "{$sender->name}: {$preview}";
        
        $this->sendCompleteNotification(
            $receiver,
            'message',
            $title,
            $message,
            [
                'sender_id' => $sender->id,
                'sender_name' => $sender->name,
            ],
            "/chats",
            "Mesajı Oku"
        );
    }

    /**
     * Send assignment notifications
     */
    public function sendAssignmentCreatedNotification(User $student, User $teacher, $assignment): void
    {
        $title = "📝 Yeni Ödev";
        $message = "{$teacher->name} size bir ödev atadı: {$assignment->title}";
        
        $this->sendCompleteNotification(
            $student,
            'assignment',
            $title,
            $message,
            [
                'assignment_id' => $assignment->id,
                'teacher_name' => $teacher->name,
                'title' => $assignment->title,
                'due_date' => $assignment->due_date?->format('d M Y'),
            ],
            "/assignments/{$assignment->id}",
            "Ödevi Görüntüle"
        );
    }

    public function sendAssignmentGradedNotification(User $student, $assignment, $grade, $feedback): void
    {
        $title = "⭐ Ödev Notlandırıldı";
        $message = "'{$assignment->title}' ödeviniz notlandırıldı. Notunuz: {$grade}";
        
        $this->sendCompleteNotification(
            $student,
            'assignment',
            $title,
            $message,
            [
                'assignment_id' => $assignment->id,
                'grade' => $grade,
                'feedback' => $feedback,
            ],
            "/assignments/{$assignment->id}",
            "Notu Görüntüle"
        );
    }

    /**
     * Send assignment submitted notification to teacher
     */
    public function sendAssignmentSubmittedNotification(User $teacher, User $student, $assignment): void
    {
        $title = "📤 Ödev Teslim Edildi";
        $message = "{$student->name}, '{$assignment->title}' ödevini teslim etti";
        
        $this->sendCompleteNotification(
            $teacher,
            'assignment',
            $title,
            $message,
            [
                'assignment_id' => $assignment->id,
                'student_id' => $student->id,
                'student_name' => $student->name,
            ],
            "/assignments/{$assignment->id}",
            "Ödevi İncele"
        );
    }

    /**
     * Send reservation completed notification
     */
    public function sendReservationCompletedNotification(User $recipient, User $otherParty, $reservation, string $recipientRole): void
    {
        $title = "✅ Ders Tamamlandı";
        
        if ($recipientRole === 'student') {
            $message = "'{$reservation->subject}' dersiniz tamamlandı. Öğretmeninizi değerlendirin!";
        } else {
            $message = "'{$reservation->subject}' dersiniz tamamlandı.";
        }
        
        $this->sendCompleteNotification(
            $recipient,
            'reservation',
            $title,
            $message,
            [
                'reservation_id' => $reservation->id,
                'subject' => $reservation->subject,
                'completed_at' => now()->toISOString(),
            ],
            "/reservations/{$reservation->id}",
            $recipientRole === 'student' ? "Değerlendir" : "Detay Gör"
        );
    }

    /**
     * Send reservation cancelled notification
     */
    public function sendReservationCancelledNotification(User $recipient, User $canceller, $reservation): void
    {
        $title = "🚫 Ders İptal Edildi";
        $message = "{$canceller->name}, '{$reservation->subject}' dersini iptal etti";
        
        $this->sendCompleteNotification(
            $recipient,
            'reservation',
            $title,
            $message,
            [
                'reservation_id' => $reservation->id,
                'cancelled_by' => $canceller->name,
                'subject' => $reservation->subject,
            ],
            "/reservations",
            "Rezervasyonları Görüntüle"
        );
    }

    /**
     * Send reservation reminder notification
     */
    public function sendReservationReminderNotification(User $recipient, $reservation): void
    {
        $title = "⏰ Ders Hatırlatması";
        $subject = $reservation->subject ?? 'Rezervasyon';
        $date = $reservation->proposed_datetime instanceof \DateTimeInterface
            ? $reservation->proposed_datetime->format('d M Y H:i')
            : null;

        $message = "'{$subject}' dersiniz yaklaşıyor.";

        $this->sendCompleteNotification(
            $recipient,
            'reservation',
            $title,
            $message,
            array_filter([
                'reservation_id' => $reservation->id,
                'subject' => $subject,
                'date' => $date,
            ], fn ($value) => $value !== null),
            "/reservations/{$reservation->id}",
            "Detayları Gör"
        );
    }

    /**
     * Send rating request notification
     */
    public function sendRatingRequestNotification(User $student, User $teacher, $reservation): void
    {
        $title = "⭐ Öğretmeninizi Değerlendirin";
        $message = "'{$reservation->subject}' dersi için {$teacher->name} öğretmeninizi değerlendirin";
        
        $this->sendCompleteNotification(
            $student,
            'rating',
            $title,
            $message,
            [
                'reservation_id' => $reservation->id,
                'teacher_id' => $teacher->id,
                'teacher_name' => $teacher->name,
            ],
            "/teachers/{$teacher->id}/rate",
            "Değerlendir"
        );
    }

    /**
     * Send lesson reminder (1 hour before)
     */
    public function sendLessonReminderNotification(User $user, $lesson, int $minutesBefore): void
    {
        $title = "⏰ Ders Hatırlatması";
        $message = "Dersianız {$minutesBefore} dakika sonra başlayacak!";
        
        $this->sendCompleteNotification(
            $user,
            'lesson',
            $title,
            $message,
            [
                'lesson_id' => $lesson->id,
                'reservation_id' => $lesson->reservation_id,
                'minutes_before' => $minutesBefore,
            ],
            "/lessons/{$lesson->id}",
            "Derse Hazırlan",
            true // Force push (critical reminder!)
        );
    }

    /**
     * Send teacher approval notification
     */
    public function sendTeacherApprovedNotification(User $teacher, $approvedBy): void
    {
        $title = "🎉 Profiliniz Onaylandı!";
        $message = "Tebrikler! Öğretmen profiliniz onaylandı. Artık ders verebilirsiniz.";
        
        $this->sendCompleteNotification(
            $teacher,
            'teacher',
            $title,
            $message,
            [
                'approved_by' => $approvedBy->name,
                'approved_at' => now()->toISOString(),
            ],
            "/teacher/profile",
            "Profilimi Görüntüle",
            true // Important!
        );
    }

    public function sendTeacherRejectedNotification(User $teacher, string $reason): void
    {
        $title = "❌ Profil İncelemesi";
        $message = "Öğretmen başvurunuz reddedildi. Sebep: {$reason}";
        
        $this->sendCompleteNotification(
            $teacher,
            'teacher',
            $title,
            $message,
            [
                'reason' => $reason,
            ],
            "/teacher/profile",
            "Profili Düzenle"
        );
    }

    /**
     * Clean up old notifications
     */
    public function cleanupOldNotifications(int $daysOld = 30): int
    {
        try {
            $count = Notification::where('created_at', '<', now()->subDays($daysOld))
                ->where('is_read', true)
                ->delete();

            Log::info('Old notifications cleaned up', [
                'count' => $count,
                'days_old' => $daysOld,
            ]);

            return $count;
        } catch (\Exception $e) {
            Log::error('Failed to cleanup old notifications', [
                'error' => $e->getMessage(),
            ]);
            return 0;
        }
    }
}
