<?php

namespace App\Support;

use App\Models\User;

final class PublicUser
{
    public static function serialize(User $user, bool $owner = false): array
    {
        return [
            'id' => (string) $user->id,
            'display_name' => $user->name,
            'bio' => $user->bio,
            'online_visible' => (bool) $user->online_visible,
            ...ProfilePhoto::forUser($user, $owner),
            ...($owner ? ['is_moderator' => (bool) $user->is_moderator] : []),
        ];
    }
}
