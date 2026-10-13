<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

final class AccountAppealTest extends TestCase
{
    use RefreshDatabase;

    private function suspendedMember(): User
    {
        return User::factory()->create([
            'email_verified_at' => now(),
            'suspended_at' => now(),
            'online_visible' => false,
            'password' => Hash::make('appeal-test-password'),
        ]);
    }

    public function test_suspended_members_get_one_private_appeal_without_social_access(): void
    {
        $member = $this->suspendedMember();
        $active = User::factory()->create(['email_verified_at' => now()]);
        $url = '/api/v1/account/appeal';

        $this->getJson($url)->assertUnauthorized();
        $this->actingAs($active, 'sanctum')
            ->postJson($url, ['statement' => 'Unrelated active account must be rejected.'])
            ->assertForbidden();

        $this->actingAs($member, 'sanctum');
        $this->getJson($url)->assertOk()->assertJsonPath('appeal', null);
        $this->postJson($url, ['statement' => 'Too short'])->assertUnprocessable();

        $created = $this->postJson($url, [
            'statement' => 'I believe this decision requires additional review and can provide evidence.',
        ])->assertCreated()->assertJsonPath('status', 'pending');
        $appealId = $created->json('id');
        $this->assertNotEmpty($appealId);

        $this->getJson($url)->assertOk()
            ->assertJsonPath('appeal.id', $appealId)
            ->assertJsonPath('appeal.status', 'pending');
        $this->postJson($url, [
            'statement' => 'I should not be able to open a second appeal for this suspension.',
        ])->assertStatus(409);

        $this->getJson('/api/v1/discovery/online')->assertForbidden();
        $this->postJson('/api/v1/presence/heartbeat')->assertForbidden();
        $this->getJson('/api/v1/moderation/appeals')->assertForbidden();
        $this->assertDatabaseCount('account_appeals', 1);

        $this->actingAs($active, 'sanctum')
            ->getJson($url)->assertForbidden();
    }

    public function test_appeal_review_restores_member_and_writes_staff_audit(): void
    {
        $member = $this->suspendedMember();
        $moderator = User::factory()->create([
            'email_verified_at' => now(), 'is_moderator' => true,
        ]);
        $outsider = User::factory()->create(['email_verified_at' => now()]);
        $this->actingAs($member, 'sanctum');
        $appealId = $this->postJson('/api/v1/account/appeal', [
            'statement' => 'Please review this decision. I can clarify the disputed activity.',
        ])->assertCreated()->json('id');

        $endpoint = '/api/v1/moderation/appeals/'.$appealId.'/review';
        $this->actingAs($outsider, 'sanctum')
            ->postJson($endpoint, ['decision' => 'restored', 'note' => 'Not authorized'])
            ->assertForbidden();

        $this->actingAs($moderator, 'sanctum');
        $this->getJson('/api/v1/moderation/appeals')
            ->assertOk()->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $appealId);
        $this->postJson($endpoint, [
            'decision' => 'restored',
            'note' => 'Reviewed submitted evidence and lifted the suspension.',
        ])->assertOk()->assertJsonPath('status', 'restored');
        $this->assertDatabaseHas('users', [
            'id' => $member->id,
            'suspended_at' => null,
            'online_visible' => false,
        ]);
        $this->assertDatabaseHas('account_appeals', [
            'id' => (int) $appealId,
            'status' => 'restored',
            'reviewed_by' => $moderator->id,
        ]);
        $this->assertDatabaseHas('moderation_actions', [
            'target_user_id' => $member->id,
            'moderator_id' => $moderator->id,
            'action' => 'appeal_restored',
        ]);
        $this->getJson('/api/v1/moderation/appeals')
            ->assertOk()->assertJsonCount(0, 'data');
        $this->postJson($endpoint, [
            'decision' => 'restored', 'note' => 'Double review must not succeed.',
        ])->assertStatus(409);
    }

    public function test_rejected_appeal_does_not_restore_access_or_allow_duplicate(): void
    {
        $member = $this->suspendedMember();
        $moderator = User::factory()->create([
            'email_verified_at' => now(), 'is_moderator' => true,
        ]);
        $this->actingAs($member, 'sanctum');
        $id = $this->postJson('/api/v1/account/appeal', [
            'statement' => 'Please reconsider this suspension based on the attached context.',
        ])->assertCreated()->json('id');
        $this->actingAs($moderator, 'sanctum')
            ->postJson('/api/v1/moderation/appeals/'.$id.'/review', [
                'decision' => 'rejected',
                'note' => 'Evidence did not justify restoring social access.',
            ])->assertOk()->assertJsonPath('status', 'rejected');
        $this->actingAs($member, 'sanctum')
            ->getJson('/api/v1/account/appeal')
            ->assertOk()
            ->assertJsonPath('appeal.status', 'rejected');
        $this->postJson('/api/v1/account/appeal', [
            'statement' => 'The prior rejection cannot be overwritten with another submission.',
        ])->assertStatus(409);
        $this->getJson('/api/v1/conversations')->assertForbidden();
        $this->assertNotNull(DB::table('users')->where('id', $member->id)
            ->value('suspended_at'));
    }

    public function test_independent_moderator_restore_resolves_pending_appeal(): void
    {
        $member = $this->suspendedMember();
        $moderator = User::factory()->create([
            'email_verified_at' => now(), 'is_moderator' => true,
        ]);
        $this->actingAs($member, 'sanctum');
        $id = $this->postJson('/api/v1/account/appeal', [
            'statement' => 'Please reconsider the block while I provide additional details.',
        ])->assertCreated()->json('id');
        $this->actingAs($moderator, 'sanctum');
        $this->postJson('/api/v1/moderation/users/'.$member->id.'/restore', [
            'reason' => 'Manual review supported restoring account access.',
        ])->assertOk();
        $this->assertDatabaseHas('account_appeals', [
            'id' => (int) $id,
            'status' => 'restored',
            'reviewed_by' => $moderator->id,
        ]);
        $this->getJson('/api/v1/moderation/appeals')
            ->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_export_includes_only_owners_appeal_statements(): void
    {
        $first = $this->suspendedMember();
        $other = $this->suspendedMember();
        $this->actingAs($first, 'sanctum');
        $this->postJson('/api/v1/account/appeal', [
            'statement' => 'FIRST USER PRIVATE APPEAL STATEMENT HERE.',
        ])->assertCreated();
        $this->actingAs($other, 'sanctum');
        $this->postJson('/api/v1/account/appeal', [
            'statement' => 'SECOND USER PRIVATE APPEAL STATEMENT HERE.',
        ])->assertCreated();

        $response = $this->post('/api/v1/account/export', [
            'password' => 'appeal-test-password',
        ])->assertOk();
        $export = json_decode($response->streamedContent(), true, 512, JSON_THROW_ON_ERROR);
        $this->assertCount(1, $export['account_appeals']);
        $this->assertSame('SECOND USER PRIVATE APPEAL STATEMENT HERE.',
            $export['account_appeals'][0]['statement']);
        $this->assertStringNotContainsString('FIRST USER PRIVATE APPEAL STATEMENT HERE.',
            json_encode($export));
    }
}
