<?php

namespace Tests\Feature;

use App\Models\User;
use App\Support\PresenceStore;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ProfilePhotoTest extends TestCase
{
    use RefreshDatabase;

    public function test_upload_is_private_pending_and_requires_authentication(): void
    {
        Storage::fake('local');
        $user = User::factory()->create(['online_visible' => true]);
        $other = User::factory()->create();
        $this->post('/api/v1/account/photo', ['photo' => UploadedFile::fake()->image('photo.jpg', 300, 300)],
            ['Accept' => 'application/json'])->assertUnauthorized();
        $this->actingAs($user, 'sanctum');
        $this->post('/api/v1/account/photo', ['photo' => UploadedFile::fake()->image('photo.jpg', 300, 300)],
            ['Accept' => 'application/json'])->assertCreated()
            ->assertJsonPath('user.photo_status', 'pending')
            ->assertJsonStructure(['user' => ['photo_id']]);
        $path = DB::table('profile_photos')->where('user_id', $user->id)->value('private_path');
        Storage::disk('local')->assertExists($path);
        $this->get('/api/v1/users/'.$user->id.'/photo')->assertOk()->assertHeader('Content-Type', 'image/jpeg');

        $presence = $this->mock(PresenceStore::class);
        $presence->shouldReceive('onlineIds')->andReturn([$user->id]);
        $this->actingAs($other, 'sanctum')->get('/api/v1/users/'.$user->id.'/photo')->assertNotFound();
    }

    public function test_only_moderators_can_review_and_stale_revision_cannot_approve_replacement(): void
    {
        Storage::fake('local');
        $owner = User::factory()->create(['online_visible' => true]);
        $moderator = User::factory()->create(['is_moderator' => true]);
        $ordinary = User::factory()->create();

        $this->actingAs($owner, 'sanctum');
        $this->post('/api/v1/account/photo', ['photo' => UploadedFile::fake()->image('first.jpg', 320, 320)],
            ['Accept' => 'application/json'])->assertCreated();
        $photo = DB::table('profile_photos')->where('user_id', $owner->id)->first();
        $this->actingAs($ordinary, 'sanctum');
        $this->getJson('/api/v1/moderation/photos')->assertForbidden();
        $this->get('/api/v1/moderation/photos/'.$photo->id)->assertForbidden();
        $this->postJson('/api/v1/moderation/photos/'.$photo->id.'/review', [
            'decision' => 'approved', 'revision' => $photo->revision,
        ])->assertForbidden();

        $this->actingAs($moderator, 'sanctum');
        $this->getJson('/api/v1/moderation/photos')->assertOk()->assertJsonCount(1, 'data');
        $this->get('/api/v1/moderation/photos/'.$photo->id)->assertOk();
        $this->actingAs($owner, 'sanctum');
        $this->post('/api/v1/account/photo', ['photo' => UploadedFile::fake()->image('second.jpg', 320, 320)],
            ['Accept' => 'application/json'])->assertCreated();

        $this->actingAs($moderator, 'sanctum');
        $url = '/api/v1/moderation/photos/'.$photo->id.'/review';
        $this->postJson($url, ['decision' => 'approved', 'revision' => $photo->revision])->assertStatus(409);
        $current = DB::table('profile_photos')->where('user_id', $owner->id)->first();
        $this->postJson($url, ['decision' => 'approved', 'revision' => $current->revision])->assertOk();

        $presence = $this->mock(PresenceStore::class);
        $presence->shouldReceive('onlineIds')->andReturn([$owner->id]);
        $this->actingAs($ordinary, 'sanctum');
        $this->get('/api/v1/users/'.$owner->id.'/photo')->assertOk();
        $this->postJson('/api/v1/users/'.$owner->id.'/block')->assertOk();
        $this->get('/api/v1/users/'.$owner->id.'/photo')->assertNotFound();
    }

    public function test_photo_delete_and_account_delete_remove_private_storage(): void
    {
        Storage::fake('local');
        $user = User::factory()->create(['password' => 'a-strong-password-here']);
        $this->actingAs($user, 'sanctum');
        $this->post('/api/v1/account/photo', ['photo' => UploadedFile::fake()->image('first.png', 400, 400)],
            ['Accept' => 'application/json'])->assertCreated();
        $path = DB::table('profile_photos')->where('user_id', $user->id)->value('private_path');
        $this->deleteJson('/api/v1/account/photo')->assertOk();
        Storage::disk('local')->assertMissing($path);
        $this->assertDatabaseCount('profile_photos', 0);

        $this->post('/api/v1/account/photo', ['photo' => UploadedFile::fake()->image('second.png', 400, 400)],
            ['Accept' => 'application/json'])->assertCreated();
        $newPath = DB::table('profile_photos')->where('user_id', $user->id)->value('private_path');
        $this->mock(PresenceStore::class)->shouldReceive('markOffline')->once()->with($user->id);
        $this->deleteJson('/api/v1/account', ['password' => 'a-strong-password-here'])->assertOk();
        Storage::disk('local')->assertMissing($newPath);
    }

    public function test_invalid_upload_is_rejected(): void
    {
        Storage::fake('local');
        $this->actingAs(User::factory()->create(), 'sanctum');
        $this->post('/api/v1/account/photo', ['photo' => UploadedFile::fake()->create('not-image.pdf', 10, 'application/pdf')],
            ['Accept' => 'application/json'])->assertUnprocessable()->assertJsonValidationErrors('photo');
    }
}
