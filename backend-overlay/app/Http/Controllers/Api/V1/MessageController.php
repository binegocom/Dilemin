<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Support\SocialAccess;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class MessageController extends Controller
{
    private function authorizedConversation(Request $request, int $id): object
    {
        $conversation = DB::table('conversations')->where('id', $id)->first();
        abort_unless($conversation, 404);
        $actor = $request->user()->id;
        abort_unless($actor === $conversation->user_low_id || $actor === $conversation->user_high_id, 404);
        abort_if(SocialAccess::blocked($conversation->user_low_id, $conversation->user_high_id), 403);
        return $conversation;
    }

    public function index(Request $request, int $conversation): JsonResponse
    {
        $this->authorizedConversation($request, $conversation);
        $cursor = $request->validate(['before_id' => ['sometimes', 'integer', 'min:1']]);
        $query = DB::table('messages')->where('conversation_id', $conversation);
        if (isset($cursor['before_id'])) $query->where('id', '<', $cursor['before_id']);
        return response()->json(['data' => $query->orderByDesc('id')->limit(50)
            ->get(['id', 'sender_id', 'body', 'created_at'])
            ->map(fn ($row) => [
                'id' => (string) $row->id,
                'sender_id' => (string) $row->sender_id,
                'body' => $row->body,
                'created_at' => $row->created_at,
            ])]);
    }

    public function markRead(Request $request, int $conversation): JsonResponse
    {
        $this->authorizedConversation($request, $conversation);
        $data = $request->validate(['message_id' => ['required', 'integer', 'min:1']]);
        $actorId = $request->user()->id;
        DB::transaction(function () use ($conversation, $actorId, $data): void {
            $row = DB::table('conversations')->where('id', $conversation)->lockForUpdate()->first();
            abort_unless($row, 404);
            abort_unless($actorId === $row->user_low_id || $actorId === $row->user_high_id, 404);
            abort_if(SocialAccess::blocked($row->user_low_id, $row->user_high_id), 403);
            abort_unless(DB::table('messages')->where('conversation_id', $conversation)
                ->where('id', $data['message_id'])->exists(), 422);
            $field = $actorId === $row->user_low_id
                ? 'last_read_low_message_id' : 'last_read_high_message_id';
            if ((int) $data['message_id'] > (int) ($row->{$field} ?? 0)) {
                DB::table('conversations')->where('id', $conversation)->update([
                    $field => $data['message_id'],
                ]);
            }
        });
        return response()->json(['status' => 'read']);
    }

    public function store(Request $request, int $conversation): JsonResponse
    {
        $this->authorizedConversation($request, $conversation);
        $data = $request->validate([
            'body' => ['required', 'string', 'max:2000'],
            'client_id' => ['required', 'uuid'],
        ]);
        $senderId = $request->user()->id;
        $existing = DB::table('messages')->where('sender_id', $senderId)
            ->where('client_id', $data['client_id'])->first();
        if ($existing) {
            abort_unless($existing->conversation_id === $conversation && $existing->body === $data['body'], 409);
            return response()->json(['id' => (string) $existing->id], 200);
        }
        $inserted = DB::table('messages')->insertOrIgnore([
            'conversation_id' => $conversation,
            'sender_id' => $senderId,
            'client_id' => $data['client_id'],
            'body' => $data['body'],
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $saved = DB::table('messages')->where('sender_id', $senderId)
            ->where('client_id', $data['client_id'])->first();
        abort_unless($saved && $saved->conversation_id === $conversation && $saved->body === $data['body'], 409);
        if ($inserted) DB::table('conversations')->where('id', $conversation)->update(['updated_at' => now()]);
        return response()->json(['id' => (string) $saved->id], $inserted ? 201 : 200);
    }
}
