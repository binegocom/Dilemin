<?php

use App\Support\SocialAccess;
use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\Facades\DB;

Broadcast::channel('users.{userId}', function ($user, string $userId): bool {
    return (int) $user->id === (int) $userId && $user->hasVerifiedEmail();
});

Broadcast::channel('conversations.{conversationId}', function ($user, string $conversationId): bool {
    if (! $user->hasVerifiedEmail()) return false;
    $row = DB::table('conversations')->where('id', $conversationId)->first();
    if (! $row) return false;
    if ((int) $user->id !== (int) $row->user_low_id
        && (int) $user->id !== (int) $row->user_high_id) return false;
    return ! SocialAccess::blocked((int) $row->user_low_id, (int) $row->user_high_id);
});
