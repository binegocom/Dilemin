<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class BroadcastAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'broadcasting.default' => 'reverb',
            'broadcasting.connections.reverb.key' => 'test-public-app-key',
            'broadcasting.connections.reverb.secret' => 'test-secret',
            'broadcasting.connections.reverb.app_id' => 'test-app',
        ]);
    }

    private function authorize(User $user, string $channel): \Illuminate\Testing\TestResponse
    {
        // Simulate a fresh HTTP request: Laravel's test application caches auth guards.
        app('auth')->forgetGuards();
        $this->withToken($user->createToken('realtime-test')->plainTextToken);
        $this->getJson('/api/v1/auth/me')->assertOk();
        return $this->postJson('/api/v1/realtime/authorize', [
            'socket_id' => '123.456',
            'channel_name' => $channel,
        ]);
    }

    public function test_only_verified_conversation_participants_can_subscribe(): void
    {
        $first = User::factory()->create(['email_verified_at' => now()]);
        $second = User::factory()->create(['email_verified_at' => now()]);
        $outsider = User::factory()->create(['email_verified_at' => now()]);
        $unverified = User::factory()->create(['email_verified_at' => null]);
        $conversation = DB::table('conversations')->insertGetId([
            'user_low_id' => min($first->id, $second->id),
            'user_high_id' => max($first->id, $second->id),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->authorize($first, "private-conversations.$conversation")->assertOk()->assertJsonStructure(['auth']);
        $this->authorize($second, "private-conversations.$conversation")->assertOk();
        $this->authorize($outsider, "private-conversations.$conversation")->assertForbidden();
        $this->authorize($unverified, "private-conversations.$conversation")->assertForbidden();

        DB::table('blocks')->insert([
            'blocker_id' => $first->id, 'blocked_id' => $second->id,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->authorize($second, "private-conversations.$conversation")->assertForbidden();
    }

    public function test_user_inbox_channel_cannot_be_subscribed_by_other_users(): void
    {
        $first = User::factory()->create(['email_verified_at' => now()]);
        $second = User::factory()->create(['email_verified_at' => now()]);
        $this->authorize($first, "private-users.$first->id")->assertOk();
        $this->authorize($second, "private-users.$first->id")->assertForbidden();
    }
}
