<?php

namespace App\Support;

use Illuminate\Support\Facades\Redis;

class PresenceStore
{
    private const KEY = 'dilemin:presence:online';
    private const TTL_SECONDS = 75;

    public function markOnline(int $userId): void
    {
        Redis::command('ZADD', [self::KEY, (string) time(), (string) $userId]);
        Redis::command('EXPIRE', [self::KEY, '7200']);
    }

    public function markOffline(int $userId): void
    {
        Redis::command('ZREM', [self::KEY, (string) $userId]);
    }

    /** @return list<int> */
    public function onlineIds(): array
    {
        $min = time() - self::TTL_SECONDS;
        Redis::command('ZREMRANGEBYSCORE', [self::KEY, '-inf', (string) ($min - 1)]);
        $result = Redis::command('ZRANGEBYSCORE', [self::KEY, (string) $min, '+inf', 'LIMIT', '0', '200']);
        return array_map('intval', is_array($result) ? $result : []);
    }
}
