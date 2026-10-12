<?php

namespace Tests\Feature;

use App\Models\User;
use App\Support\PresenceStore;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class LogoutResilienceTest extends TestCase
{
    use RefreshDatabase;

    public function test_logout_revokes_session_and_its_push_tokens_when_redis_fails(): void
    {
        $user = User::factory()->create(['email_verified_at' => now()]);
        $token = $user->createToken('phone')->plainTextToken;
        $this->withToken($token);
        $this->putJson('/api/v1/push/devices', [
            'token' => str_repeat('device-token-', 10),
            'platform' => 'ios',
            'locale' => 'en',
        ])->assertOk();

        $presence = $this->mock(PresenceStore::class);
        $presence->shouldReceive('markOffline')->once()->andThrow(new \RuntimeException('Redis unavailable'));

        $this->postJson('/api/v1/auth/logout')->assertOk();
        $this->assertDatabaseCount('personal_access_tokens', 0);
        $this->assertDatabaseCount('push_devices', 0);
        $this->getJson('/api/v1/auth/me')->assertUnauthorized();
    }
}
