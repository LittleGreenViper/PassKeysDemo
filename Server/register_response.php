<?php
/*
    © Copyright 2025, Little Green Viper Software Development LLC

    LICENSE:

    MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
    files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
    modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
    CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
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
