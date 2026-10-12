<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

final class EmailVerificationCode extends Notification
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
            'de' => ['Dılêmın – E-Mail bestätigen', 'Dein Bestätigungscode lautet:',
                'Der Code ist 10 Minuten gültig. Gib ihn nicht an andere weiter.'],
            'fr' => ['Dılêmın – Vérification de votre adresse e-mail', 'Votre code de vérification :',
                'Ce code expire dans 10 minutes. Ne le communiquez à personne.'],
            'it' => ['Dılêmın – Verifica email', 'Il tuo codice di verifica è:',
                'Il codice scade tra 10 minuti. Non condividerlo con nessuno.'],
            'en' => ['Dılêmın – Verify your email', 'Your verification code is:',
                'The code expires in 10 minutes. Do not share it with anyone.'],
        ];
        [$subject, $heading, $warning] = $translations[$this->emailLocale] ?? $translations['en'];
        return (new MailMessage)->subject($subject)->line($heading)
            ->line($this->code)->line($warning);
    }
}
