<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\PresenceStore;
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
            'decision' => ['required', 'in:reviewed,dismissed,suspended'],
            'note' => ['required_if:decision,suspended', 'nullable', 'string', 'min:3', 'max:500'],
        ]);
        $targetId = DB::transaction(function () use ($request, $report, $data): ?int {
            $record = DB::table('user_reports')->where('id', $report)
                ->lockForUpdate()->first();
            abort_unless($record && $record->status === 'pending', 409);
            $targetId = null;
            if ($data['decision'] === 'suspended') {
                $targetId = (int) $record->reported_user_id;
                abort_unless($targetId > 0 && $targetId !== (int) $request->user()->id, 422);
                $target = DB::table('users')->where('id', $targetId)
                    ->lockForUpdate()->first();
                abort_unless($target, 422);
                abort_if($target->suspended_at !== null, 409, 'Account already suspended.');
                abort_if((bool) $target->is_moderator, 403,
                    'Staff accounts require separate administrative review.');
                DB::table('users')->where('id', $targetId)->update([
                    'suspended_at' => now(), 'online_visible' => false,
                    'updated_at' => now(),
                ]);
                DB::table('moderation_actions')->insert([
                    'moderator_id' => $request->user()->id,
                    'target_user_id' => $targetId,
                    'report_id' => $report,
                    'action' => 'suspended',
                    'reason' => $data['note'],
                    'created_at' => now(), 'updated_at' => now(),
                ]);
            }
            DB::table('user_reports')->where('id', $report)->update([
                'status' => $data['decision'],
                'review_note' => $data['note'] ?? null,
                'reviewed_by' => $request->user()->id,
                'reviewed_at' => now(),
                'updated_at' => now(),
            ]);

            return $targetId;
        });
        if ($targetId !== null) {
            try {
                app(PresenceStore::class)->markOffline($targetId);
            } catch (\Throwable $exception) {
                // The database suspension immediately blocks discovery and
                // messaging; cached presence also expires automatically.
                report($exception);
            }
        }
        return response()->json(['status' => $data['decision']]);
    }

    public function suspended(Request $request): JsonResponse
    {
        $this->authorizeModerator($request);
        $rows = DB::table('users')
            ->whereNotNull('suspended_at')
            ->where('is_moderator', false)
            ->orderByDesc('suspended_at')
            ->limit(100)
            ->get(['id', 'name', 'suspended_at']);

        return response()->json(['data' => $rows->map(fn ($row): array => [
            'id' => (string) $row->id,
            'display_name' => $row->name,
            'suspended_at' => $row->suspended_at,
        ])]);
    }

    public function restore(Request $request, User $user): JsonResponse
    {
        $this->authorizeModerator($request);
        abort_if($user->is($request->user()) || $user->is_moderator, 403);
        $data = $request->validate([
            'reason' => ['required', 'string', 'min:3', 'max:500'],
        ]);
        DB::transaction(function () use ($request, $user, $data): void {
            $locked = DB::table('users')->where('id', $user->id)
                ->lockForUpdate()->first();
            abort_unless($locked && $locked->suspended_at !== null, 409);
            DB::table('users')->where('id', $user->id)->update([
                'suspended_at' => null,
                'online_visible' => false,
                'updated_at' => now(),
            ]);
            DB::table('account_appeals')->where('user_id', $user->id)
                ->where('suspended_at', $locked->suspended_at)
                ->where('status', 'pending')->update([
                    'status' => 'restored',
                    'review_note' => $data['reason'],
                    'reviewed_by' => $request->user()->id,
                    'reviewed_at' => now(),
                    'updated_at' => now(),
                ]);
            DB::table('moderation_actions')->insert([
                'moderator_id' => $request->user()->id,
                'target_user_id' => $user->id,
                'report_id' => null,
                'action' => 'restored',
                'reason' => $data['reason'],
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        });

        return response()->json(['status' => 'restored']);
    }
}
