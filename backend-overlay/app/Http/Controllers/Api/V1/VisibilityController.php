<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Support\PresenceStore;
use App\Support\PublicUser;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class VisibilityController extends Controller
{
    public function update(Request $request, PresenceStore $presence): JsonResponse
    {
        $data = $request->validate(['online_visible' => ['required', 'boolean']]);
        $user = $request->user();
        $user->forceFill(['online_visible' => $data['online_visible']])->save();
        if ($user->online_visible) {
            $presence->markOnline($user->id);
        } else {
            $presence->markOffline($user->id);
        }
        return response()->json(['user' => PublicUser::serialize($user)]);
    }
}
