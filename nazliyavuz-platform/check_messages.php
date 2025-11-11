<?php

require __DIR__ . '/vendor/autoload.php';

$app = require_once __DIR__ . '/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

use App\Models\Message;

echo "=== CHECKING MESSAGES WITH FILES ===\n\n";

$imageMessages = Message::where('message_type', 'image')->latest()->take(3)->get();
$voiceMessages = Message::where('message_type', 'audio')->latest()->take(3)->get();

echo "IMAGE MESSAGES: " . $imageMessages->count() . "\n";
foreach ($imageMessages as $msg) {
    echo "  ID: {$msg->id}\n";
    echo "  Type: {$msg->message_type}\n";
    echo "  URL: {$msg->file_url}\n";
    echo "  Name: {$msg->file_name}\n";
    echo "  ---\n";
}

echo "\nVOICE MESSAGES: " . $voiceMessages->count() . "\n";
foreach ($voiceMessages as $msg) {
    echo "  ID: {$msg->id}\n";
    echo "  Type: {$msg->message_type}\n";
    echo "  URL: {$msg->file_url}\n";
    echo "  Name: {$msg->file_name}\n";
    echo "  ---\n";
}

