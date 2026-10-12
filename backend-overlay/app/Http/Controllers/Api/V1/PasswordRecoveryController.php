<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Notifications\PasswordRecoveryCode;
use App\Support\PresenceStore;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class PasswordRecoveryController extends Controller
{
    public function requestCode(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email', 'max:254'],
            'locale' => ['required', Rule::in(['de', 'fr', 'it', 'en'])],
        ]);
        $email = mb_strtolower(trim($data['email']));
        $user = User::where('email', $email)->first();

        if ($user) {
            DB::transaction(function () use ($user, $data): void {
                User::whereKey($user->id)->lockForUpdate()->firstOrFail();
                $existing = DB::table('password_recovery_codes')->where('user_id', $user->id)->first();
                if ($existing && now()->lt(\Carbon\Carbon::parse($existing->last_sent_at)->addSeconds(90))) {
                    return;
                }
                $code = (string) random_int(100000, 999999);
                DB::table('password_recovery_codes')->updateOrInsert(['user_id' => $user->id], [
                    'code_hash' => Hash::make($code), 'attempts' => 0,
                    'expires_at' => now()->addMinutes(10), 'last_sent_at' => now(),
                ]);
                Notification::send($user, new PasswordRecoveryCode($code, $data['locale']));
            });
        }
        // A uniform response prevents simple email enumeration.
        return response()->json(['status' => 'accepted']);
    }

    public function confirm(Request $request, PresenceStore $presence): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email', 'max:254'],
            'code' => ['required', 'digits:6'],
            'password' => ['required', 'string', 'min:12', 'max:128'],
        ]);
        $email = mb_strtolower(trim($data['email']));
        $user = User::where('email', $email)->first();
        if (! $user) {
            throw ValidationException::withMessages(['code' => ['Invalid or expired recovery code.']]);
        }

        $result = DB::transaction(function () use ($user, $data): string {
            $lockedUser = User::whereKey($user->id)->lockForUpdate()->firstOrFail();
            $record = DB::table('password_recovery_codes')->where('user_id', $user->id)->lockForUpdate()->first();
            if (! $record) return 'invalid';
            if (now()->gt($record->expires_at)) {
                DB::table('password_recovery_codes')->where('user_id', $user->id)->delete();
                return 'invalid';
            }
            if ($record->attempts >= 5) return 'locked';
            if (! Hash::check($data['code'], $record->code_hash)) {
                DB::table('password_recovery_codes')->where('user_id', $user->id)
                    ->update(['attempts' => $record->attempts + 1]);
                return 'invalid';
            }
            $lockedUser->forceFill(['password' => $data['password']])->save();
            $lockedUser->tokens()->delete();
            DB::table('password_recovery_codes')->where('user_id', $user->id)->delete();
            return 'success';
        });
        abort_if($result === 'locked', 429);
        if ($result !== 'success') {
            throw ValidationException::withMessages(['code' => ['Invalid or expired recovery code.']]);
        }
        $presence->markOffline($user->id);
        return response()->json(['status' => 'updated']);
    }
}
