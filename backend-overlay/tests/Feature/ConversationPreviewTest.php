<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

final class ConversationPreviewTest extends TestCase
{
    use RefreshDatabase;

    public function test_inbox_returns_newest_message_without_leaking_other_conversations(): void
    {
        $actor = User::factory()->create(['email_verified_at' => now()]);
        $partner = User::factory()->create(['email_verified_at' => now()]);
        $outsider = User::factory()->create(['email_verified_at' => now()]);

        $one = $this->conversation($actor, $partner);
        $two = $this->conversation($partner, $outsider);
        $this->message($one, $partner, 'First');
        $this->message($one, $actor, 'Second – the latest message');
        $this->message($two, $outsider, 'Confidential unrelated content');

        $this->actingAs($actor, 'sanctum');
        $this->getJson('/api/v1/conversations')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.last_message', 'Second – the latest message')
            ->assertJsonMissing(['last_message' => 'Confidential unrelated content']);
    }

    public function test_empty_conversation_has_null_preview(): void
    {
        $actor = User::factory()->create(['email_verified_at' => now()]);
        $partner = User::factory()->create(['email_verified_at' => now()]);
        $this->conversation($actor, $partner);
        $this->actingAs($actor, 'sanctum')
            ->getJson('/api/v1/conversations')
            ->assertOk()->assertJsonPath('data.0.last_message', null);
    }

    private function conversation(User $left, User $right): int
    {
        return DB::table('conversations')->insertGetId([
            'user_low_id' => min($left->id, $right->id),
            'user_high_id' => max($left->id, $right->id),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function message(int $conversation, User $sender, string $body): void
    {
        DB::table('messages')->insert([
            'conversation_id' => $conversation,
            'sender_id' => $sender->id,
            'body' => $body,
            'client_id' => (string) Str::uuid(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
