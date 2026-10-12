<?php

namespace App\Support;

use App\Models\User;
use Illuminate\Support\Facades\DB;

final class SocialAccess
{
    public static function blocked(int $a, int $b): bool
    {
        if (DB::table('users')->whereIn('id', [$a, $b])
            ->whereNotNull('suspended_at')->exists()) return true;

        return DB::table('blocks')
            ->where(function ($query) use ($a, $b): void {
                $query->where('blocker_id', $a)->where('blocked_id', $b);
            })
            ->orWhere(function ($query) use ($a, $b): void {
                $query->where('blocker_id', $b)->where('blocked_id', $a);
            })
            ->exists();
    }

    public static function canCommunicate(User $actor, User $recipient): bool
    {
        return $actor->id !== $recipient->id && ! self::blocked($actor->id, $recipient->id);
    }
}
