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

$challenge = $_SESSION['modifyChallenge'];
$displayName = $_SESSION['displayName'];
$credo = $_SESSION['credo'];

$pdo = new PDO(Config::$g_db_type.':host='.Config::$g_db_host.';dbname='.Config::$g_db_name, Config::$g_db_login, Config::$g_db_password);
$stmt = $pdo->prepare('SELECT user_id, display_name, public_key, sign_count FROM webauthn_credentials WHERE credential_id = ?');
$stmt->execute([$credentialId]);
$row = $stmt->fetch(PDO::FETCH_ASSOC);

if (empty($row) || empty($row['user_id'])) {
    http_response_code(404);
    echo json_encode(['error' => 'Credential not found']);
} else {
    if (empty($displayName)) {
        $displayName = $row['display_name'];
    }
    
    if (NULL == $credo) {
        $credo = '';
    }
    
    $userId = $row['user_id'];
    $signCount = intval($row['sign_count']);
    
    $webAuthn = new WebAuthn(Config::$g_relying_party_name, $_SERVER['HTTP_HOST']);
    
    try {
        $data = $webAuthn->processGet(
            $clientDataJSON,
            $authenticatorData,
            $signature,
            $row['public_key'],
            $challenge,
            $signCount
        );
    
        $stmt = $pdo->prepare('UPDATE webauthn_credentials SET sign_count = ? WHERE credential_id = ?');
        $stmt->execute([intval($data->signCount), $credentialId]);
    
        $stmt = $pdo->prepare('SELECT display_name, credo FROM passkeys_demo_users WHERE user_id = ?');
        $stmt->execute([$row['user_id']]);
        $row2 = $stmt->fetch(PDO::FETCH_ASSOC);
        if (empty($row2)) {
            if (!empty($userId) && !empty($displayName)) {
                $stmt = $pdo->prepare('INSERT INTO passkeys_demo_users (user_id, display_name, credo) VALUES (?, ?, ?)');
                $stmt->execute([$row['user_id'], $displayName, ""]);
                $row2 = ['display_name' => $displayName, 'credo' => $credo];
            } else {
                http_response_code(404);
                echo json_encode(['error' => 'User not found']);
                exit;
            }
        } elseif (!empty($userId) && !empty($displayName)) {
            $stmt = $pdo->prepare('UPDATE passkeys_demo_users SET display_name = ?, credo = ? WHERE user_id = ?');
            $stmt->execute([$displayName, $credo, $row['user_id']]);
            $row2 = ['display_name' => $displayName, 'credo' => $credo];
        }
        
        if (!empty($row2)) {
            header('Content-Type: application/json');
            echo json_encode(['userId' => $row['user_id'], 'displayName' => $row2['display_name'], 'credo' => $row2['credo']]);
        } else {
            http_response_code(400);
            echo json_encode(['error' => 'Unable to update']);
        }
    } catch (Exception $e) {
        http_response_code(400);
        echo json_encode(['error' => $e->getMessage()]);
    }
}
