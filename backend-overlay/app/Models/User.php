<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name', 'email', 'password', 'date_of_birth', 'online_visible', 'bio',
    ];

    protected $hidden = ['password', 'remember_token', 'date_of_birth'];

    protected function casts(): array
    {
        return [
            'date_of_birth' => 'date',
            'online_visible' => 'boolean',
            'is_moderator' => 'boolean',
            'password' => 'hashed',
            'email_verified_at' => 'datetime',
        ];
    }
}
