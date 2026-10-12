<?php

namespace Tests\Feature;

use App\Jobs\SendMessagePush;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class PushDeliveryGuardTest extends TestCase
{
    use RefreshDatabase;

    private function createMessage(User $sender, User $recipient): array
    {
        $low = min($sender->id, $recipient->id);
        $high = max($sender->id, $recipient->id);
        $conversationId = DB::table('conversations')->insertGetId([
            'user_low_id' => $low,
            'user_high_id' => $high,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $messageId = DB::table('messages')->insertGetId([
            'conversation_id' => $conversationId,
            'sender_id' => $sender->id,
            'client_id' => (string) Str::uuid(),
            'body' => 'The private message must never appear in push metadata',
            'created_at' => now(), 'updated_at' => now(),
        ]);

        return [$conversationId, $messageId, $recipient->id === $low
            ? 'last_read_low_message_id' : 'last_read_high_message_id'];
    }

    private function registerDevice(User $recipient, bool $expired = false): void
    {
        $session = $recipient->createToken('phone')->accessToken;
        if ($expired) {
            DB::table('personal_access_tokens')->where('id', $session->id)
                ->update(['expires_at' => now()->subMinute()]);
        }
        DB::table('push_devices')->insert([
            'user_id' => $recipient->id,
            'personal_access_token_id' => $session->id,
            'token_hash' => hash('sha256', 'device-token-for-tests-'.$session->id),
            'token_ciphertext' => Crypt::encryptString('device-token-for-tests-'.$session->id),
            'platform' => 'android',
            'locale' => 'en',
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    public function test_already_read_message_never_needs_firebase_credentials(): void
    {
        $sender = User::factory()->create(['email_verified_at' => now()]);
        $recipient = User::factory()->create(['email_verified_at' => now()]);
        [$conversationId, $messageId, $field] = $this->createMessage($sender, $recipient);
        $this->registerDevice($recipient);
        DB::table('conversations')->where('id', $conversationId)
            ->update([$field => $messageId]);

        config(['dilemin.firebase_credentials' => null]);
        (new SendMessagePush($messageId))->handle();

        $this->assertDatabaseCount('push_devices', 1);
    }

    public function test_expired_session_is_not_considered_a_push_destination(): void
    {
        $sender = User::factory()->create(['email_verified_at' => now()]);
        $recipient = User::factory()->create(['email_verified_at' => now()]);
        [, $messageId] = $this->createMessage($sender, $recipient);
        $this->registerDevice($recipient, true);

        config(['dilemin.firebase_credentials' => null]);
        (new SendMessagePush($messageId))->handle();

        $this->assertDatabaseCount('push_devices', 1);
    }

    public function test_blocked_conversation_never_attempts_push_delivery(): void
    {
        $sender = User::factory()->create(['email_verified_at' => now()]);
        $recipient = User::factory()->create(['email_verified_at' => now()]);
        [, $messageId] = $this->createMessage($sender, $recipient);
        $this->registerDevice($recipient);
        DB::table('blocks')->insert([
            'blocker_id' => $recipient->id,
            'blocked_id' => $sender->id,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        config(['dilemin.firebase_credentials' => null]);
        (new SendMessagePush($messageId))->handle();
        $this->assertDatabaseCount('push_devices', 1);
    }
}
