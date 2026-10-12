<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class BlockController extends Controller
{
    public function store(Request $request, User $user): JsonResponse
    {
        abort_if($request->user()->is($user), 422);
        DB::table('blocks')->insertOrIgnore([
            'blocker_id' => $request->user()->id,
            'blocked_id' => $user->id,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        return response()->json(['status' => 'ok']);
    }

    public function destroy(Request $request, User $user): JsonResponse
    {
        DB::table('blocks')
            ->where('blocker_id', $request->user()->id)
            ->where('blocked_id', $user->id)->delete();
        return response()->json(['status' => 'ok']);
    }
}
