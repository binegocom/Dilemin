<?php

namespace Tests\Feature;

use App\Models\User;
use App\Notifications\PasswordRecoveryCode;
use App\Support\PresenceStore;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class PasswordRecoveryTest extends TestCase
{
    use RefreshDatabase;

    public function test_unknown_email_returns_generic_response_without_creating_codes(): void
    {
        Notification::fake();
        $this->postJson('/api/v1/auth/password/request', [
            'email' => 'unknown@example.org', 'locale' => 'de',
        ])->assertOk()->assertExactJson(['status' => 'accepted']);
        $this->assertDatabaseCount('password_recovery_codes', 0);
        Notification::assertNothingSent();
    }

    public function test_code_is_hash_stored_and_cooldown_prevents_repeat_email(): void
    {
        Notification::fake();
        $user = User::factory()->create(['email' => 'reset@example.org']);
        $body = ['email' => $user->email, 'locale' => 'fr'];
        $this->postJson('/api/v1/auth/password/request', $body)
            ->assertOk()->assertJsonPath('status', 'accepted');
        Notification::assertSentTo($user, PasswordRecoveryCode::class);
        $this->assertDatabaseCount('password_recovery_codes', 1);
        $row = DB::table('password_recovery_codes')->where('user_id', $user->id)->first();
        $this->assertNotNull($row);
        $this->assertNotSame('123456', $row->code_hash);

        // The same generic response does not reveal the cooldown or account state.
        $this->postJson('/api/v1/auth/password/request', $body)
            ->assertOk()->assertExactJson(['status' => 'accepted']);
        Notification::assertCount(1);
    }

    public function test_successful_reset_revokes_all_tokens_and_rejects_old_password(): void
    {
        $user = User::factory()->create([
            'email' => 'recovery@example.org',
            'password' => 'original-password-2026',
            'date_of_birth' => now()->subYears(25)->toDateString(),
        ]);
        $user->createToken('phone')->plainTextToken;
        $user->createToken('tablet')->plainTextToken;
        DB::table('password_recovery_codes')->insert([
            'user_id' => $user->id,
            'code_hash' => Hash::make('123456'), 'attempts' => 0,
            'expires_at' => now()->addMinutes(10), 'last_sent_at' => now(),
        ]);
        $this->mock(PresenceStore::class)->shouldReceive('markOffline')->once()->with($user->id);
        $this->postJson('/api/v1/auth/password/confirm', [
            'email' => $user->email,
            'code' => '123456',
            'password' => 'replacement-password-2026',
        ])->assertOk()->assertExactJson(['status' => 'updated']);
        $this->assertTrue(Hash::check('replacement-password-2026', $user->fresh()->password));
        $this->assertDatabaseCount('personal_access_tokens', 0);
        $this->assertDatabaseCount('password_recovery_codes', 0);
        $this->postJson('/api/v1/auth/login', [
            'email' => $user->email, 'password' => 'original-password-2026',
        ])->assertUnprocessable();
        $this->postJson('/api/v1/auth/login', [
            'email' => $user->email, 'password' => 'replacement-password-2026',
        ])->assertOk()->assertJsonStructure(['token']);
    }

    public function test_five_wrong_codes_lock_the_challenge(): void
    {
        $user = User::factory()->create();
        DB::table('password_recovery_codes')->insert([
            'user_id' => $user->id, 'code_hash' => Hash::make('123456'),
            'attempts' => 0, 'expires_at' => now()->addMinutes(10),
            'last_sent_at' => now(),
        ]);
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/v1/auth/password/confirm', [
                'email' => $user->email, 'code' => '999999',
                'password' => 'changed-password-2026',
            ])->assertUnprocessable();
        }
        $this->postJson('/api/v1/auth/password/confirm', [
            'email' => $user->email, 'code' => '123456',
            'password' => 'changed-password-2026',
        ])->assertStatus(429);
        $this->assertSame(5, (int) DB::table('password_recovery_codes')->where('user_id', $user->id)->value('attempts'));
    }
}
