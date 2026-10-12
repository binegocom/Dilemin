<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ModerationReportTest extends TestCase
{
    use RefreshDatabase;

    public function test_blocked_list_is_private_and_unblock_only_affects_own_blocks(): void
    {
        $viewer = User::factory()->create();
        $other = User::factory()->create();
        $third = User::factory()->create();
        $this->actingAs($viewer, 'sanctum');
        $this->postJson('/api/v1/users/'.$other->id.'/block')->assertOk();
        $this->getJson('/api/v1/account/blocked')->assertOk()
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', (string) $other->id)
            ->assertJsonMissingPath('data.0.email');
        $this->actingAs($third, 'sanctum');
        $this->getJson('/api/v1/account/blocked')->assertOk()->assertJsonCount(0, 'data');
        $this->deleteJson('/api/v1/users/'.$other->id.'/block')->assertOk();
        $this->actingAs($viewer, 'sanctum');
        $this->getJson('/api/v1/account/blocked')->assertJsonCount(1, 'data');
        $this->deleteJson('/api/v1/users/'.$other->id.'/block')->assertOk();
        $this->getJson('/api/v1/account/blocked')->assertJsonCount(0, 'data');
    }

    public function test_only_moderators_can_review_reports_and_double_review_conflicts(): void
    {
        $reporter = User::factory()->create();
        $target = User::factory()->create();
        $moderator = User::factory()->create(['is_moderator' => true]);
        $this->actingAs($reporter, 'sanctum');
        $this->postJson('/api/v1/users/'.$target->id.'/report', [
            'reason' => 'harassment', 'details' => 'Inappropriate messages',
        ])->assertCreated();
        $this->getJson('/api/v1/moderation/reports')->assertForbidden();
        // Authentication is checked before report lookup; the requested ID
        // need not exist for this unauthorized-access assertion.
        $this->postJson('/api/v1/moderation/reports/1/review', [
            'decision' => 'dismissed',
        ])->assertForbidden();

        $this->actingAs($moderator, 'sanctum');
        $response = $this->getJson('/api/v1/moderation/reports')->assertOk()
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.reason', 'harassment');
        $reportId = $response->json('data.0.id');
        $this->postJson('/api/v1/moderation/reports/'.$reportId.'/review', [
            'decision' => 'reviewed', 'note' => 'Escalated to safety lead',
        ])->assertOk()->assertJsonPath('status', 'reviewed');
        $this->getJson('/api/v1/moderation/reports')->assertOk()->assertJsonCount(0, 'data');
        $this->postJson('/api/v1/moderation/reports/1/review', [
            'decision' => 'dismissed',
        ])->assertStatus(409);
    }
}
