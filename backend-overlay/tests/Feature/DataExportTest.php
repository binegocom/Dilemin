<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class DataExportTest extends TestCase
{
    use RefreshDatabase;

    public function test_export_requires_authentication_and_correct_password(): void
    {
        $user = User::factory()->create(['password' => Hash::make('safe-passphrase-123')]);
        $this->postJson('/api/v1/account/export', ['password' => 'safe-passphrase-123'])->assertUnauthorized();
        $this->actingAs($user, 'sanctum');
        $this->postJson('/api/v1/account/export', ['password' => 'incorrect'])->assertUnprocessable();
    }

    public function test_export_is_scoped_to_authenticated_user_and_contains_private_account_data(): void
    {
        $user = User::factory()->create([
            'email' => 'owner@example.org',
            'password' => Hash::make('safe-passphrase-123'),
            'bio' => 'Private biography',
        ]);
        $friend = User::factory()->create();
        $stranger = User::factory()->create(['email' => 'stranger@example.org']);

        $ownedConversation = DB::table('conversations')->insertGetId([
            'user_low_id' => min($user->id, $friend->id),
            'user_high_id' => max($user->id, $friend->id),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $foreignConversation = DB::table('conversations')->insertGetId([
            'user_low_id' => min($friend->id, $stranger->id),
            'user_high_id' => max($friend->id, $stranger->id),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        foreach ([[$ownedConversation, $friend->id, 'Allowed incoming'],
                  [$foreignConversation, $stranger->id, 'PRIVATE FOREIGN MESSAGE']] as $i => $tuple) {
            DB::table('messages')->insert([
                'conversation_id' => $tuple[0], 'sender_id' => $tuple[1],
                'client_id' => sprintf('a3b0f276-1234-4ba1-8b12-%012d', $i + 1),
                'body' => $tuple[2], 'created_at' => now(), 'updated_at' => now(),
            ]);
        }
        DB::table('blocks')->insert([
            'blocker_id' => $user->id, 'blocked_id' => $stranger->id,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        Storage::fake('local');
        Storage::disk('local')->put('dilemin/profile-photos/'.$user->id.'/photo.jpg', 'binary-photo');
        DB::table('profile_photos')->insert([
            'user_id' => $user->id,
            'private_path' => 'dilemin/profile-photos/'.$user->id.'/photo.jpg',
            'revision' => '9ac227e8-a7c7-4d45-8903-c278b7e2cf91',
            'status' => 'pending', 'created_at' => now(), 'updated_at' => now(),
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->post('/api/v1/account/export', ['password' => 'safe-passphrase-123']);
        $response->assertOk()->assertHeader('Cache-Control', 'private, no-store, max-age=0');
        $export = json_decode($response->streamedContent(), true, 512, JSON_THROW_ON_ERROR);
        $this->assertSame('dilemin-account-export-v1', $export['format']);
        $this->assertSame('owner@example.org', $export['account']['email']);
        $this->assertSame('Private biography', $export['account']['bio']);
        $this->assertSame([(string) $stranger->id], $export['blocked_user_ids']);
        $this->assertCount(1, $export['messages']);
        $this->assertSame('Allowed incoming', $export['messages'][0]['body']);
        $this->assertSame('binary-photo', base64_decode($export['profile_photo']['jpeg_base64'], true));
        $this->assertStringNotContainsString('PRIVATE FOREIGN MESSAGE', json_encode($export));
        $this->assertStringNotContainsString('stranger@example.org', json_encode($export));
    }
}
