<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Notifications\EmailVerificationCode;
use App\Support\PublicUser;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class EmailVerificationController extends Controller
{
    public function requestCode(Request $request): JsonResponse
    {
        $data = $request->validate(['locale' => ['required', Rule::in(['de', 'fr', 'it', 'en'])]]);
        $user = $request->user();
        abort_if($user->hasVerifiedEmail(), 409);

        DB::transaction(function () use ($user, $data): void {
            // The row lock prevents simultaneous requests from bypassing the resend cooldown.
            $lockedUser = User::whereKey($user->id)->lockForUpdate()->firstOrFail();
            abort_if($lockedUser->hasVerifiedEmail(), 409);
            $existing = DB::table('email_verification_codes')->where('user_id', $user->id)->first();
            abort_if($existing && now()->lt(\Carbon\Carbon::parse($existing->last_sent_at)->addSeconds(60)), 429);

            $code = (string) random_int(100000, 999999);
            DB::table('email_verification_codes')->updateOrInsert(['user_id' => $user->id], [
                'code_hash' => Hash::make($code), 'attempts' => 0,
                'expires_at' => now()->addMinutes(10), 'last_sent_at' => now(),
            ]);
            Notification::send($lockedUser, new EmailVerificationCode($code, $data['locale']));
        });
        return response()->json(['status' => 'sent']);
    }

    public function confirm(Request $request): JsonResponse
    {
        $data = $request->validate(['code' => ['required', 'digits:6']]);
        $user = $request->user();
        if ($user->hasVerifiedEmail()) {
            return response()->json(['user' => PublicUser::serialize($user, true)]);
        }
        $result = DB::transaction(function () use ($user, $data): string {
            User::whereKey($user->id)->lockForUpdate()->firstOrFail();
            $record = DB::table('email_verification_codes')->where('user_id', $user->id)->lockForUpdate()->first();
            if (! $record) return 'invalid';
            if (now()->gt($record->expires_at)) {
                DB::table('email_verification_codes')->where('user_id', $user->id)->delete();
                return 'expired';
            }
            if ($record->attempts >= 5) return 'locked';
            if (! Hash::check($data['code'], $record->code_hash)) {
                DB::table('email_verification_codes')->where('user_id', $user->id)
                    ->update(['attempts' => $record->attempts + 1]);
                return 'invalid';
            }
            DB::table('users')->where('id', $user->id)->whereNull('email_verified_at')
                ->update(['email_verified_at' => now()]);
            DB::table('email_verification_codes')->where('user_id', $user->id)->delete();
            return 'verified';
        });
        abort_if($result === 'locked', 429);
        if ($result !== 'verified') {
            throw ValidationException::withMessages(['code' => ['Invalid or expired verification code.']]);
        }
        return response()->json(['user' => PublicUser::serialize($user->fresh(), true)]);
    }
}
