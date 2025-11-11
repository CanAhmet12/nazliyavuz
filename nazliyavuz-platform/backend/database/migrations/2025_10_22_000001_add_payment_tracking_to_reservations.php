<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('reservations', function (Blueprint $table) {
            // Payment tracking
            $table->enum('payment_status', ['unpaid', 'paid', 'refunded', 'partial_refund'])->default('unpaid')->after('price');
            $table->enum('payment_method', ['credit_card', 'bank_transfer', 'cash', 'wallet'])->nullable()->after('payment_status');
            $table->string('payment_transaction_id')->nullable()->after('payment_method');
            $table->timestamp('paid_at')->nullable()->after('payment_transaction_id');
            
            // Refund tracking
            $table->decimal('refund_amount', 8, 2)->nullable()->after('paid_at');
            $table->text('refund_reason')->nullable()->after('refund_amount');
            $table->timestamp('refunded_at')->nullable()->after('refund_reason');
            
            // Cancellation tracking
            $table->foreignId('cancelled_by_id')->nullable()->after('refunded_at')->constrained('users')->onDelete('set null');
            $table->text('cancelled_reason')->nullable()->after('cancelled_by_id');
            $table->timestamp('cancelled_at')->nullable()->after('cancelled_reason');
            $table->decimal('cancellation_fee', 8, 2)->default(0.00)->after('cancelled_at');
            
            // Reminder tracking
            $table->boolean('reminder_sent')->default(false)->after('cancellation_fee');
            $table->timestamp('reminder_sent_at')->nullable()->after('reminder_sent');
            $table->tinyInteger('reminder_count')->default(0)->after('reminder_sent_at');
            
            // Rating link
            $table->foreignId('rating_id')->nullable()->after('reminder_count')->constrained('ratings')->onDelete('set null');
            $table->timestamp('rated_at')->nullable()->after('rating_id');
            $table->timestamp('rating_requested_at')->nullable()->after('rated_at');
            
            // Indexes
            $table->index('payment_status');
            $table->index(['teacher_id', 'status', 'proposed_datetime']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('reservations', function (Blueprint $table) {
            $table->dropColumn([
                'payment_status',
                'payment_method',
                'payment_transaction_id',
                'paid_at',
                'refund_amount',
                'refund_reason',
                'refunded_at',
                'cancelled_by_id',
                'cancelled_reason',
                'cancelled_at',
                'cancellation_fee',
                'reminder_sent',
                'reminder_sent_at',
                'reminder_count',
                'rating_id',
                'rated_at',
                'rating_requested_at',
            ]);
        });
    }
};

