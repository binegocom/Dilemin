<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class ReadCursorTest extends TestCase
{
    use RefreshDatabase;

    public function test_unread_counts_are_personal_and_read_updates_never_move_backward(): void
    {
        $low = User::factory()->create();
        $high = User::factory()->create();
        $conversation = DB::table('conversations')->insertGetId([
            'user_low_id' => min($low->id, $high->id),
            'user_high_id' => max($low->id, $high->id),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $first = $this->insertMessage($conversation, $low->id, 'First');
        $second = $this->insertMessage($conversation, $high->id, 'Second');
        $third = $this->insertMessage($conversation, $low->id, 'Third');

        $this->actingAs($high, 'sanctum');
        $this->getJson('/api/v1/conversations')
            ->assertOk()->assertJsonPath('data.0.unread_count', 2);
        $this->postJson('/api/v1/conversations/'.$conversation.'/read', ['message_id' => $third])
            ->assertOk();
        $this->getJson('/api/v1/conversations')
            ->assertOk()->assertJsonPath('data.0.unread_count', 0);
        $this->postJson('/api/v1/conversations/'.$conversation.'/read', ['message_id' => $first])
            ->assertOk();
        $this->assertSame($third, (int) DB::table('conversations')
            ->where('id', $conversation)->value($high->id < $low->id
                ? 'last_read_low_message_id' : 'last_read_high_message_id'));
        $this->actingAs($low, 'sanctum');
        $this->getJson('/api/v1/conversations')
            ->assertOk()->assertJsonPath('data.0.unread_count', 1);
        $this->postJson('/api/v1/conversations/'.$conversation.'/read', ['message_id' => $second])
            ->assertOk();
        $this->getJson('/api/v1/conversations')->assertJsonPath('data.0.unread_count', 0);
    }

    public function test_outsider_and_foreign_message_cannot_mutate_read_cursor(): void
    {
        $first = User::factory()->create();
        $second = User::factory()->create();
        $outsider = User::factory()->create();
        $conversation = DB::table('conversations')->insertGetId([
            'user_low_id' => min($first->id, $second->id),
            'user_high_id' => max($first->id, $second->id),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $foreign = DB::table('conversations')->insertGetId([
            'user_low_id' => min($first->id, $outsider->id),
            'user_high_id' => max($first->id, $outsider->id),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $message = $this->insertMessage($foreign, $first->id, 'Foreign');
        $this->actingAs($outsider, 'sanctum')
            ->postJson('/api/v1/conversations/'.$conversation.'/read', ['message_id' => $message])
            ->assertNotFound();
        $this->actingAs($second, 'sanctum')
            ->postJson('/api/v1/conversations/'.$conversation.'/read', ['message_id' => $message])
            ->assertUnprocessable();
        $this->assertNull(DB::table('conversations')->where('id', $conversation)
            ->value($second->id < $first->id ? 'last_read_low_message_id' : 'last_read_high_message_id'));
    }

    private function insertMessage(int $conversation, int $sender, string $body): int
    {
        return DB::table('messages')->insertGetId([
            'conversation_id' => $conversation,
            'sender_id' => $sender,
            'client_id' => (string) \Illuminate\Support\Str::uuid(),
            'body' => $body, 'created_at' => now(), 'updated_at' => now(),
        ]);
    }
}
