<?php

namespace App\Jobs;

use App\Support\SocialAccess;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Kreait\Firebase\Factory;
use Kreait\Firebase\Exception\Messaging\NotFound;
use Kreait\Firebase\Exception\Messaging\SenderIdMismatch;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;

final class SendMessagePush implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;
    public int $timeout = 30;

    public function __construct(public readonly int $messageId) {}

    public function handle(): void
    {
        $message = DB::table('messages')->where('id', $this->messageId)->first();
        if (! $message) return;
        $conversation = DB::table('conversations')->where('id', $message->conversation_id)->first();
        if (! $conversation) return;
        $senderId = (int) $message->sender_id;
        $low = (int) $conversation->user_low_id;
        $high = (int) $conversation->user_high_id;
        if ($senderId !== $low && $senderId !== $high) return;
        if (SocialAccess::blocked($low, $high)) return;
        $recipientId = $senderId === $low ? $high : $low;
        $recipient = DB::table('users')->where('id', $recipientId)->first();
        if (! $recipient || $recipient->email_verified_at === null) return;

        // A delayed queue job must not notify about a message already read.
        $readCursor = $recipientId === $low
            ? $conversation->last_read_low_message_id
            : $conversation->last_read_high_message_id;
        if ((int) ($readCursor ?? 0) >= (int) $message->id) return;

        // Token revocation is protected by a FK; expired sessions are filtered
        // explicitly because Sanctum token expiry does not remove database rows.
        $devices = DB::table('push_devices as device')
            ->join('personal_access_tokens as session', 'session.id', '=', 'device.personal_access_token_id')
            ->where('device.user_id', $recipientId)
            ->where('session.tokenable_type', 'App\\Models\\User')
            ->where('session.tokenable_id', $recipientId)
            ->where(function ($query): void {
                $query->whereNull('session.expires_at')
                    ->orWhere('session.expires_at', '>', now());
            })
            ->get(['device.*']);
        if ($devices->isEmpty()) return;

        $credentialPath = config('dilemin.firebase_credentials');
        if (! is_string($credentialPath) || $credentialPath === '' || ! is_readable($credentialPath)) {
            throw new \RuntimeException('Firebase service account credentials not configured.');
        }
        $messaging = (new Factory())->withServiceAccount($credentialPath)->createMessaging();
        $texts = [
            'de' => ['Neue Nachricht', 'Du hast eine neue Nachricht.'],
            'fr' => ['Nouveau message', 'Vous avez reçu un nouveau message.'],
            'it' => ['Nuovo messaggio', 'Hai ricevuto un nuovo messaggio.'],
            'en' => ['New message', 'You received a new message.'],
        ];
        foreach ($devices as $device) {
            // Re-check state after slow provider calls and concurrent session revocation.
            if (SocialAccess::blocked($low, $high)) return;
            if (! DB::table('push_devices')->where('id', $device->id)
                ->where('user_id', $recipientId)
                ->where('personal_access_token_id', $device->personal_access_token_id)
                ->where('token_hash', $device->token_hash)->exists()) continue;
            $latestRead = DB::table('conversations')->where('id', $conversation->id)
                ->value($recipientId === $low ? 'last_read_low_message_id' : 'last_read_high_message_id');
            if ((int) ($latestRead ?? 0) >= (int) $message->id) return;
            $copy = $texts[$device->locale] ?? $texts['en'];
            $cloud = CloudMessage::new()
                ->withToken(Crypt::decryptString($device->token_ciphertext))
                ->withNotification(Notification::create($copy[0], $copy[1]))
                ->withData([
                    'type' => 'chat',
                    'conversation_id' => (string) $conversation->id,
                    'message_id' => (string) $message->id,
                ]);
            try {
                $messaging->send($cloud);
            } catch (NotFound|SenderIdMismatch $exception) {
                // Replaced, uninstalled, or foreign-project devices must not be retried.
                DB::table('push_devices')->where('id', $device->id)
                    ->where('token_hash', $device->token_hash)->delete();
                report($exception);
            }
        }
    }
}
