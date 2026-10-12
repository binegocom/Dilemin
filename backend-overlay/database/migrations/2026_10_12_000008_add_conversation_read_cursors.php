<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('conversations', function (Blueprint $table): void {
            $table->unsignedBigInteger('last_read_low_message_id')->nullable();
            $table->unsignedBigInteger('last_read_high_message_id')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('conversations', function (Blueprint $table): void {
            $table->dropColumn(['last_read_low_message_id', 'last_read_high_message_id']);
        });
    }
};
