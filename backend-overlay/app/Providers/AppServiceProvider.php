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
        RateLimiter::for('dilemin-password-request', fn (Request $request) =>
            Limit::perMinute(4)->by((string) $request->ip()));
        RateLimiter::for('dilemin-password-confirm', fn (Request $request) =>
            Limit::perMinute(10)->by((string) $request->ip()));
        RateLimiter::for('dilemin-verification-request', fn (Request $request) =>
            Limit::perHour(5)->by((string) ($request->user()?->id ?? $request->ip())));
        RateLimiter::for('dilemin-verification-confirm', fn (Request $request) =>
            Limit::perMinute(10)->by((string) ($request->user()?->id ?? $request->ip())));
        RateLimiter::for('dilemin-messages', fn (Request $request) =>
            Limit::perMinute(25)->by((string) ($request->user()?->id ?? $request->ip())));
    }
}
