<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

final class PasswordRecoveryCode extends Notification
{
    use Queueable;

    public function __construct(private readonly string $code, private readonly string $emailLocale) {}

    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        $translations = [
            'de' => ['Dılêmın – Passwort zurücksetzen', 'Dein Code zum Zurücksetzen lautet:',
                'Dieser Code ist 10 Minuten gültig. Wenn du keinen Reset angefordert hast, ignoriere diese Nachricht.'],
            'fr' => ['Dılêmın – Réinitialiser votre mot de passe', 'Votre code de réinitialisation :',
                'Le code expire dans 10 minutes. Si vous ne l’avez pas demandé, ignorez ce message.'],
            'it' => ['Dılêmın – Reimposta la password', 'Il tuo codice di recupero è:',
                'Il codice scade tra 10 minuti. Se non hai richiesto il recupero, ignora questo messaggio.'],
            'en' => ['Dılêmın – Reset your password', 'Your password recovery code is:',
                'This code expires in 10 minutes. If you did not request it, ignore this message.'],
        ];
        [$subject, $heading, $warning] = $translations[$this->emailLocale] ?? $translations['en'];
        return (new MailMessage)->subject($subject)->line($heading)->line($this->code)->line($warning);
    }
}
