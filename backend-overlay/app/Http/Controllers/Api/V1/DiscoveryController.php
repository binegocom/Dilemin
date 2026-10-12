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
            ->leftJoin('profile_photos as photo', function ($join): void {
                $join->on('photo.user_id', '=', 'users.id')->where('photo.status', '=', 'approved');
            })
            ->whereIn('users.id', $ids)
            ->where('users.online_visible', true)
            ->whereNull('users.suspended_at')
            ->whereNotIn('users.id', $blocked)
            ->whereNotIn('users.id', $blockedBy)
            ->orderBy('users.id')
            ->limit(200)
            ->get(['users.id', 'users.name', 'users.bio', 'photo.id as photo_id'])
            ->map(fn (User $user): array => [
                'id' => (string) $user->id,
                'display_name' => $user->name,
                'bio' => $user->bio,
                'photo_id' => $user->photo_id === null ? null : (string) $user->photo_id,
            ]);

        return response()->json(['data' => $people]);
    }
}
