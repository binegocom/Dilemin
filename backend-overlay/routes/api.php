<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BlockController;
use App\Http\Controllers\Api\V1\ConversationController;
use App\Http\Controllers\Api\V1\DiscoveryController;
use App\Http\Controllers\Api\V1\MessageController;
use App\Http\Controllers\Api\V1\PresenceController;
use App\Http\Controllers\Api\V1\ProfileController;
use App\Http\Controllers\Api\V1\SafetyController;
use App\Http\Controllers\Api\V1\VisibilityController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::post('/auth/register', [AuthController::class, 'register'])->middleware('throttle:dilemin-register');
    Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:dilemin-login');

    Route::middleware(['auth:sanctum', 'throttle:dilemin-api'])->group(function (): void {
        Route::get('/auth/me', [AuthController::class, 'me']);
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::post('/presence/heartbeat', [PresenceController::class, 'heartbeat']);
        Route::post('/presence/offline', [PresenceController::class, 'offline']);
        Route::get('/discovery/online', [DiscoveryController::class, 'online']);
        Route::get('/users/{user}', [ProfileController::class, 'show']);
        Route::patch('/account/profile', [ProfileController::class, 'update']);
        Route::patch('/account/visibility', [VisibilityController::class, 'update']);
        Route::delete('/account', [SafetyController::class, 'deleteAccount'])->middleware('throttle:dilemin-sensitive');
        Route::post('/users/{user}/block', [BlockController::class, 'store']);
        Route::delete('/users/{user}/block', [BlockController::class, 'destroy']);
        Route::post('/users/{user}/report', [SafetyController::class, 'report'])->middleware('throttle:dilemin-sensitive');
        Route::get('/conversations', [ConversationController::class, 'index']);
        Route::post('/conversations', [ConversationController::class, 'store'])->middleware('throttle:dilemin-sensitive');
        Route::get('/conversations/{conversation}/messages', [MessageController::class, 'index'])->whereNumber('conversation');
        Route::post('/conversations/{conversation}/messages', [MessageController::class, 'store'])->middleware('throttle:dilemin-messages')->whereNumber('conversation');
    });
});
