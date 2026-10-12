<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Support\PublicUser;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class NotificationPreferenceController extends Controller
{
    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'push_messages_enabled' => ['required', 'boolean'],
        ]);
        $user = $request->user();
        $user->forceFill([
            'push_messages_enabled' => $data['push_messages_enabled'],
        ])->save();

        return response()->json(['user' => PublicUser::serialize($user, true)]);
    }
}
