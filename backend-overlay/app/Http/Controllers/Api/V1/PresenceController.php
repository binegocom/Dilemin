<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Support\PresenceStore;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PresenceController extends Controller
{
    public function heartbeat(Request $request, PresenceStore $presence): JsonResponse
    {
        $user = $request->user();
        if ($user->online_visible) {
            $presence->markOnline($user->id);
        } else {
            $presence->markOffline($user->id);
        }
        return response()->json(['status' => 'ok']);
    }

    public function offline(Request $request, PresenceStore $presence): JsonResponse
    {
        $presence->markOffline($request->user()->id);
        return response()->json(['status' => 'ok']);
    }
}
