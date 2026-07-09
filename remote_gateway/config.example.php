<?php
declare(strict_types=1);

return [
    // En az 32 rastgele karakter kullanın. Bu anahtar yalnızca Desktop'ta tutulur.
    'center_token' => 'CHANGE_WITH_A_LONG_RANDOM_CENTER_TOKEN',

    // Mobil cihazların eşleşme isteği göndermek için kullanacağı kurum kodu.
    'site_code' => 'CHANGE_SITE_CODE',

    // Mümkünse public_html dışında bir klasör seçin.
    'database_path' => __DIR__ . '/data/biomed_remote.sqlite',

    // Canlı sistemde true kalmalıdır.
    'require_https' => true,

    // Tek bir JSON isteği için üst sınır.
    'max_payload_bytes' => 10485760,
];

