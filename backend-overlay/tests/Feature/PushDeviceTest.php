<?php

namespace Tests\Feature;

use App\Jobs\SendMessagePush;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class PushDeviceTest extends TestCase
{
    use RefreshDatabase;

    public function test_device_tokens_are_session_bound_encrypted_and_removed_when_session_expires(): void
    {
        $user = User::factory()->create(['email_verified_at' => now()]);
        $token = $user->createToken('phone')->plainTextToken;
        $this->withToken($token);

        $deviceToken = str_repeat('fcm-token:', 15);
        $this->putJson('/api/v1/push/devices', [
            'token' => $deviceToken, 'platform' => 'ios', 'locale' => 'de',
        ])->assertOk();
        $this->putJson('/api/v1/push/devices', [
            'token' => $deviceToken, 'platform' => 'ios', 'locale' => 'fr',
        ])->assertOk();
        $this->assertDatabaseCount('push_devices', 1);
        $row = DB::table('push_devices')->first();
        $this->assertSame('fr', $row->locale);
        $this->assertNotSame($deviceToken, $row->token_ciphertext);
        $this->assertSame($deviceToken, Crypt::decryptString($row->token_ciphertext));

        $this->postJson('/api/v1/auth/logout')->assertOk();
        $this->assertDatabaseCount('push_devices', 0);
    }

    public function test_device_registration_requires_real_authenticated_verified_session(): void
    {
        $payload = ['token' => str_repeat('abc', 30), 'platform' => 'android', 'locale' => 'en'];
        $this->putJson('/api/v1/push/devices', $payload)->assertUnauthorized();

        $user = User::factory()->create(['email_verified_at' => null]);
        $this->withToken($user->createToken('phone')->plainTextToken);
        $this->putJson('/api/v1/push/devices', $payload)->assertForbidden();
        $this->assertDatabaseCount('push_devices', 0);
    }

    public function test_new_message_enqueues_push_once_without_replay_or_blocked_delivery(): void
    {
        Bus::fake([SendMessagePush::class]);
        $sender = User::factory()->create();
        $recipient = User::factory()->create();
        $id = DB::table('conversations')->insertGetId([
            'user_low_id' => min($sender->id, $recipient->id),
            'user_high_id' => max($sender->id, $recipient->id),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->actingAs($sender, 'sanctum');
        $payload = ['client_id' => (string) Str::uuid(), 'body' => 'message'];
        $this->postJson("/api/v1/conversations/$id/messages", $payload)->assertCreated();
        $this->postJson("/api/v1/conversations/$id/messages", $payload)->assertOk();
        Bus::assertDispatchedTimes(SendMessagePush::class, 1);
    }
}
