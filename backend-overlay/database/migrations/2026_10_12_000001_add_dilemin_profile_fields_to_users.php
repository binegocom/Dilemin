<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->date('date_of_birth')->nullable();
            $table->boolean('online_visible')->default(false)->index();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropIndex(['online_visible']);
            $table->dropColumn(['date_of_birth', 'online_visible']);
        });
    }
};
