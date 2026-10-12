<?php

namespace Tests\Feature;

use App\Models\User;
use App\Support\PresenceStore;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class PresenceOutageResilienceTest extends TestCase
{
    use RefreshDatabase;

    public function test_revoking_another_session_survives_presence_store_outage(): void
    {
        $owner = User::factory()->create([
            'online_visible' => true,
            'email_verified_at' => now(),
        ]);
        $current = $owner->createToken('current');
        $lost = $owner->createToken('lost');
        $presence = $this->mock(PresenceStore::class);
        $presence->shouldReceive('markOffline')->once()
            ->with($owner->id, (string) $lost->accessToken->id)
            ->andThrow(new \RuntimeException('Redis down'));

        $this->withToken($current->plainTextToken)
            ->deleteJson('/api/v1/auth/sessions/'.$lost->accessToken->id)
            ->assertOk();
        $this->assertDatabaseMissing('personal_access_tokens', [
            'id' => $lost->accessToken->id,
        ]);
        $this->assertDatabaseHas('personal_access_tokens', [
            'id' => $current->accessToken->id,
        ]);
    }

    public function test_revoking_all_other_sessions_survives_presence_store_outage(): void
    {
        $owner = User::factory()->create([
            'online_visible' => true,
            'password' => Hash::make('secure-password-2026'),
            'email_verified_at' => now(),
        ]);
        $current = $owner->createToken('current');
        $other = $owner->createToken('other');
        $presence = $this->mock(PresenceStore::class);
        $presence->shouldReceive('markOffline')->once()
            ->with($owner->id)->andThrow(new \RuntimeException('Redis down'));

        $this->withToken($current->plainTextToken)
            ->postJson('/api/v1/auth/sessions/revoke-others', [
                'password' => 'secure-password-2026',
            ])->assertOk()->assertJsonPath('count', 1);
        $this->assertDatabaseMissing('personal_access_tokens', [
            'id' => $other->accessToken->id,
        ]);
        $this->assertDatabaseHas('personal_access_tokens', [
            'id' => $current->accessToken->id,
        ]);
    }

    public function test_user_can_delete_account_even_if_redis_is_unavailable(): void
    {
        $user = User::factory()->create([
            'password' => Hash::make('secure-password-2026'),
            'email_verified_at' => now(),
        ]);
        $this->withToken($user->createToken('current')->plainTextToken);
        $presence = $this->mock(PresenceStore::class);
        $presence->shouldReceive('markOffline')->once()
            ->with($user->id)->andThrow(new \RuntimeException('Redis down'));

        $this->deleteJson('/api/v1/account', [
            'password' => 'secure-password-2026',
        ])->assertOk()->assertJsonPath('status', 'deleted');
        $this->assertDatabaseMissing('users', ['id' => $user->id]);
        $this->assertSame(0, DB::table('personal_access_tokens')
            ->where('tokenable_id', $user->id)
            ->where('tokenable_type', User::class)->count());
    }
}
