<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->string('bio', 500)->nullable();
        });

        Schema::create('conversations', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_low_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('user_high_id')->constrained('users')->cascadeOnDelete();
            $table->timestamps();
            $table->unique(['user_low_id', 'user_high_id']);
            $table->index(['user_high_id', 'updated_at']);
            $table->index(['user_low_id', 'updated_at']);
        });

        Schema::create('messages', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('conversation_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sender_id')->constrained('users')->cascadeOnDelete();
            $table->uuid('client_id');
            $table->text('body');
            $table->timestamps();
            $table->unique(['sender_id', 'client_id']);
            $table->index(['conversation_id', 'id']);
        });

        Schema::create('user_reports', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('reporter_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('reported_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('reason', 40);
            $table->string('details', 1000)->nullable();
            $table->timestamps();
            $table->index(['reported_user_id', 'created_at']);
            $table->index(['reporter_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_reports');
        Schema::dropIfExists('messages');
        Schema::dropIfExists('conversations');
        Schema::table('users', function (Blueprint $table): void {
            $table->dropColumn('bio');
        });
    }
};
