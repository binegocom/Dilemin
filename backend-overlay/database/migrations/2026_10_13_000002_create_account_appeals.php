<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('account_appeals', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->timestamp('suspended_at');
            $table->string('status', 16)->default('pending')->index();
            $table->text('statement');
            $table->string('review_note', 500)->nullable();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamps();
            // Exactly one appeal per suspension, including rejected decisions.
            $table->unique(['user_id', 'suspended_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('account_appeals');
    }
};
