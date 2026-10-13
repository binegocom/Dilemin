<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

final class DataExportController extends Controller
{
    public function download(Request $request): StreamedResponse
    {
        $data = $request->validate(['password' => ['required', 'string']]);
        $user = $request->user();
        abort_unless(Hash::check($data['password'], $user->password), 422);

        $account = [
            'id' => (string) $user->id,
            'email' => $user->email,
            'display_name' => $user->name,
            'date_of_birth' => $user->date_of_birth?->toDateString(),
            'bio' => $user->bio,
            'online_visible' => (bool) $user->online_visible,
            'push_messages_enabled' => (bool) $user->push_messages_enabled,
            'email_verified_at' => $user->email_verified_at?->toIso8601String(),
            'created_at' => $user->created_at?->toIso8601String(),
        ];
        $userId = (int) $user->id;

        // Streaming avoids loading the entire conversation history into PHP memory.
        return response()->streamDownload(function () use ($userId, $account): void {
            echo '{"format":"dilemin-account-export-v1","account":';
            echo json_encode($account, JSON_THROW_ON_ERROR | JSON_INVALID_UTF8_SUBSTITUTE);

            echo ',"blocked_user_ids":[';
            $first = true;
            foreach (DB::table('blocks')->where('blocker_id', $userId)
                ->orderBy('id')->cursor(['blocked_id']) as $block) {
                if (! $first) echo ',';
                echo json_encode((string) $block->blocked_id, JSON_THROW_ON_ERROR);
                $first = false;
            }
            echo ']';

            echo ',"reports":[';
            $first = true;
            foreach (DB::table('user_reports')->where('reporter_id', $userId)
                ->orderBy('id')->cursor(['id', 'reported_user_id', 'reason', 'details', 'status', 'created_at']) as $report) {
                if (! $first) echo ',';
                echo json_encode([
                    'id' => (string) $report->id,
                    'reported_user_id' => $report->reported_user_id === null ? null : (string) $report->reported_user_id,
                    'reason' => $report->reason,
                    'details' => $report->details,
                    'status' => $report->status,
                    'created_at' => $report->created_at,
                ], JSON_THROW_ON_ERROR | JSON_INVALID_UTF8_SUBSTITUTE);
                $first = false;
            }
            echo ']';

            echo ',"account_appeals":[';
            $first = true;
            foreach (DB::table('account_appeals')->where('user_id', $userId)
                ->orderBy('id')->cursor(['id', 'status', 'statement', 'review_note',
                    'suspended_at', 'created_at', 'reviewed_at']) as $appeal) {
                if (! $first) echo ',';
                echo json_encode([
                    'id' => (string) $appeal->id,
                    'status' => $appeal->status,
                    'statement' => $appeal->statement,
                    'review_note' => $appeal->review_note,
                    'suspended_at' => $appeal->suspended_at,
                    'created_at' => $appeal->created_at,
                    'reviewed_at' => $appeal->reviewed_at,
                ], JSON_THROW_ON_ERROR | JSON_INVALID_UTF8_SUBSTITUTE);
                $first = false;
            }
            echo ']';

            echo ',"messages":[';
            $first = true;
            foreach (DB::table('messages as m')
                ->join('conversations as c', 'c.id', '=', 'm.conversation_id')
                ->where(fn ($q) => $q->where('c.user_low_id', $userId)->orWhere('c.user_high_id', $userId))
                ->orderBy('m.id')
                ->cursor(['m.id', 'm.conversation_id', 'm.sender_id', 'm.body', 'm.created_at']) as $message) {
                if (! $first) echo ',';
                echo json_encode([
                    'id' => (string) $message->id,
                    'conversation_id' => (string) $message->conversation_id,
                    'sender_id' => (string) $message->sender_id,
                    'body' => $message->body,
                    'created_at' => $message->created_at,
                ], JSON_THROW_ON_ERROR | JSON_INVALID_UTF8_SUBSTITUTE);
                $first = false;
            }
            echo ']';

            // Own photo is included regardless of moderation status; never export another member's photo.
            $photo = DB::table('profile_photos')->where('user_id', $userId)->first();
            echo ',"profile_photo":';
            if ($photo && Storage::disk('local')->exists($photo->private_path)) {
                echo json_encode([
                    'status' => $photo->status,
                    'mime_type' => 'image/jpeg',
                    'jpeg_base64' => base64_encode(Storage::disk('local')->get($photo->private_path)),
                ], JSON_THROW_ON_ERROR);
            } else {
                echo 'null';
            }
            echo '}';
        }, 'dilemin-account-export.json', [
            'Content-Type' => 'application/json; charset=utf-8',
            'Cache-Control' => 'private, no-store, max-age=0',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }
}
