<?php

namespace Tests\Feature;

use App\Jobs\SendMessagePush;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class NotificationPreferenceTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_disable_and_enable_own_notifications_only(): void
    {
        $owner = User::factory()->create(['email_verified_at' => now()]);
        $other = User::factory()->create(['email_verified_at' => now()]);

        $this->patchJson('/api/v1/account/notifications', [
            'push_messages_enabled' => false,
        ])->assertUnauthorized();

        $this->actingAs($owner, 'sanctum');
        $this->patchJson('/api/v1/account/notifications', [
            'push_messages_enabled' => 'not-a-boolean',
        ])->assertUnprocessable();

        $this->patchJson('/api/v1/account/notifications', [
            'push_messages_enabled' => false,
        ])->assertOk()->assertJsonPath('user.push_messages_enabled', false);
        $this->getJson('/api/v1/auth/me')
            ->assertOk()->assertJsonPath('user.push_messages_enabled', false);
        $this->assertDatabaseHas('users', [
            'id' => $owner->id,
            'push_messages_enabled' => false,
        ]);
        $this->assertDatabaseHas('users', [
            'id' => $other->id,
            'push_messages_enabled' => true,
        ]);

        $this->patchJson('/api/v1/account/notifications', [
            'push_messages_enabled' => true,
        ])->assertOk()->assertJsonPath('user.push_messages_enabled', true);
    }

    public function test_disabled_preference_skips_delivery_even_with_registered_device(): void
    {
        $sender = User::factory()->create(['email_verified_at' => now()]);
        $recipient = User::factory()->create([
            'email_verified_at' => now(),
            'push_messages_enabled' => false,
        ]);
        $session = $recipient->createToken('phone')->accessToken;
        DB::table('push_devices')->insert([
            'user_id' => $recipient->id,
            'personal_access_token_id' => $session->id,
            'token_hash' => hash('sha256', 'push-preference-device'),
            'token_ciphertext' => Crypt::encryptString('push-preference-device'),
            'platform' => 'ios',
            'locale' => 'de',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $conversation = DB::table('conversations')->insertGetId([
            'user_low_id' => min($sender->id, $recipient->id),
            'user_high_id' => max($sender->id, $recipient->id),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $message = DB::table('messages')->insertGetId([
            'conversation_id' => $conversation,
            'sender_id' => $sender->id,
            'client_id' => (string) Str::uuid(),
            'body' => 'Private',
            'created_at' => now(), 'updated_at' => now(),
        ]);
        config(['dilemin.firebase_credentials' => null]);

        // No credentials error: the preference is enforced before FCM setup.
        (new SendMessagePush($message))->handle();
        $this->assertDatabaseCount('push_devices', 1);
    }
}
