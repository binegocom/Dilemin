<?php

namespace Tests\Feature;

use App\Models\User;
use App\Support\PresenceStore;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

final class AccountSuspensionTest extends TestCase
{
    use RefreshDatabase;

    public function test_only_staff_can_suspend_a_reported_account_and_block_all_social_access(): void
    {
        $moderator = User::factory()->create([
            'is_moderator' => true, 'email_verified_at' => now(),
        ]);
        $reporter = User::factory()->create(['email_verified_at' => now()]);
        $target = User::factory()->create(['email_verified_at' => now(), 'online_visible' => true]);
        $conversation = DB::table('conversations')->insertGetId([
            'user_low_id' => min($reporter->id, $target->id),
            'user_high_id' => max($reporter->id, $target->id),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $reportId = DB::table('user_reports')->insertGetId([
            'reporter_id' => $reporter->id,
            'reported_user_id' => $target->id,
            'reason' => 'underage',
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $presence = $this->mock(PresenceStore::class);
        $presence->shouldReceive('markOffline')->once()->with($target->id);

        $this->actingAs($reporter, 'sanctum')
            ->postJson("/api/v1/moderation/reports/$reportId/review", [
                'decision' => 'suspended', 'note' => 'Identity review requested',
            ])->assertForbidden();

        $this->actingAs($moderator, 'sanctum')
            ->postJson("/api/v1/moderation/reports/$reportId/review", [
                'decision' => 'suspended', 'note' => 'Identity review requested',
            ])->assertOk()->assertJsonPath('status', 'suspended');

        $this->assertDatabaseHas('users', [
            'id' => $target->id, 'online_visible' => false,
        ]);
        $this->assertNotNull(DB::table('users')->where('id', $target->id)->value('suspended_at'));
        $this->assertDatabaseHas('moderation_actions', [
            'moderator_id' => $moderator->id,
            'target_user_id' => $target->id,
            'report_id' => $reportId,
            'action' => 'suspended',
        ]);
        $this->postJson("/api/v1/moderation/reports/$reportId/review", [
            'decision' => 'suspended', 'note' => 'Duplicate',
        ])->assertStatus(409);

        $this->actingAs($reporter, 'sanctum')
            ->getJson('/api/v1/conversations')->assertOk()->assertJsonCount(0, 'data');
        $this->getJson("/api/v1/conversations/$conversation/messages")->assertForbidden();

        $this->actingAs($target, 'sanctum')
            ->getJson('/api/v1/auth/me')->assertOk()->assertJsonPath('user.suspended', true);
        $this->getJson('/api/v1/discovery/online')->assertForbidden();
        $this->postJson('/api/v1/presence/heartbeat')->assertForbidden();
        $this->postJson("/api/v1/conversations/$conversation/messages", [
            'body' => 'Forbidden after suspension', 'client_id' => (string) Str::uuid(),
        ])->assertForbidden();
    }

    public function test_suspended_member_can_export_delete_and_staff_can_audit_restore(): void
    {
        $moderator = User::factory()->create([
            'is_moderator' => true, 'email_verified_at' => now(),
        ]);
        $target = User::factory()->create([
            'email_verified_at' => now(), 'suspended_at' => now(),
            'password' => Hash::make('secure-password-2026'),
            'online_visible' => false,
        ]);

        $this->actingAs($target, 'sanctum')
            ->postJson('/api/v1/account/export', [
                'password' => 'secure-password-2026',
            ])->assertOk();

        $this->postJson("/api/v1/moderation/users/$target->id/restore", [
            'reason' => 'Account appeal reviewed',
        ])->assertForbidden();

        $this->actingAs($moderator, 'sanctum')
            ->postJson("/api/v1/moderation/users/$target->id/restore", [
                'reason' => 'Account appeal reviewed',
            ])->assertOk()->assertJsonPath('status', 'restored');
        $this->assertDatabaseHas('users', [
            'id' => $target->id, 'suspended_at' => null,
            'online_visible' => false,
        ]);
        $this->assertDatabaseHas('moderation_actions', [
            'action' => 'restored', 'target_user_id' => $target->id,
            'moderator_id' => $moderator->id,
        ]);
        $this->postJson("/api/v1/moderation/users/$target->id/restore", [
            'reason' => 'Duplicate restoration',
        ])->assertStatus(409);

        // Account erasure remains available if a member is suspended again.
        DB::table('users')->where('id', $target->id)->update(['suspended_at' => now()]);
        $this->actingAs($target, 'sanctum')
            ->deleteJson('/api/v1/account', [
                'password' => 'secure-password-2026',
            ])->assertOk();
        $this->assertDatabaseMissing('users', ['id' => $target->id]);
    }

    public function test_staff_account_suspension_requires_separate_administration(): void
    {
        $moderator = User::factory()->create([
            'is_moderator' => true, 'email_verified_at' => now(),
        ]);
        $otherModerator = User::factory()->create([
            'is_moderator' => true, 'email_verified_at' => now(),
        ]);
        $reporter = User::factory()->create(['email_verified_at' => now()]);
        $id = DB::table('user_reports')->insertGetId([
            'reporter_id' => $reporter->id,
            'reported_user_id' => $otherModerator->id,
            'reason' => 'harassment',
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->actingAs($moderator, 'sanctum')
            ->postJson("/api/v1/moderation/reports/$id/review", [
                'decision' => 'suspended', 'note' => 'Needs administrative investigation',
            ])->assertForbidden();
        $this->assertDatabaseCount('moderation_actions', 0);
        $this->assertDatabaseHas('user_reports', ['id' => $id, 'status' => 'pending']);
    }
}
