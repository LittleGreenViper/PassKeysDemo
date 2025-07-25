<?php
require 'vendor/autoload.php';
require_once "./Config.php";
session_start();

use lbuchs\WebAuthn\WebAuthn;

$rawPostData = file_get_contents("php://input");
$input = json_decode($rawPostData, true);

$userId = $_SESSION['registerUserID'];

$webAuthn = new WebAuthn(ConfigW::$g_relying_party_name, $_SERVER['HTTP_HOST']);

$challengeStr = base64url_decode($_SESSION['registerChallenge']);
$clientDataJSON = base64_decode($input['clientDataJSON']);
$attestationObject = base64_decode($input['attestationObject']);

try {
    $data = $webAuthn->processCreate($clientDataJSON, $attestationObject, $challengeStr);

    $signCount = $signCount = intval($data->signCount);
    
    $params = [
        $userId,
        $data->credentialId,
        $data->credentialPublicKey
    ];
    
    // Store in DB
    $pdo = new PDO(ConfigW::$g_db_type.':host='.ConfigW::$g_db_host.';dbname='.ConfigW::$g_db_name, ConfigW::$g_db_login, ConfigW::$g_db_password);
    $stmt = $pdo->prepare('INSERT INTO webauthn_credentials (user_id, credential_id, public_key) VALUES (?, ?, ?)');
    $stmt->execute($params);

    echo json_encode(['success' => true]);
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['error' => $e->getMessage()]);
}
