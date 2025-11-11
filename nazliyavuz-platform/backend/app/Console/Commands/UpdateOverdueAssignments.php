<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Assignment;
use Illuminate\Support\Facades\Log;

class UpdateOverdueAssignments extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'assignments:update-overdue';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Update pending assignments to overdue status if past due date';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $this->info('🔄 Checking for overdue assignments...');

        try {
            // Find all pending assignments that are past their due date
            $overdueAssignments = Assignment::where('status', 'pending')
                ->where('due_date', '<', now())
                ->get();

            $count = $overdueAssignments->count();

            if ($count === 0) {
                $this->info('✅ No overdue assignments found.');
                return Command::SUCCESS;
            }

            // Update each assignment to overdue status
            foreach ($overdueAssignments as $assignment) {
                $assignment->update(['status' => 'overdue']);
                
                $this->line("   📌 Assignment #{$assignment->id} - {$assignment->title} → overdue");
                
                Log::info('Assignment marked as overdue', [
                    'assignment_id' => $assignment->id,
                    'title' => $assignment->title,
                    'due_date' => $assignment->due_date,
                    'student_id' => $assignment->student_id,
                ]);
            }

            $this->info("✅ Updated {$count} assignment(s) to overdue status.");
            
            Log::info('Overdue assignments updated', [
                'count' => $count,
                'timestamp' => now()->toDateTimeString()
            ]);

            return Command::SUCCESS;

        } catch (\Exception $e) {
            $this->error('❌ Error updating overdue assignments: ' . $e->getMessage());
            
            Log::error('Failed to update overdue assignments', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            return Command::FAILURE;
        }
    }
}

