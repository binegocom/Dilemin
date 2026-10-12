<?php

namespace Tests\Feature;

use App\Models\User;
use App\Support\PresenceStore;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SocialApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_profile_rejects_invalid_bio_and_never_exposes_private_data(): void
    {
        $actor = User::factory()->create();
        $other = User::factory()->create(['online_visible' => true, 'bio' => 'Ready to talk']);
        $presence = $this->mock(PresenceStore::class);
        $presence->shouldReceive('onlineIds')->once()->andReturn([$other->id]);
        $this->actingAs($actor, 'sanctum');
        $this->patchJson('/api/v1/account/profile', ['bio' => str_repeat('x', 501)])
            ->assertUnprocessable();
        $this->patchJson('/api/v1/account/profile', ['display_name' => 'Updated', 'bio' => 'Hello'])
            ->assertOk()->assertJsonPath('user.bio', 'Hello');
        $this->getJson('/api/v1/users/'.$other->id)
            ->assertOk()->assertJsonPath('user.bio', 'Ready to talk')
            ->assertJsonMissingPath('user.email')->assertJsonMissingPath('user.date_of_birth');
    }

    public function test_blocked_users_cannot_view_profile_or_send_messages(): void
    {
        $actor = User::factory()->create();
        $other = User::factory()->create(['online_visible' => true]);
        $presence = $this->mock(PresenceStore::class);
        $presence->shouldReceive('onlineIds')->once()->andReturn([$other->id]);
        $this->actingAs($actor, 'sanctum');
        $response = $this->postJson('/api/v1/conversations', ['recipient_id' => $other->id]);
        $response->assertCreated();
        $conversation = $response->json('id');
        $this->postJson('/api/v1/users/'.$other->id.'/block')->assertOk();
        $this->getJson('/api/v1/users/'.$other->id)->assertNotFound();
        $this->postJson('/api/v1/conversations/'.$conversation.'/messages', [
            'body' => 'Hello', 'client_id' => 'efb68ac0-0d5a-4992-bf05-58d6f5fb41f1',
        ])->assertForbidden();
        $this->getJson('/api/v1/conversations/'.$conversation.'/messages')->assertForbidden();
    }

    public function test_only_conversation_members_can_read_messages(): void
    {
        $actor = User::factory()->create();
        $other = User::factory()->create(['online_visible' => true]);
        $outsider = User::factory()->create();
        $presence = $this->mock(PresenceStore::class);
        $presence->shouldReceive('onlineIds')->once()->andReturn([$other->id]);
        $this->actingAs($actor, 'sanctum');
        $conversation = $this->postJson('/api/v1/conversations', ['recipient_id' => $other->id])->json('id');
        $this->actingAs($outsider, 'sanctum');
        $this->getJson('/api/v1/conversations/'.$conversation.'/messages')->assertNotFound();
        $this->postJson('/api/v1/conversations/'.$conversation.'/messages', [
            'body' => 'Unauthorized', 'client_id' => '5b187692-b0e4-4c5d-8de0-d75c6ab3cfcf',
        ])->assertNotFound();
    }

    public function test_duplicate_client_id_is_idempotent_and_conflicting_body_rejected(): void
    {
        $actor = User::factory()->create();
        $other = User::factory()->create(['online_visible' => true]);
        $presence = $this->mock(PresenceStore::class);
        $presence->shouldReceive('onlineIds')->once()->andReturn([$other->id]);
        $this->actingAs($actor, 'sanctum');
        $conversation = $this->postJson('/api/v1/conversations', ['recipient_id' => $other->id])->json('id');
        $url = '/api/v1/conversations/'.$conversation.'/messages';
        $data = ['body' => 'Hello', 'client_id' => 'e6201d80-a12d-43de-8d63-5ae14aa0ff18'];
        $first = $this->postJson($url, $data)->assertCreated();
        $this->postJson($url, $data)->assertOk()->assertJsonPath('id', $first->json('id'));
        $this->postJson($url, ['body' => 'Changed', 'client_id' => $data['client_id']])->assertStatus(409);
        $this->assertDatabaseCount('messages', 1);
    }

    public function test_report_does_not_allow_self_report(): void
    {
        $actor = User::factory()->create();
        $this->actingAs($actor, 'sanctum');
        $this->postJson('/api/v1/users/'.$actor->id.'/report', ['reason' => 'spam'])->assertUnprocessable();
        $other = User::factory()->create();
        $this->postJson('/api/v1/users/'.$other->id.'/report', ['reason' => 'harassment'])
            ->assertCreated();
        $this->assertDatabaseCount('user_reports', 1);
    }
}
