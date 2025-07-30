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

// file_put_contents('./check_modify_response.txt', print_r(['$_SESSION' => $_SESSION], true));

$rawPostData = file_get_contents("php://input");
$input = json_decode($rawPostData, true);

$clientDataJSON = base64_decode($input['clientDataJSON']);
$authenticatorData = base64_decode($input['authenticatorData']);
$signature = base64_decode($input['signature']);
$credentialId = base64url_decode($input['credentialId']);

$challenge = $_SESSION['modifyChallenge'];
$token = $_SESSION['bearer_token'];
$displayName = $_SESSION['displayName'];
$credo = $_SESSION['credo'];

$_SESSION = [];

$pdo = new PDO(Config::$g_db_type.':host='.Config::$g_db_host.';dbname='.Config::$g_db_name, Config::$g_db_login, Config::$g_db_password);
$stmt = $pdo->prepare('SELECT user_id, display_name, sign_count, bearer_token, public_key FROM webauthn_credentials WHERE credential_id = ?');
$stmt->execute([$credentialId]);
$row = $stmt->fetch(PDO::FETCH_ASSOC);

$userId = isset($row['user_id']) ? $row['user_id'] : NULL;

if (empty($row) || empty($userId)) {
    http_response_code(404);
    echo json_encode(['error' => 'Credential not found']);
} elseif (empty($token) || ($row['bearer_token'] != $token)) {
    if (empty($displayName)) {
        $displayName = $row['display_name'];
    }
    
    if (empty($credo)) {
        $credo = '';
    }
    
    $signCount = intval($row['sign_count']);
    
    $webAuthn = new WebAuthn(Config::$g_relying_party_name, $_SERVER['HTTP_HOST']);
    
    try {
        $success = $webAuthn->processGet(
            $clientDataJSON,
            $authenticatorData,
            $signature,
            $row['public_key'],
            $challenge,
            $signCount
        );
        $token = base64url_encode(random_bytes(32));
        $newSignCount = intval($webAuthn->getSignatureCounter());
        $stmt = $pdo->prepare('UPDATE webauthn_credentials SET sign_count = ?, bearer_token = ? WHERE credential_id = ?');
        $stmt->execute([$newSignCount, $token, $credentialId]);
        
        performUpdate($pdo, $stmt, $userId, $token, $displayName, $credo);
        $_SESSION['bearer_token'] = $token;
    } catch (Exception $e) {
        http_response_code(400);
        echo json_encode(['error' => $e->getMessage()]);
    }
} elseif (!empty($row) && ($row['bearer_token'] == $token)) {
    performUpdate($pdo, $stmt, $userId, $token $displayName, $credo);
    $_SESSION['bearer_token'] = $token;
} else {
    $stmt = $pdo->prepare('UPDATE webauthn_credentials SET bearer_token = NULL WHERE credential_id = ?');
    $stmt->execute([$credentialId]);
    http_response_code(400);
    echo json_encode(['error' => 'API Key Mismatch']);
}

/***********************/
/**
    Updates the user table with the new values (or simply returns the current values).
    @param string $pdo The PDO instance to be used for the query/update.
    @param string $stmt The PDO statement to be used for the query/update.
    @param string $userId The user ID from the credentials.
    @param string $displayName The user's display name (if being changed). NOTE: This should be set for any change, even if this string is not changed from what's in the DB.
    @param string $credo The user's credo string (if being changed).
    @return the data provided, as a Base64URL-encoded string.
 */
function performUpdate($pdo, $stmt, $userId, $token, $displayName = NULL, $credo = NULL) {
    $stmt = $pdo->prepare('SELECT display_name, credo FROM passkeys_demo_users WHERE user_id = ?');
    $stmt->execute([$userId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!empty($row) && !empty($displayName) && !empty($row['display_name'])) {
        if (($displayName != $row['display_name']) || ($credo != $row['credo'])) {
            $stmt = $pdo->prepare('UPDATE passkeys_demo_users SET display_name = ?, credo = ? WHERE user_id = ?');
            $stmt->execute([$displayName, $credo, $userId]);
            $row = ['display_name' => $displayName, 'credo' => $credo, 'bearer_token' => $token];
        }
        
        header('Content-Type: application/json');
        echo json_encode(['displayName' => $row['display_name'], 'credo' => $row['credo'], 'bearer_token' => $token]);
    } else {
        http_response_code(404);
        echo json_encode(['error' => 'User not found']);
    }
}
