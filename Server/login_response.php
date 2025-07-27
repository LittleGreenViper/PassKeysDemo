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
use lbuchs\WebAuthn\Binary\ByteBuffer;

$rawPostData = file_get_contents("php://input");
$input = json_decode($rawPostData, true);

$clientDataJSON = base64_decode($input['clientDataJSON']);
$authenticatorData = base64_decode($input['authenticatorData']);
$signature = base64_decode($input['signature']);
$credentialId = base64url_decode($input['credentialId']);
$challenge = $_SESSION['loginChallenge'];
$pdo = new PDO(Config::$g_db_type.':host='.Config::$g_db_host.';dbname='.Config::$g_db_name, Config::$g_db_login, Config::$g_db_password);
$stmt = $pdo->prepare('SELECT user_id, public_key FROM webauthn_credentials WHERE credential_id = ?');
$stmt->execute([$credentialId]);
$row = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$row) {
    http_response_code(404);
    echo json_encode(['error' => 'Credential not found']);
} else {
    $webAuthn = new WebAuthn(Config::$g_relying_party_name, $_SERVER['HTTP_HOST']);
    
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
}