<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class ModerationController extends Controller
{
    private function authorizeModerator(Request $request): void
    {
        abort_unless($request->user()->is_moderator, 403);
    }

    public function index(Request $request): JsonResponse
    {
        $this->authorizeModerator($request);
        $rows = DB::table('profile_photos as p')->join('users as u', 'u.id', '=', 'p.user_id')
            ->where('p.status', 'pending')->where('p.user_id', '!=', $request->user()->id)->orderBy('p.created_at')->limit(50)
            ->get(['p.id', 'p.user_id', 'p.revision', 'u.name as display_name', 'p.created_at']);
        return response()->json(['data' => $rows->map(fn ($row): array => [
            'id' => (string) $row->id,
            'revision' => $row->revision,
            'user_id' => (string) $row->user_id,
            'display_name' => $row->display_name,
            'created_at' => $row->created_at,
        ])]);
    }

    public function photo(Request $request, int $photo): BinaryFileResponse
    {
        $this->authorizeModerator($request);
        $record = DB::table('profile_photos')->where('id', $photo)
            ->where('user_id', '!=', $request->user()->id)->first();
        abort_unless($record, 404);
        abort_unless(Storage::disk('local')->exists($record->private_path), 404);
        return response()->file(Storage::disk('local')->path($record->private_path), [
            'Content-Type' => 'image/jpeg',
            'Cache-Control' => 'private, no-store',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }

    public function review(Request $request, int $photo): JsonResponse
    {
        $this->authorizeModerator($request);
        $data = $request->validate(['decision' => ['required', 'in:approved,rejected'], 'revision' => ['required', 'uuid']]);
        $updated = DB::table('profile_photos')->where('id', $photo)->where('status', 'pending')->where('user_id', '!=', $request->user()->id)
            ->where('revision', $data['revision'])
            ->update(['status' => $data['decision'], 'reviewed_by' => $request->user()->id,
                'reviewed_at' => now(), 'updated_at' => now()]);
        abort_unless($updated, 409, 'Photo has already been reviewed or replaced.');
        return response()->json(['status' => $data['decision']]);
    }
}
