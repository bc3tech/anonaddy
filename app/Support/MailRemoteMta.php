<?php

namespace App\Support;

class MailRemoteMta
{
    public static function forConfiguredMailer(?string $mailer = null): ?string
    {
        $mailer ??= config('mail.default');

        if (! is_string($mailer) || $mailer === '') {
            return null;
        }

        $config = config("mail.mailers.{$mailer}");

        if (! is_array($config)) {
            return $mailer;
        }

        $transport = $config['transport'] ?? $mailer;

        return match ($transport) {
            'acs' => self::hostFromEndpoint(self::stringValue($config['endpoint'] ?? null)) ?? 'acs',
            'smtp' => self::stringValue($config['host'] ?? null),
            default => self::stringValue($transport) ?? $mailer,
        };
    }

    private static function stringValue(mixed $value): ?string
    {
        return is_string($value) && $value !== '' ? $value : null;
    }

    private static function hostFromEndpoint(?string $endpoint): ?string
    {
        if ($endpoint === null) {
            return null;
        }

        $host = parse_url($endpoint, PHP_URL_HOST);

        return is_string($host) && $host !== '' ? $host : $endpoint;
    }
}
