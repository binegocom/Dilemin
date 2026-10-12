<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('user_reports', function (Blueprint $table): void {
            $table->string('status', 16)->default('pending')->index();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->string('review_note', 500)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('user_reports', function (Blueprint $table): void {
            $table->dropForeign(['reviewed_by']);
            $table->dropColumn(['status', 'reviewed_by', 'reviewed_at', 'review_note']);
        });
    }
};
