<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\PresenceStore;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DiscoveryController extends Controller
{
    public function online(Request $request, PresenceStore $presence): JsonResponse
    {
        $ids = array_diff($presence->onlineIds(), [$request->user()->id]);
        if ($ids === []) {
            return response()->json(['data' => []]);
        }
        // The response never includes contact information, birthdates, or coordinates.
        $blocked = DB::table('blocks')->select('blocked_id')
            ->where('blocker_id', $request->user()->id);
        $blockedBy = DB::table('blocks')->select('blocker_id')
            ->where('blocked_id', $request->user()->id);

        $people = User::query()
            ->whereIn('id', $ids)
            ->where('online_visible', true)
            ->whereNotIn('id', $blocked)
            ->whereNotIn('id', $blockedBy)
            ->orderBy('id')
            ->limit(200)
            ->get(['id', 'name', 'bio'])
            ->map(fn (User $user): array => [
                'id' => (string) $user->id,
                'display_name' => $user->name,
                'bio' => $user->bio,
            ]);

        return response()->json(['data' => $people]);
    }
}
