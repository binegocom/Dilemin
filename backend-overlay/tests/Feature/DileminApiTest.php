<?php

namespace Tests\Feature;

use App\Models\User;
use App\Support\PresenceStore;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class DileminApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_registration_rejects_underage_users(): void
    {
        $this->postJson('/api/v1/auth/register', [
            'display_name' => 'Test User',
            'email' => 'adult@example.com',
            'password' => 'secure-password-2026',
            'date_of_birth' => now()->subYears(17)->toDateString(),
        ])->assertUnprocessable()->assertJsonValidationErrors(['date_of_birth']);
    }

    public function test_registration_defaults_to_invisible_and_returns_token(): void
    {
        $this->postJson('/api/v1/auth/register', [
            'display_name' => 'Test User',
            'email' => 'adult@example.com',
            'password' => 'secure-password-2026',
            'date_of_birth' => now()->subYears(22)->toDateString(),
        ])->assertCreated()
            ->assertJsonPath('user.online_visible', false)
            ->assertJsonStructure(['token', 'user' => ['id', 'display_name', 'online_visible']])
            ->assertJsonMissingPath('user.date_of_birth');

        $this->assertTrue(Hash::check('secure-password-2026', User::firstOrFail()->password));
    }

    public function test_presence_endpoint_requires_authentication(): void
    {
        $this->postJson('/api/v1/presence/heartbeat')->assertUnauthorized();
        $this->getJson('/api/v1/discovery/online')->assertUnauthorized();
    }

    public function test_invisible_user_is_not_added_to_presence(): void
    {
        $user = User::factory()->create(['online_visible' => false]);
        $presence = $this->mock(PresenceStore::class);
        $presence->shouldReceive('markOffline')->once()->with($user->id);
        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/presence/heartbeat')->assertOk();
    }

    public function test_discovery_does_not_leak_private_fields(): void
    {
        $viewer = User::factory()->create();
        $visible = User::factory()->create(['online_visible' => true]);
        $hidden = User::factory()->create(['online_visible' => false]);
        $presence = $this->mock(PresenceStore::class);
        $presence->shouldReceive('onlineIds')->once()->andReturn([$viewer->id, $visible->id, $hidden->id]);
        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/discovery/online')->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', (string) $visible->id)
            ->assertJsonMissingPath('data.0.email')
            ->assertJsonMissingPath('data.0.date_of_birth');
    }
    public function test_blocking_hides_online_profiles(): void
    {
        $viewer = User::factory()->create();
        $other = User::factory()->create(['online_visible' => true]);
        $presence = $this->mock(PresenceStore::class);
        $presence->shouldReceive('onlineIds')->twice()->andReturn([$other->id]);
        $this->actingAs($viewer, 'sanctum')
            ->postJson('/api/v1/users/'.$other->id.'/block')->assertOk();
        $this->getJson('/api/v1/discovery/online')->assertOk()->assertJsonCount(0, 'data');
        $this->deleteJson('/api/v1/users/'.$other->id.'/block')->assertOk();
        $this->getJson('/api/v1/discovery/online')->assertOk()->assertJsonCount(1, 'data');
    }
}
