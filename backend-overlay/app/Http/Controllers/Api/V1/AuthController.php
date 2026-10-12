<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\PresenceStore;
use App\Support\PublicUser;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        $request->merge(['email' => mb_strtolower(trim((string) $request->input('email')))]);
        $data = Validator::make($request->all(), [
            'display_name' => ['required', 'string', 'min:2', 'max:80'],
            'email' => ['required', 'email', 'max:254', Rule::unique('users', 'email')],
            'password' => ['required', 'string', 'min:12', 'max:128'],
            'date_of_birth' => ['required', 'date_format:Y-m-d', 'before_or_equal:'.now()->subYears(18)->toDateString()],
        ])->validate();

        $user = User::create([
            'name' => $data['display_name'],
            'email' => mb_strtolower(trim($data['email'])),
            'password' => $data['password'],
            'date_of_birth' => $data['date_of_birth'],
            'online_visible' => false,
        ]);

        return response()->json([
            'user' => PublicUser::serialize($user, true),
            'token' => $user->createToken('dilemin-mobile', ['*'], now()->addDays(30))->plainTextToken,
        ], 201);
    }

    public function login(Request $request): JsonResponse
    {
        $request->merge(['email' => mb_strtolower(trim((string) $request->input('email')))]);
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);
        $user = User::where('email', mb_strtolower(trim($data['email'])))->first();
        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages(['email' => ['Invalid credentials.']]);
        }
        if ($user->date_of_birth === null || $user->date_of_birth->gt(now()->subYears(18))) {
            abort(403, 'Age verification required.');
        }

        return response()->json([
            'user' => PublicUser::serialize($user, true),
            'token' => $user->createToken('dilemin-mobile', ['*'], now()->addDays(30))->plainTextToken,
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json(['user' => PublicUser::serialize($request->user(), true)]);
    }

    public function logout(Request $request, PresenceStore $presence): JsonResponse
    {
        $sessionId = PresenceStore::sessionId($request);
        try {
            if ($sessionId === null) $presence->markOffline($request->user()->id);
            else $presence->markOffline($request->user()->id, $sessionId);
        } catch (\Throwable $exception) {
            // Presence has an expiry; a Redis outage must never prevent revoking a session.
            report($exception);
        } finally {
            $request->user()->currentAccessToken()?->delete();
        }
        return response()->json(['status' => 'ok']);
    }
}
