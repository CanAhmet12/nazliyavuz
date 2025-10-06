<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Payment extends Model
{
    use HasFactory;

    protected $fillable = [
        'reservation_id',
        'user_id',
        'amount',
        'currency',
        'paytr_order_id',
        'paytr_token',
        'status',
        'payment_method',
        'transaction_id',
        'description',
        'paid_at',
        'failed_at',
        'payment_data',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'paid_at' => 'datetime',
            'failed_at' => 'datetime',
            'payment_data' => 'array',
        ];
    }

    /**
     * Get the reservation that owns the payment
     */
    public function reservation()
    {
        return $this->belongsTo(Reservation::class);
    }

    /**
     * Get the user who made the payment
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Scope for successful payments
     */
    public function scopeSuccessful($query)
    {
        return $query->where('status', 'success');
    }

    /**
     * Scope for failed payments
     */
    public function scopeFailed($query)
    {
        return $query->where('status', 'failed');
    }

    /**
     * Scope for pending payments
     */
    public function scopePending($query)
    {
        return $query->where('status', 'pending');
    }

    /**
     * Scope for processing payments
     */
    public function scopeProcessing($query)
    {
        return $query->where('status', 'processing');
    }

    /**
     * Scope for refunded payments
     */
    public function scopeRefunded($query)
    {
        return $query->where('status', 'refunded');
    }

    /**
     * Check if payment is successful
     */
    public function isSuccessful(): bool
    {
        return $this->status === 'success';
    }

    /**
     * Check if payment is failed
     */
    public function isFailed(): bool
    {
        return $this->status === 'failed';
    }

    /**
     * Check if payment is pending
     */
    public function isPending(): bool
    {
        return $this->status === 'pending';
    }

    /**
     * Check if payment is processing
     */
    public function isProcessing(): bool
    {
        return $this->status === 'processing';
    }

    /**
     * Get formatted amount
     */
    public function getFormattedAmountAttribute(): string
    {
        return number_format((float) $this->amount, 2) . ' ' . $this->currency;
    }

    /**
     * Get payment status in Turkish
     */
    public function getStatusInTurkishAttribute(): string
    {
        $statuses = [
            'pending' => 'Bekliyor',
            'processing' => 'İşleniyor',
            'success' => 'Başarılı',
            'failed' => 'Başarısız',
            'cancelled' => 'İptal Edildi',
            'refunded' => 'İade Edildi',
        ];

        return $statuses[$this->status] ?? $this->status;
    }

    /**
     * Get payment method in Turkish
     */
    public function getPaymentMethodInTurkishAttribute(): string
    {
        $methods = [
            'credit_card' => 'Kredi Kartı',
            'debit_card' => 'Banka Kartı',
            'bank_transfer' => 'Banka Havalesi',
            'cash' => 'Nakit',
            'other' => 'Diğer',
        ];

        return $methods[$this->payment_method] ?? $this->payment_method ?? 'Bilinmiyor';
    }

    /**
     * Get time since payment
     */
    public function getTimeSinceAttribute(): string
    {
        if ($this->paid_at) {
            return $this->paid_at->diffForHumans();
        }

        return $this->created_at->diffForHumans();
    }
}
