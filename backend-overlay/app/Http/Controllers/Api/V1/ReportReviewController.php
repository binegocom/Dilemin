<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ReportReviewController extends Controller
{
    private function authorizeModerator(Request $request): void
    {
        abort_unless($request->user()->is_moderator, 403);
    }

    public function index(Request $request): JsonResponse
    {
        $this->authorizeModerator($request);
        $reports = DB::table('user_reports as r')
            ->join('users as author', 'author.id', '=', 'r.reporter_id')
            ->leftJoin('users as target', 'target.id', '=', 'r.reported_user_id')
            ->where('r.status', 'pending')->orderBy('r.created_at')->limit(50)
            ->get(['r.id', 'r.reporter_id', 'author.name as reporter_name',
                'r.reported_user_id', 'target.name as reported_name',
                'r.reason', 'r.details', 'r.created_at']);
        return response()->json(['data' => $reports->map(fn ($item): array => [
            'id' => (string) $item->id,
            'reporter_id' => (string) $item->reporter_id,
            'reporter_name' => $item->reporter_name,
            'reported_user_id' => $item->reported_user_id === null ? null : (string) $item->reported_user_id,
            'reported_name' => $item->reported_name,
            'reason' => $item->reason,
            'details' => $item->details,
            'created_at' => $item->created_at,
        ])]);
    }

    public function review(Request $request, int $report): JsonResponse
    {
        $this->authorizeModerator($request);
        $data = $request->validate([
            'decision' => ['required', 'in:reviewed,dismissed'],
            'note' => ['nullable', 'string', 'max:500'],
        ]);
        $changed = DB::table('user_reports')->where('id', $report)->where('status', 'pending')
            ->update(['status' => $data['decision'], 'review_note' => $data['note'] ?? null,
                'reviewed_by' => $request->user()->id, 'reviewed_at' => now(),
                'updated_at' => now()]);
        abort_unless($changed, 409);
        return response()->json(['status' => $data['decision']]);
    }
}
