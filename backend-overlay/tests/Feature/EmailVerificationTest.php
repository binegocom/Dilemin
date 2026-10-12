<?php

namespace Tests\Feature;

use App\Models\User;
use App\Support\PresenceStore;
use App\Notifications\EmailVerificationCode;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class EmailVerificationTest extends TestCase
{
    use RefreshDatabase;

    public function test_new_registration_is_unverified_and_gated_from_discovery(): void
    {
        $this->postJson('/api/v1/auth/register', [
            'display_name' => 'Taylor', 'email' => 'taylor@example.org',
            'password' => 'good-password-longer-than-twelve',
            'date_of_birth' => now()->subYears(25)->toDateString(),
        ])->assertCreated()->assertJsonPath('user.email_verified', false);
        $user = User::where('email', 'taylor@example.org')->firstOrFail();
        $this->actingAs($user, 'sanctum')->getJson('/api/v1/discovery/online')->assertForbidden();
        $this->postJson('/api/v1/presence/heartbeat')->assertForbidden();
    }

    public function test_code_delivery_cooldown_and_confirmation_unlocks_social_api(): void
    {
        Notification::fake();
        $user = User::factory()->create(['email_verified_at' => null, 'online_visible' => false]);
        $this->actingAs($user, 'sanctum');
        $this->postJson('/api/v1/auth/email/request', ['locale' => 'de'])->assertOk();
        Notification::assertSentTo($user, EmailVerificationCode::class);
        $this->postJson('/api/v1/auth/email/request', ['locale' => 'de'])->assertStatus(429);
        $this->assertDatabaseCount('email_verification_codes', 1);

        // The code is hashed at rest; tests set a known hash without changing production code.
        DB::table('email_verification_codes')->where('user_id', $user->id)
            ->update(['code_hash' => Hash::make('123456')]);
        $this->postJson('/api/v1/auth/email/confirm', ['code' => '999999'])
            ->assertUnprocessable();
        $this->postJson('/api/v1/auth/email/confirm', ['code' => '123456'])
            ->assertOk()->assertJsonPath('user.email_verified', true);
        $this->mock(PresenceStore::class)->shouldReceive('onlineIds')->once()->andReturn([]);
        // actingAs reuses the in-memory model; a real Sanctum request reloads it.
        $this->actingAs($user->fresh(), 'sanctum');
        $this->getJson('/api/v1/discovery/online')->assertOk();
        $this->assertDatabaseCount('email_verification_codes', 0);
    }

    public function test_five_invalid_codes_lock_challenge(): void
    {
        $user = User::factory()->create(['email_verified_at' => null]);
        DB::table('email_verification_codes')->insert([
            'user_id' => $user->id, 'code_hash' => Hash::make('123456'),
            'attempts' => 0, 'expires_at' => now()->addMinutes(10), 'last_sent_at' => now(),
        ]);
        $this->actingAs($user, 'sanctum');
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/v1/auth/email/confirm', ['code' => '999999'])->assertUnprocessable();
        }
        $this->postJson('/api/v1/auth/email/confirm', ['code' => '123456'])->assertStatus(429);
        $this->assertNull($user->fresh()->email_verified_at);
    }
}
