<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Support\SocialAccess;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class RealtimeAuthorizationController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        // Sanctum authentication and verified email are enforced at the router.
        $input = $request->validate([
            'socket_id' => ['required', 'string', 'regex:/^[0-9]+\.[0-9]+$/', 'max:80'],
            'channel_name' => [
                'required', 'string',
                'regex:/^private-(users|conversations)\.[1-9][0-9]{0,18}$/',
                'max:100',
            ],
        ]);

        $user = $request->user();
        abort_unless($user && $user->hasVerifiedEmail(), 403);

        $channelName = $input['channel_name'];
        $channel = substr($channelName, strlen('private-'));
        [$type, $identifier] = explode('.', $channel, 2);
        if ($type === 'users') {
            abort_unless((int) $user->id === (int) $identifier, 403);
        } else {
            $conversation = DB::table('conversations')->where('id', $identifier)->first();
            abort_unless($conversation, 403);
            $low = (int) $conversation->user_low_id;
            $high = (int) $conversation->user_high_id;
            abort_unless((int) $user->id === $low || (int) $user->id === $high, 403);
            abort_if(SocialAccess::blocked($low, $high), 403);
        }

        $key = config('broadcasting.connections.reverb.key');
        $secret = config('broadcasting.connections.reverb.secret');
        // Configuration failures must never silently generate invalid signatures.
        abort_unless(is_string($key) && $key !== '' &&
            is_string($secret) && $secret !== '', 503);

        $message = $input['socket_id'].':'.$channelName;
        return response()->json([
            'auth' => $key.':'.hash_hmac('sha256', $message, $secret),
        ]);
    }
}
