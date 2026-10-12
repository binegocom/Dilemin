<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void {}

    public function boot(): void
    {
        RateLimiter::for('dilemin-register', fn (Request $request) =>
            Limit::perMinute(3)->by($request->ip()));
        RateLimiter::for('dilemin-login', fn (Request $request) =>
            Limit::perMinute(10)->by($request->ip()));
        RateLimiter::for('dilemin-api', fn (Request $request) =>
            Limit::perMinute(120)->by((string) ($request->user()?->id ?? $request->ip())));
        RateLimiter::for('dilemin-sensitive', fn (Request $request) =>
            Limit::perMinute(15)->by((string) ($request->user()?->id ?? $request->ip())));
        RateLimiter::for('dilemin-messages', fn (Request $request) =>
            Limit::perMinute(25)->by((string) ($request->user()?->id ?? $request->ip())));
    }
}
