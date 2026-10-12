<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;

class PushDeviceController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'min:30', 'max:4096'],
            'platform' => ['required', 'in:ios,android'],
            'locale' => ['required', 'in:de,fr,it,en'],
        ]);
        $session = $request->user()->currentAccessToken();
        abort_unless($session && $session->getKey(), 401);
        $fingerprint = hash('sha256', $data['token']);
        DB::table('push_devices')->updateOrInsert(
            ['token_hash' => $fingerprint],
            [
                'user_id' => $request->user()->id,
                'personal_access_token_id' => $session->getKey(),
                'token_ciphertext' => Crypt::encryptString($data['token']),
                'platform' => $data['platform'],
                'locale' => $data['locale'],
                'updated_at' => now(),
            ]
        );
        return response()->json(['status' => 'registered']);
    }

    public function destroy(Request $request): JsonResponse
    {
        $data = $request->validate(['token' => ['required', 'string', 'min:30', 'max:4096']]);
        $session = $request->user()->currentAccessToken();
        abort_unless($session && $session->getKey(), 401);
        DB::table('push_devices')
            ->where('user_id', $request->user()->id)
            ->where('personal_access_token_id', $session->getKey())
            ->where('token_hash', hash('sha256', $data['token']))->delete();
        return response()->json(['status' => 'removed']);
    }
}
