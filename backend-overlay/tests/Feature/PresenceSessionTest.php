<?php

namespace Tests\Feature;

use App\Models\User;
use App\Support\PresenceStore;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Redis;
use Tests\TestCase;

class PresenceSessionTest extends TestCase
{
    use RefreshDatabase;

    public function test_one_device_offline_does_not_hide_another_active_device(): void
    {
        $userId = 123;
        $global = [];
        $sessions = [];
        Redis::shouldReceive('command')->andReturnUsing(function (string $op, array $args) use (&$global, &$sessions) {
            switch ($op) {
                case 'ZADD':
                    if ($args[0] === 'dilemin:presence:online') $global[$args[2]] = true;
                    else $sessions[$args[0]][$args[2]] = true;
                    return 1;
                case 'ZREM':
                    if ($args[0] === 'dilemin:presence:online') unset($global[$args[1]]);
                    else unset($sessions[$args[0]][$args[1]]);
                    return 1;
                case 'ZCOUNT': return count($sessions[$args[0]] ?? []);
                case 'ZREVRANGEBYSCORE': return array_keys($global);
                case 'DEL': unset($sessions[$args[0]]); return 1;
                default: return 1;
            }
        });

        $presence = new PresenceStore();
        $presence->markOnline($userId, 'device-a');
        $presence->markOnline($userId, 'device-b');
        $this->assertSame([$userId], $presence->onlineIds());
        $presence->markOffline($userId, 'device-a');
        $this->assertSame([$userId], $presence->onlineIds());
        $presence->markOffline($userId, 'device-b');
        $this->assertSame([], $presence->onlineIds());
        $presence->markOnline($userId, 'device-c');
        $presence->markOffline($userId);
        $this->assertSame([], $presence->onlineIds());
    }

    public function test_revoking_other_sessions_preserves_current_presence(): void
    {
        $user = User::factory()->create([
            'online_visible' => true,
            'password' => Hash::make('secure-password-2026'),
        ]);
        $current = $user->createToken('current');
        $other = $user->createToken('other');
        $presence = $this->mock(PresenceStore::class);
        $presence->shouldReceive('markOffline')->once()->with($user->id);
        $presence->shouldReceive('markOnline')->once()->with($user->id, (string) $current->accessToken->id);
        $this->withToken($current->plainTextToken)
            ->postJson('/api/v1/auth/sessions/revoke-others', ['password' => 'secure-password-2026'])
            ->assertOk()->assertJsonPath('count', 1);
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $other->accessToken->id]);
    }
}
