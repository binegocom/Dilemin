<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BlockController;
use App\Http\Controllers\Api\V1\ConversationController;
use App\Http\Controllers\Api\V1\DiscoveryController;
use App\Http\Controllers\Api\V1\DataExportController;
use App\Http\Controllers\Api\V1\EmailVerificationController;
use App\Http\Controllers\Api\V1\MessageController;
use App\Http\Controllers\Api\V1\PresenceController;
use App\Http\Controllers\Api\V1\PasswordRecoveryController;
use App\Http\Controllers\Api\V1\PhotoController;
use App\Http\Controllers\Api\V1\ModerationController;
use App\Http\Controllers\Api\V1\ProfileController;
use App\Http\Controllers\Api\V1\ReportReviewController;
use App\Http\Controllers\Api\V1\SafetyController;
use App\Http\Controllers\Api\V1\SessionController;
use App\Http\Controllers\Api\V1\VisibilityController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::post('/auth/register', [AuthController::class, 'register'])->middleware('throttle:dilemin-register');
    Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:dilemin-login');
    Route::post('/auth/password/request', [PasswordRecoveryController::class, 'requestCode'])
        ->middleware('throttle:dilemin-password-request');
    Route::post('/auth/password/confirm', [PasswordRecoveryController::class, 'confirm'])
        ->middleware('throttle:dilemin-password-confirm');

    Route::middleware(['auth:sanctum', 'throttle:dilemin-api'])->group(function (): void {
        Route::get('/auth/me', [AuthController::class, 'me']);
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/auth/sessions', [SessionController::class, 'index']);
        Route::delete('/auth/sessions/{token}', [SessionController::class, 'destroy'])
            ->whereNumber('token')->middleware('throttle:dilemin-sensitive');
        Route::post('/auth/sessions/revoke-others', [SessionController::class, 'revokeOthers'])
            ->middleware('throttle:dilemin-sensitive');
        Route::post('/auth/email/request', [EmailVerificationController::class, 'requestCode'])
            ->middleware('throttle:dilemin-verification-request');
        Route::post('/auth/email/confirm', [EmailVerificationController::class, 'confirm'])
            ->middleware('throttle:dilemin-verification-confirm');
        Route::middleware('verified')->group(function (): void {
        Route::post('/presence/heartbeat', [PresenceController::class, 'heartbeat']);
        Route::post('/presence/offline', [PresenceController::class, 'offline']);
        Route::get('/discovery/online', [DiscoveryController::class, 'online']);
        Route::post('/account/photo', [PhotoController::class, 'store'])->middleware('throttle:dilemin-sensitive');
        Route::delete('/account/photo', [PhotoController::class, 'destroy'])->middleware('throttle:dilemin-sensitive');
        Route::get('/users/{user}/photo', [PhotoController::class, 'show']);
        Route::get('/moderation/photos', [ModerationController::class, 'index']);
        Route::get('/moderation/photos/{photo}', [ModerationController::class, 'photo'])->whereNumber('photo');
        Route::post('/moderation/photos/{photo}/review', [ModerationController::class, 'review'])->whereNumber('photo')->middleware('throttle:dilemin-sensitive');
        Route::get('/users/{user}', [ProfileController::class, 'show']);
        Route::patch('/account/profile', [ProfileController::class, 'update']);
        Route::patch('/account/visibility', [VisibilityController::class, 'update']);
        Route::delete('/account', [SafetyController::class, 'deleteAccount'])->middleware('throttle:dilemin-sensitive');
        Route::post('/account/export', [DataExportController::class, 'download'])->middleware('throttle:dilemin-export');
        Route::get('/account/blocked', [BlockController::class, 'index']);
        Route::get('/moderation/reports', [ReportReviewController::class, 'index']);
        Route::post('/moderation/reports/{report}/review', [ReportReviewController::class, 'review'])
            ->whereNumber('report')->middleware('throttle:dilemin-sensitive');
        Route::post('/users/{user}/block', [BlockController::class, 'store']);
        Route::delete('/users/{user}/block', [BlockController::class, 'destroy']);
        Route::post('/users/{user}/report', [SafetyController::class, 'report'])->middleware('throttle:dilemin-sensitive');
        Route::get('/conversations', [ConversationController::class, 'index']);
        Route::post('/conversations', [ConversationController::class, 'store'])->middleware('throttle:dilemin-sensitive');
        Route::get('/conversations/{conversation}/messages', [MessageController::class, 'index'])->whereNumber('conversation');
        Route::post('/conversations/{conversation}/read', [MessageController::class, 'markRead'])->middleware('throttle:dilemin-sensitive')->whereNumber('conversation');
        Route::post('/conversations/{conversation}/messages', [MessageController::class, 'store'])->middleware('throttle:dilemin-messages')->whereNumber('conversation');
        });
    });
});
