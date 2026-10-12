<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\PersonalAccessToken;

final class SessionController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $currentId = $user->currentAccessToken() instanceof PersonalAccessToken
            ? $user->currentAccessToken()->getKey() : null;

        $tokens = $user->tokens()
            ->orderByDesc('created_at')
            ->limit(100)
            ->get(['id', 'name', 'created_at', 'last_used_at', 'expires_at']);

        return response()->json(['data' => $tokens->map(fn ($token) => [
            'id' => (string) $token->getKey(),
            'name' => (string) $token->name,
            'created_at' => $token->created_at?->toIso8601String(),
            'last_used_at' => $token->last_used_at?->toIso8601String(),
            'expires_at' => $token->expires_at?->toIso8601String(),
            'current' => $currentId !== null && (string) $currentId === (string) $token->getKey(),
        ])->all()]);
    }

    public function destroy(Request $request, string $token): JsonResponse
    {
        // Both the query and the deletion must be scoped to the authenticated account.
        $session = $request->user()->tokens()->whereKey($token)->first();
        abort_unless($session, 404);
        $current = $request->user()->currentAccessToken();
        abort_if($current instanceof PersonalAccessToken
            && (string) $current->getKey() === (string) $session->getKey(), 409,
            'Sign out from the current device using Logout.');
        $session->delete();
        return response()->json(['status' => 'revoked']);
    }

    public function revokeOthers(Request $request): JsonResponse
    {
        $data = $request->validate(['password' => ['required', 'string']]);
        abort_unless(Hash::check($data['password'], $request->user()->password), 422);
        $current = $request->user()->currentAccessToken();
        abort_unless($current instanceof PersonalAccessToken, 409,
            'Current session is not a personal access token.');
        $count = $request->user()->tokens()->whereKeyNot($current->getKey())->delete();
        return response()->json(['status' => 'revoked', 'count' => $count]);
    }
}
