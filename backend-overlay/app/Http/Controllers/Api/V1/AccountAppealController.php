<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class AccountAppealController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_unless($user->suspended_at, 403);
        $appeal = DB::table('account_appeals')->where('user_id', $user->id)
            ->where('suspended_at', $user->suspended_at)
            ->first(['id', 'status', 'statement', 'review_note', 'created_at', 'reviewed_at']);

        return response()->json(['appeal' => $appeal === null ? null : [
            'id' => (string) $appeal->id,
            'status' => $appeal->status,
            'statement' => $appeal->statement,
            'review_note' => $appeal->review_note,
            'created_at' => $appeal->created_at,
            'reviewed_at' => $appeal->reviewed_at,
        ]]);
    }

    public function store(Request $request): JsonResponse
    {
        $input = $request->validate([
            'statement' => ['required', 'string', 'min:20', 'max:2000'],
        ]);
        $id = DB::transaction(function () use ($request, $input): int {
            $user = DB::table('users')->where('id', $request->user()->id)
                ->lockForUpdate()->first(['id', 'suspended_at']);
            abort_unless($user && $user->suspended_at !== null, 403);
            abort_if(DB::table('account_appeals')->where('user_id', $user->id)
                ->where('suspended_at', $user->suspended_at)->exists(), 409,
                'This suspension already has an appeal.');

            return (int) DB::table('account_appeals')->insertGetId([
                'user_id' => $user->id,
                'suspended_at' => $user->suspended_at,
                'status' => 'pending',
                'statement' => trim($input['statement']),
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        });

        return response()->json(['id' => (string) $id, 'status' => 'pending'], 201);
    }
}
