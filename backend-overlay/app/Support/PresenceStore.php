<?php

namespace App\Support;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Redis;
use Laravel\Sanctum\PersonalAccessToken;

class PresenceStore
{
    private const KEY = 'dilemin:presence:online';
    private const TTL_SECONDS = 75;
    private const SESSION_PREFIX = 'dilemin:presence:sessions:';

    public static function sessionId(Request $request): ?string
    {
        $token = $request->user()?->currentAccessToken();
        return $token instanceof PersonalAccessToken ? (string) $token->getKey() : null;
    }

    private function sessionsKey(int $userId): string
    {
        return self::SESSION_PREFIX.$userId;
    }

    public function markOnline(int $userId, ?string $sessionId = null): void
    {
        $now = (string) time();
        if ($sessionId !== null) {
            $key = $this->sessionsKey($userId);
            Redis::command('ZADD', [$key, $now, $sessionId]);
            Redis::command('EXPIRE', [$key, '7200']);
        }
        Redis::command('ZADD', [self::KEY, $now, (string) $userId]);
        Redis::command('EXPIRE', [self::KEY, '7200']);
    }

    public function markOffline(int $userId, ?string $sessionId = null): void
    {
        if ($sessionId === null) {
            Redis::command('ZREM', [self::KEY, (string) $userId]);
            Redis::command('DEL', [$this->sessionsKey($userId)]);
            return;
        }
        $key = $this->sessionsKey($userId);
        Redis::command('ZREM', [$key, $sessionId]);
        Redis::command('ZREMRANGEBYSCORE', [$key, '-inf', (string) (time() - self::TTL_SECONDS - 1)]);
        $remaining = Redis::command('ZCOUNT', [$key, (string) (time() - self::TTL_SECONDS), '+inf']);
        if ((int) $remaining === 0) {
            Redis::command('ZREM', [self::KEY, (string) $userId]);
        }
    }

    /** @return list<int> */
    public function onlineIds(): array
    {
        $min = time() - self::TTL_SECONDS;
        Redis::command('ZREMRANGEBYSCORE', [self::KEY, '-inf', (string) ($min - 1)]);
        $result = Redis::command('ZREVRANGEBYSCORE', [self::KEY, '+inf', (string) $min, 'LIMIT', '0', '200']);
        return array_map('intval', is_array($result) ? $result : []);
    }
}
