<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;
use Illuminate\Foundation\Events\Dispatchable;

final class ConversationMessageCreated implements ShouldBroadcast, ShouldDispatchAfterCommit
{
    use Dispatchable, InteractsWithSockets;

    public function __construct(
        public readonly int $messageId,
        public readonly int $conversationId,
        public readonly int $senderId,
        public readonly int $recipientId,
    ) {}

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel("conversations.{$this->conversationId}"),
            new PrivateChannel("users.{$this->senderId}"),
            new PrivateChannel("users.{$this->recipientId}"),
        ];
    }

    public function broadcastAs(): string
    {
        return 'message.created';
    }

    public function broadcastWith(): array
    {
        return [
            'message_id' => (string) $this->messageId,
            'conversation_id' => (string) $this->conversationId,
            'sender_id' => (string) $this->senderId,
        ];
    }
}
