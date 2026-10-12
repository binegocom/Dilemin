<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

final class MessagePaginationTest extends TestCase
{
    use RefreshDatabase;

    public function test_pages_are_descending_complete_and_conversation_scoped(): void
    {
        $first = User::factory()->create(['email_verified_at' => now()]);
        $second = User::factory()->create(['email_verified_at' => now()]);
        $outsider = User::factory()->create(['email_verified_at' => now()]);
        $conversation = DB::table('conversations')->insertGetId([
            'user_low_id' => min($first->id, $second->id),
            'user_high_id' => max($first->id, $second->id),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $foreignConversation = DB::table('conversations')->insertGetId([
            'user_low_id' => min($first->id, $outsider->id),
            'user_high_id' => max($first->id, $outsider->id),
            'created_at' => now(), 'updated_at' => now(),
        ]);

        for ($i = 0; $i < 112; $i++) {
            DB::table('messages')->insert([
                'conversation_id' => $conversation,
                'sender_id' => $i % 2 ? $first->id : $second->id,
                'client_id' => (string) Str::uuid(),
                'body' => 'Message '.$i,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
        $foreignId = DB::table('messages')->insertGetId([
            'conversation_id' => $foreignConversation,
            'sender_id' => $outsider->id,
            'client_id' => (string) Str::uuid(),
            'body' => 'Foreign conversation',
            'created_at' => now(), 'updated_at' => now(),
        ]);

        $this->actingAs($first, 'sanctum');
        $url = '/api/v1/conversations/'.$conversation.'/messages';
        $latest = $this->getJson($url)->assertOk()->assertJsonCount(50, 'data')->json('data');
        $middle = $this->getJson($url.'?before_id='.$latest[49]['id'])
            ->assertOk()->assertJsonCount(50, 'data')->json('data');
        $oldest = $this->getJson($url.'?before_id='.$middle[49]['id'])
            ->assertOk()->assertJsonCount(12, 'data')->json('data');
        $this->getJson($url.'?before_id='.$oldest[11]['id'])
            ->assertOk()->assertJsonCount(0, 'data');

        $all = array_merge($latest, $middle, $oldest);
        $ids = array_map(fn ($message) => (int) $message['id'], $all);
        $this->assertCount(112, array_unique($ids));
        $this->assertSame($ids, collect($ids)->sortDesc()->values()->all());
        $this->assertNotContains($foreignId, $ids);
        $this->assertSame('Message 111', $latest[0]['body']);
        $this->assertSame('Message 0', $oldest[11]['body']);
        $this->getJson($url.'?before_id=not-a-number')->assertUnprocessable();

        $this->actingAs($outsider, 'sanctum')
            ->getJson($url.'?before_id='.$latest[49]['id'])->assertNotFound();
    }
}
