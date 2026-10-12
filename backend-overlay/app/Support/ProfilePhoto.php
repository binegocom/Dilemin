<?php

namespace App\Support;

use App\Models\User;
use Illuminate\Support\Facades\DB;

final class ProfilePhoto
{
    public static function forUser(User $user, bool $owner = false): array
    {
        $photo = DB::table('profile_photos')->where('user_id', $user->id)->first(['id', 'status']);
        if (! $photo) {
            return ['photo_id' => null, 'photo_status' => $owner ? 'none' : null];
        }
        if ($photo->status !== 'approved') {
            return ['photo_id' => $owner ? (string) $photo->id : null,
                'photo_status' => $owner ? $photo->status : null];
        }
        return ['photo_id' => (string) $photo->id, 'photo_status' => 'approved'];
    }
}
