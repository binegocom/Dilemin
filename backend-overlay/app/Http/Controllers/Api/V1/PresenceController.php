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
        $sessionId = PresenceStore::sessionId($request);
        if ($user->online_visible) {
            if ($sessionId !== null) $presence->markOnline($user->id, $sessionId);
            else $presence->markOnline($user->id);
        } else {
            $presence->markOffline($user->id);
        }
        return response()->json(['status' => 'ok']);
    }

    public function offline(Request $request, PresenceStore $presence): JsonResponse
    {
        $sessionId = PresenceStore::sessionId($request);
        if ($sessionId === null) $presence->markOffline($request->user()->id);
        else $presence->markOffline($request->user()->id, $sessionId);
        return response()->json(['status' => 'ok']);
    }
}
