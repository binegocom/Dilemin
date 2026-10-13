<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final class EnsureAccountActive
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        abort_unless($user, 401);

        if ($user->suspended_at !== null) {
            // Suspended members retain their privacy rights and account exit.
            $allowExport = $request->isMethod('POST') && $request->is('api/v1/account/export');
            $allowDelete = $request->isMethod('DELETE') && $request->is('api/v1/account');
            $allowAppeal = ($request->isMethod('GET') || $request->isMethod('POST'))
                && $request->is('api/v1/account/appeal');
            abort_unless($allowExport || $allowDelete || $allowAppeal, 403, 'Account suspended.');
        }

        return $next($request);
    }
}
