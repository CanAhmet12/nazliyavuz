<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Payment;
use App\Models\Reservation;
use App\Models\User;
use App\Models\Category;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class AdminReservationManagementTest extends TestCase
{
    use RefreshDatabase;

    protected User $admin;
    protected User $teacher;
    protected User $student;
    protected Category $category;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = User::factory()->create(['role' => 'admin']);
        $this->teacher = User::factory()->create(['role' => 'teacher']);
        $this->student = User::factory()->create(['role' => 'student']);
        $this->category = Category::create([
            'name' => 'Test Category',
            'slug' => Str::slug('Test Category'),
            'description' => 'Unit test category',
            'is_active' => true,
        ]);

        config(['paytr.test_mode' => true]);

        Notification::fake();
    }

    /** @test */
    public function admin_can_update_reservation_status(): void
    {
        $reservation = Reservation::create([
            'student_id' => $this->student->id,
            'teacher_id' => $this->teacher->id,
            'category_id' => $this->category->id,
            'subject' => 'Matematik Dersi',
            'proposed_datetime' => Carbon::now()->addDays(2),
            'duration_minutes' => 60,
            'price' => 500,
            'status' => 'pending',
            'notes' => 'Öğrenci notu',
        ]);

        $response = $this->actingAs($this->admin)
            ->putJson("/api/v1/admin/reservations/{$reservation->id}/status", [
                'status' => 'accepted',
                'teacher_notes' => 'Öğretmen notu',
                'admin_notes' => 'Admin onayı',
                'notify_participants' => false,
            ]);

        $response->assertOk()
            ->assertJsonFragment([
                'success' => true,
                'status' => 'accepted',
            ])
            ->assertJsonPath('reservation.status', 'accepted');

        $reservation->refresh();

        $this->assertEquals('accepted', $reservation->status);
        $this->assertEquals('Öğretmen notu', $reservation->teacher_notes);

        if (Schema::hasColumn('reservations', 'admin_notes')) {
            $this->assertEquals('Admin onayı', $reservation->admin_notes);
        } else {
            $this->assertNull($reservation->admin_notes);
        }

        $this->assertDatabaseHas('audit_logs', [
            'action' => 'reservation_status_updated',
            'user_id' => $this->admin->id,
        ]);
    }

    /** @test */
    public function admin_can_process_manual_refund(): void
    {
        $reservation = Reservation::create([
            'student_id' => $this->student->id,
            'teacher_id' => $this->teacher->id,
            'category_id' => $this->category->id,
            'subject' => 'Kimya Dersi',
            'proposed_datetime' => Carbon::now()->addDays(3),
            'duration_minutes' => 60,
            'price' => 400,
            'status' => 'accepted',
            'payment_status' => 'paid',
        ]);

        Payment::create([
            'reservation_id' => $reservation->id,
            'user_id' => $this->student->id,
            'amount' => 400,
            'currency' => 'TRY',
            'status' => 'success',
            'payment_method' => 'credit_card',
            'paytr_order_id' => 'TEST_PAYTR_123',
            'paid_at' => now()->subDay(),
        ]);

        $response = $this->actingAs($this->admin)
            ->postJson("/api/v1/admin/reservations/{$reservation->id}/refund", [
                'refund_amount' => 150,
                'reason' => 'Öğrenci talebi',
                'notify_participants' => false,
                'cancel_reservation' => false,
            ]);

        $response->assertOk()
            ->assertJsonFragment([
                'success' => true,
                'status' => 'completed',
            ])
            ->assertJsonPath('reservation.payment_status', 'partial_refund')
            ->assertJsonPath('refund.status', 'completed')
            ->assertJsonPath('paytr.success', true);

        $reservation->refresh();

        $this->assertEquals('partial_refund', $reservation->payment_status);
        $this->assertEquals(150.0, (float) $reservation->refund_amount);
        $this->assertEquals('Öğrenci talebi', $reservation->refund_reason);

        $this->assertDatabaseHas('audit_logs', [
            'action' => 'reservation_refund_processed',
            'user_id' => $this->admin->id,
        ]);
    }

    /** @test */
    public function admin_can_handle_reschedule_request(): void
    {
        $oldDatetime = Carbon::now()->addDays(2);
        $newDatetime = Carbon::now()->addDays(3);

        $reservation = Reservation::create([
            'student_id' => $this->student->id,
            'teacher_id' => $this->teacher->id,
            'category_id' => $this->category->id,
            'subject' => 'Fizik Dersi',
            'proposed_datetime' => $oldDatetime,
            'duration_minutes' => 45,
            'price' => 350,
            'status' => 'accepted',
            'teacher_notes' => json_encode([
                'reschedule_request' => [
                    'type' => 'reschedule_request',
                    'requested_by' => $this->student->id,
                    'requested_at' => now()->toISOString(),
                    'old_datetime' => $oldDatetime->toISOString(),
                    'new_datetime' => $newDatetime->toISOString(),
                    'reason' => 'Öğrenci ailevi sebeplerden dolayı ertelemek istiyor',
                    'status' => 'pending',
                ],
            ], JSON_UNESCAPED_UNICODE),
        ]);

        $response = $this->actingAs($this->admin)
            ->postJson("/api/v1/admin/reservations/{$reservation->id}/reschedule", [
                'action' => 'approve',
                'notify_participants' => false,
            ]);

        $response->assertOk()
            ->assertJsonFragment([
                'success' => true,
                'status' => 'accepted',
            ])
            ->assertJsonPath('reservation.reschedule_request.status', 'approved');

        $reservation->refresh();

        $this->assertEquals($newDatetime->toDateTimeString(), $reservation->proposed_datetime->toDateTimeString());

        $this->assertDatabaseHas('audit_logs', [
            'action' => 'reservation_reschedule_handled',
            'user_id' => $this->admin->id,
        ]);
    }

    /** @test */
    public function admin_can_fetch_calendar_view(): void
    {
        $calendarDate = Carbon::now()->addDays(5)->setTime(14, 0);

        Reservation::create([
            'student_id' => $this->student->id,
            'teacher_id' => $this->teacher->id,
            'category_id' => $this->category->id,
            'subject' => 'Biyoloji Dersi',
            'proposed_datetime' => $calendarDate,
            'duration_minutes' => 90,
            'price' => 275,
            'status' => 'accepted',
        ]);

        $response = $this->actingAs($this->admin)
            ->getJson('/api/v1/admin/reservations/calendar?start_date=' . $calendarDate->copy()->subDay()->toDateString() . '&end_date=' . $calendarDate->copy()->addDay()->toDateString());

        $response->assertOk()
            ->assertJsonFragment([
                'success' => true,
                'count' => 1,
            ])
            ->assertJsonPath('reservations.0.status', 'accepted')
            ->assertJsonPath('reservations.0.duration_minutes', 90);
    }
}

