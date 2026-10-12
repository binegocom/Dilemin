<?php

namespace Tests\Feature;

use App\Events\ConversationMessageCreated;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Str;
use Tests\TestCase;

class RealtimeMessageTest extends TestCase
{
    use RefreshDatabase;

    public function test_message_event_is_unique_for_idempotent_retries_and_excludes_private_text(): void
    {
        Event::fake([ConversationMessageCreated::class]);
        $first = User::factory()->create();
        $second = User::factory()->create();
        $conversationId = DB::table('conversations')->insertGetId([
            'user_low_id' => min($first->id, $second->id),
            'user_high_id' => max($first->id, $second->id),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->actingAs($first, 'sanctum');
        $data = ['body' => 'Sensitive text', 'client_id' => (string) Str::uuid()];
        $url = "/api/v1/conversations/{$conversationId}/messages";
        $this->postJson($url, $data)->assertCreated();
        $this->postJson($url, $data)->assertOk();

        Event::assertDispatchedTimes(ConversationMessageCreated::class, 1);
        Event::assertDispatched(ConversationMessageCreated::class, function ($event) use ($first, $second, $conversationId): bool {
            $channels = array_map(fn ($channel) => $channel->name, $event->broadcastOn());
            return $event->conversationId === $conversationId
                && $event->senderId === $first->id
                && $event->recipientId === $second->id
                && in_array("private-conversations.$conversationId", $channels, true)
                && in_array("private-users.{$second->id}", $channels, true)
                && ! str_contains(json_encode($event->broadcastWith()), 'Sensitive text');
        });
    }

    public function test_blocked_message_cannot_dispatch_realtime_event(): void
    {
        Event::fake([ConversationMessageCreated::class]);
        $first = User::factory()->create();
        $second = User::factory()->create();
        $conversationId = DB::table('conversations')->insertGetId([
            'user_low_id' => min($first->id, $second->id),
            'user_high_id' => max($first->id, $second->id),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('blocks')->insert([
            'blocker_id' => $second->id,
            'blocked_id' => $first->id,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->actingAs($first, 'sanctum');
        $this->postJson("/api/v1/conversations/$conversationId/messages", [
            'body' => 'Should not deliver', 'client_id' => (string) Str::uuid(),
        ])->assertForbidden();
        Event::assertNotDispatched(ConversationMessageCreated::class);
    }
}
