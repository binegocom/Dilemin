<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class SessionManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_unauthed_client_cannot_enumerate_sessions(): void
    {
        $this->getJson('/api/v1/auth/sessions')->assertUnauthorized();
        $this->deleteJson('/api/v1/auth/sessions/1')->assertUnauthorized();
        $this->postJson('/api/v1/auth/sessions/revoke-others')->assertUnauthorized();
    }

    public function test_token_operations_are_scoped_to_owner(): void
    {
        $owner = User::factory()->create();
        $intruder = User::factory()->create();
        $ownedToken = $owner->createToken('owner-phone');
        $intruder->createToken('other-phone');

        $this->actingAs($intruder, 'sanctum')
            ->deleteJson('/api/v1/auth/sessions/'.$ownedToken->accessToken->id)->assertNotFound();
        $this->assertDatabaseHas('personal_access_tokens', ['id' => $ownedToken->accessToken->id]);
        $this->getJson('/api/v1/auth/sessions')->assertOk()->assertJsonCount(1, 'data')
            ->assertJsonMissing(['name' => 'owner-phone']);
    }

    public function test_other_sessions_require_password_and_preserve_current_token(): void
    {
        $owner = User::factory()->create(['password' => Hash::make('secure-password-2026')]);
        $current = $owner->createToken('this-device');
        $other = $owner->createToken('lost-device');

        $this->withToken($current->plainTextToken)
            ->getJson('/api/v1/auth/sessions')
            ->assertOk()->assertJsonCount(2, 'data');

        $this->postJson('/api/v1/auth/sessions/revoke-others', ['password' => 'incorrect'])
            ->assertUnprocessable();
        $this->assertDatabaseHas('personal_access_tokens', ['id' => $other->accessToken->id]);

        $this->postJson('/api/v1/auth/sessions/revoke-others', ['password' => 'secure-password-2026'])
            ->assertOk()->assertJsonPath('count', 1);
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $other->accessToken->id]);
        $this->assertDatabaseHas('personal_access_tokens', ['id' => $current->accessToken->id]);
        $this->getJson('/api/v1/auth/me')->assertOk();
    }

    public function test_user_can_revoke_another_session(): void
    {
        $owner = User::factory()->create();
        $first = $owner->createToken('primary');
        $second = $owner->createToken('other');
        $this->actingAs($owner, 'sanctum')
            ->deleteJson('/api/v1/auth/sessions/'.$second->accessToken->id)
            ->assertOk()->assertJsonPath('status', 'revoked');
        $this->assertDatabaseHas('personal_access_tokens', ['id' => $first->accessToken->id]);
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $second->accessToken->id]);
    }
}
