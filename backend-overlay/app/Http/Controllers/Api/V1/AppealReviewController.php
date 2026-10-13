<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class AppealReviewController extends Controller
{
    private function authorizeModerator(Request $request): void
    {
        abort_unless($request->user()->is_moderator, 403);
    }

    public function index(Request $request): JsonResponse
    {
        $this->authorizeModerator($request);
        $rows = DB::table('account_appeals as a')
            ->join('users as u', 'u.id', '=', 'a.user_id')
            ->where('a.status', 'pending')
            ->whereColumn('u.suspended_at', 'a.suspended_at')
            ->where('u.is_moderator', false)
            ->orderBy('a.created_at')->orderBy('a.id')
            ->limit(100)
            ->get(['a.id', 'a.user_id', 'u.name as display_name',
                'a.statement', 'a.created_at']);

        return response()->json(['data' => $rows->map(fn ($row) => [
            'id' => (string) $row->id,
            'user_id' => (string) $row->user_id,
            'display_name' => $row->display_name,
            'statement' => $row->statement,
            'created_at' => $row->created_at,
        ])]);
    }

    public function review(Request $request, int $appeal): JsonResponse
    {
        $this->authorizeModerator($request);
        $data = $request->validate([
            'decision' => ['required', 'in:restored,rejected'],
            'note' => ['required', 'string', 'min:5', 'max:500'],
        ]);

        DB::transaction(function () use ($request, $appeal, $data): void {
            $row = DB::table('account_appeals')->where('id', $appeal)
                ->lockForUpdate()->first();
            abort_unless($row && $row->status === 'pending', 409);

            $user = DB::table('users')->where('id', $row->user_id)
                ->lockForUpdate()->first();
            abort_unless($user && ! $user->is_moderator &&
                $user->suspended_at !== null &&
                (string) $user->suspended_at === (string) $row->suspended_at, 409);

            if ($data['decision'] === 'restored') {
                DB::table('users')->where('id', $user->id)->update([
                    'suspended_at' => null,
                    'online_visible' => false,
                    'updated_at' => now(),
                ]);
            }
            DB::table('account_appeals')->where('id', $row->id)->update([
                'status' => $data['decision'],
                'review_note' => $data['note'],
                'reviewed_by' => $request->user()->id,
                'reviewed_at' => now(),
                'updated_at' => now(),
            ]);
            DB::table('moderation_actions')->insert([
                'moderator_id' => $request->user()->id,
                'target_user_id' => $user->id,
                'report_id' => null,
                'action' => $data['decision'] === 'restored' ? 'appeal_restored' : 'appeal_rejected',
                'reason' => $data['note'],
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        });

        return response()->json(['status' => $data['decision']]);
    }
}
