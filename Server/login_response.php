<?php
require 'vendor/autoload.php';
require_once "./Config.php";
session_start();

use lbuchs\WebAuthn\WebAuthn;
use lbuchs\WebAuthn\Binary\ByteBuffer;

$rawPostData = file_get_contents("php://input");
$input = json_decode($rawPostData, true);

$clientDataJSON = base64_decode($input['clientDataJSON']);
$authenticatorData = base64_decode($input['authenticatorData']);
$signature = base64_decode($input['signature']);
$credentialId = base64url_decode($input['credentialId']);
$challenge = $_SESSION['loginChallenge'];
$pdo = new PDO(ConfigW::$g_db_type.':host='.ConfigW::$g_db_host.';dbname='.ConfigW::$g_db_name, ConfigW::$g_db_login, ConfigW::$g_db_password);
$stmt = $pdo->prepare('SELECT user_id, public_key FROM webauthn_credentials WHERE credential_id = ?');
$stmt->execute([$credentialId]);
$row = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$row) {
    http_response_code(400);
    echo json_encode(['error' => 'Credential not found']);
    exit;
}

$webAuthn = new WebAuthn(ConfigW::$g_relying_party_name, $_SERVER['HTTP_HOST']);

try {
    $data = $webAuthn->processGet(
        $clientDataJSON,
        $authenticatorData,
        $signature,
        $row['public_key'],
        $challenge,
        $credentialId
    );

    echo($row['user_id']);
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['error' => $e->getMessage()]);
}
