<?php

namespace App\Services;

use Illuminate\Support\Str;

class EnvironmentService
{
    protected string $envPath;

    /**
     * Keys that are allowed to be updated through the admin panel.
     *
     * @var string[]
     */
    protected array $allowedKeys = [
        'MAIL_MAILER',
        'MAIL_HOST',
        'MAIL_PORT',
        'MAIL_USERNAME',
        'MAIL_PASSWORD',
        'MAIL_ENCRYPTION',
        'MAIL_FROM_ADDRESS',
        'MAIL_FROM_NAME',
        'FCM_SERVER_KEY',
        'FCM_SENDER_ID',
        'SMS_PROVIDER',
        'SMS_TWILIO_ACCOUNT_SID',
        'SMS_TWILIO_AUTH_TOKEN',
        'SMS_TWILIO_FROM',
    ];

    public function __construct()
    {
        $this->envPath = base_path('.env');
    }

    public function get(array $keys): array
    {
        $values = [];

        foreach ($keys as $key) {
            if (!in_array($key, $this->allowedKeys, true)) {
                continue;
            }

            $values[$key] = env($key);
        }

        return $values;
    }

    /**
     * Update environment values for the given key/value pairs.
     *
     * @param array<string, string|null> $values
     */
    public function update(array $values): void
    {
        if (!is_file($this->envPath) || !is_writable($this->envPath)) {
            throw new \RuntimeException('.env dosyası bulunamadı veya yazılamıyor.');
        }

        $contents = file_get_contents($this->envPath);

        if ($contents === false) {
            throw new \RuntimeException('.env dosyası okunamadı.');
        }

        foreach ($values as $key => $value) {
            if (!in_array($key, $this->allowedKeys, true)) {
                continue;
            }

            $formatted = $this->formatEnvValue($value);

            $pattern = "/^{$key}=.*$/m";
            if (preg_match($pattern, $contents)) {
                $contents = (string) preg_replace($pattern, "{$key}={$formatted}", $contents);
            } else {
                $contents .= PHP_EOL . "{$key}={$formatted}";
            }
        }

        file_put_contents($this->envPath, $contents);
    }

    /**
     * Convert the raw value to a .env compatible representation.
     */
    protected function formatEnvValue(?string $value): string
    {
        if ($value === null) {
            return '';
        }

        $needsQuotes = Str::contains($value, [' ', '#', '"', "'"]);
        $escaped = str_replace('"', '\"', $value);

        return $needsQuotes ? '"' . $escaped . '"' : $escaped;
    }
}

