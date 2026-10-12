<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\PresenceStore;
use App\Support\PublicUser;
use App\Support\SocialAccess;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProfileController extends Controller
{
    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'display_name' => ['sometimes', 'required', 'string', 'min:2', 'max:80'],
            'bio' => ['sometimes', 'nullable', 'string', 'max:500'],
        ]);
        $user = $request->user();
        if (array_key_exists('display_name', $data)) $user->name = $data['display_name'];
        if (array_key_exists('bio', $data)) $user->bio = $data['bio'];
        $user->save();
        return response()->json(['user' => PublicUser::serialize($user)]);
    }

    public function show(Request $request, User $user, PresenceStore $presence): JsonResponse
    {
        abort_if($request->user()->is($user), 404);
        abort_if(SocialAccess::blocked($request->user()->id, $user->id), 404);
        abort_unless($user->online_visible && in_array($user->id, $presence->onlineIds(), true), 404);
        return response()->json(['user' => PublicUser::serialize($user)]);
    }
}
