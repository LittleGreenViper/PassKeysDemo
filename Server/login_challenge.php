<?php
require 'vendor/autoload.php';
require_once "./Config.php";
session_start();

use lbuchs\WebAuthn\WebAuthn;

try {
    // Load credentials from DB
    $pdo = new PDO(ConfigW::$g_db_type.':host='.ConfigW::$g_db_host.';dbname='.ConfigW::$g_db_name, ConfigW::$g_db_login, ConfigW::$g_db_password);
    $stmt = $pdo->prepare('SELECT credential_id FROM webauthn_credentials WHERE user_id = ?');
    $stmt->execute([$userId]);
    
    $credentials = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $credentials[] = base64url_encode($row['credential_id']);
    }
    
    $challenge = random_bytes(32);
    $_SESSION['loginChallenge'] = $challenge;
    
    $webAuthn = new WebAuthn(ConfigW::$g_relying_party_name, $_SERVER['HTTP_HOST']);
    $args = $webAuthn->getGetArgs($credentials);
    $args->publicKey->challenge = base64url_encode($challenge);

    header('Content-Type: application/json');
    echo json_encode($args);
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['error' => $e->getMessage()]);
}
