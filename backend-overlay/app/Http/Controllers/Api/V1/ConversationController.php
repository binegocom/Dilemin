<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\PresenceStore;
use App\Support\SocialAccess;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ConversationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $id = $request->user()->id;
        $rows = DB::table('conversations as c')
            ->join('users as low', 'low.id', '=', 'c.user_low_id')
            ->join('users as high', 'high.id', '=', 'c.user_high_id')
            ->where(fn ($q) => $q->where('c.user_low_id', $id)->orWhere('c.user_high_id', $id))
            ->whereNotExists(function ($q) use ($id): void {
                $q->selectRaw('1')->from('blocks as b')
                    ->where(fn ($sub) => $sub->whereColumn('b.blocker_id', 'c.user_low_id')->whereColumn('b.blocked_id', 'c.user_high_id'))
                    ->orWhere(fn ($sub) => $sub->whereColumn('b.blocker_id', 'c.user_high_id')->whereColumn('b.blocked_id', 'c.user_low_id'));
            })
            ->orderByDesc('c.updated_at')->orderByDesc('c.id')->limit(50)
            ->get(['c.id', 'c.user_low_id', 'c.user_high_id', 'low.name as low_name', 'high.name as high_name', 'c.updated_at']);

        return response()->json(['data' => $rows->map(fn ($row) => [
            'id' => (string) $row->id,
            'person' => [
                'id' => (string) ($row->user_low_id === $id ? $row->user_high_id : $row->user_low_id),
                'display_name' => $row->user_low_id === $id ? $row->high_name : $row->low_name,
            ],
            'updated_at' => $row->updated_at,
        ])]);
    }

    public function store(Request $request, PresenceStore $presence): JsonResponse
    {
        $data = $request->validate(['recipient_id' => ['required', 'integer', 'exists:users,id']]);
        $actor = $request->user();
        $recipient = User::findOrFail($data['recipient_id']);
        abort_unless(SocialAccess::canCommunicate($actor, $recipient), 403);

        $ids = [$actor->id, $recipient->id];
        sort($ids, SORT_NUMERIC);
        $existing = DB::table('conversations')->where('user_low_id', $ids[0])
            ->where('user_high_id', $ids[1])->first();
        if ($existing) return response()->json(['id' => (string) $existing->id]);

        abort_unless($recipient->online_visible && in_array($recipient->id, $presence->onlineIds(), true), 403);
        $created = DB::table('conversations')->insertOrIgnore([
            'user_low_id' => $ids[0], 'user_high_id' => $ids[1],
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $conversation = DB::table('conversations')->where('user_low_id', $ids[0])
            ->where('user_high_id', $ids[1])->first();
        abort_unless($conversation, 500);
        return response()->json(['id' => (string) $conversation->id], $created ? 201 : 200);
    }
}
