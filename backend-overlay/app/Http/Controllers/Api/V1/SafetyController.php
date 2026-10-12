<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\PresenceStore;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class SafetyController extends Controller
{
    public function report(Request $request, User $user): JsonResponse
    {
        abort_if($request->user()->is($user), 422);
        $data = $request->validate([
            'reason' => ['required', 'in:spam,harassment,impersonation,underage,other'],
            'details' => ['nullable', 'string', 'max:1000'],
        ]);
        DB::table('user_reports')->insert([
            'reporter_id' => $request->user()->id,
            'reported_user_id' => $user->id,
            'reason' => $data['reason'],
            'details' => $data['details'] ?? null,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        return response()->json(['status' => 'received'], 201);
    }

    public function deleteAccount(Request $request, PresenceStore $presence): JsonResponse
    {
        $data = $request->validate(['password' => ['required', 'string']]);
        $user = $request->user();
        abort_unless(Hash::check($data['password'], $user->password), 422);
        $presence->markOffline($user->id);
        DB::transaction(function () use ($user): void {
            $user->tokens()->delete();
            $user->delete();
        });
        return response()->json(['status' => 'deleted']);
    }
}
