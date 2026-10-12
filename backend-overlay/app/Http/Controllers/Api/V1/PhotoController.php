<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\PresenceStore;
use App\Support\ProfilePhoto;
use App\Support\PublicUser;
use App\Support\SocialAccess;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class PhotoController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'photo' => ['required', 'file', 'image', 'mimes:jpeg,png,webp', 'max:5120',
                'dimensions:min_width=200,min_height=200,max_width=4096,max_height=4096'],
        ]);
        $file = $request->file('photo');
        $image = match ($file->getMimeType()) {
            'image/jpeg' => @imagecreatefromjpeg($file->getRealPath()),
            'image/png' => @imagecreatefrompng($file->getRealPath()),
            'image/webp' => @imagecreatefromwebp($file->getRealPath()),
            default => false,
        };
        if (! $image) {
            throw ValidationException::withMessages(['photo' => ['Image decoding failed.']]);
        }

        // Decode and re-encode: metadata (including EXIF/GPS) is never persisted.
        ob_start();
        $encoded = imagejpeg($image, null, 85);
        $bytes = ob_get_clean();
        imagedestroy($image);
        if (! $encoded || ! is_string($bytes) || strlen($bytes) > 8 * 1024 * 1024) {
            throw ValidationException::withMessages(['photo' => ['Image processing failed.']]);
        }

        $user = $request->user();
        $path = 'dilemin/profile-photos/'.$user->id.'/'.Str::random(40).'.jpg';
        abort_unless(Storage::disk('local')->put($path, $bytes), 503);
        $previous = null;
        try {
            DB::transaction(function () use ($user, $path, &$previous): void {
                // Lock parent row to serialize concurrent uploads for the same user.
                User::whereKey($user->id)->lockForUpdate()->firstOrFail();
                $existing = DB::table('profile_photos')->where('user_id', $user->id)->lockForUpdate()->first();
                $previous = $existing?->private_path;
                if ($existing) {
                    DB::table('profile_photos')->where('id', $existing->id)->update([
                        'private_path' => $path, 'revision' => (string) Str::uuid(),
                        'status' => 'pending', 'reviewed_by' => null,
                        'reviewed_at' => null, 'updated_at' => now(),
                    ]);
                } else {
                    DB::table('profile_photos')->insert([
                        'user_id' => $user->id, 'private_path' => $path,
                        'revision' => (string) Str::uuid(), 'status' => 'pending',
                        'created_at' => now(), 'updated_at' => now(),
                    ]);
                }
            });
        } catch (\Throwable $error) {
            Storage::disk('local')->delete($path);
            throw $error;
        }
        if ($previous !== null) Storage::disk('local')->delete($previous);
        return response()->json(['user' => PublicUser::serialize($user, true)], 201);
    }

    public function show(Request $request, User $user, PresenceStore $presence): BinaryFileResponse
    {
        $viewer = $request->user();
        if ($viewer->id !== $user->id) {
            abort_if(SocialAccess::blocked($viewer->id, $user->id), 404);
            abort_unless($user->online_visible && in_array($user->id, $presence->onlineIds(), true), 404);
        }
        $photo = DB::table('profile_photos')->where('user_id', $user->id)->first();
        abort_unless($photo, 404);
        abort_if($viewer->id !== $user->id && $photo->status !== 'approved', 404);
        abort_unless(Storage::disk('local')->exists($photo->private_path), 404);
        return response()->file(Storage::disk('local')->path($photo->private_path), [
            'Content-Type' => 'image/jpeg',
            'Cache-Control' => 'private, no-store',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }

    public function destroy(Request $request): JsonResponse
    {
        $user = $request->user();
        $path = DB::transaction(function () use ($user): ?string {
            $photo = DB::table('profile_photos')->where('user_id', $user->id)->lockForUpdate()->first();
            if (! $photo) return null;
            DB::table('profile_photos')->where('id', $photo->id)->delete();
            return $photo->private_path;
        });
        if ($path !== null) Storage::disk('local')->delete($path);
        return response()->json(['user' => PublicUser::serialize($user, true)]);
    }
}
