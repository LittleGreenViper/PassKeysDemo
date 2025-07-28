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
$oldChallenge = isset($_SESSION['oldChallenge']) ? $_SESSION['oldChallenge'] : NULL;
$displayName = $_SESSION['displayName'];
$credo = $_SESSION['credo'];

$_SESSION['modifyChallenge'] = NULL;

$presentedAPIKey = "";

$auth = explode('&', $_SERVER['QUERY_STRING']);
foreach ($auth as $query) {
    $exp = explode('=', $query);
    if ('key' == $exp[0]) {
        $presentedAPIKey = rawurldecode(trim($exp[1]));
    }
}

$pdo = new PDO(Config::$g_db_type.':host='.Config::$g_db_host.';dbname='.Config::$g_db_name, Config::$g_db_login, Config::$g_db_password);
$stmt = $pdo->prepare('SELECT user_id, display_name, sign_count, api_key, public_key FROM webauthn_credentials WHERE credential_id = ?');
$stmt->execute([$credentialId]);
$row = $stmt->fetch(PDO::FETCH_ASSOC);

$userId = isset($row['user_id']) ? $row['user_id'] : NULL;

if (empty($row) || empty($userId)) {
    http_response_code(404);
    echo json_encode(['error' => 'Credential not found']);
} elseif (empty($oldChallenge) || ($row['api_key'] != $oldChallenge)) {
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
    
// file_put_contents('./check_modify.txt', print_r(['data' => $data], true));

        $newSignCount = intval($webAuthn->getSignatureCounter());
        $stmt = $pdo->prepare('UPDATE webauthn_credentials SET sign_count = ?, api_key = ? WHERE credential_id = ?');
        $stmt->execute([$newSignCount, $challenge, $credentialId]);
        
        performUpdate($pdo, $stmt, $userId, $displayName, $credo);
        $_SESSION['modifyChallenge'] = $challenge;
    } catch (Exception $e) {
        http_response_code(400);
        echo json_encode(['error' => $e->getMessage()]);
    }
} elseif ($row['api_key'] == $oldChallenge) {
    performUpdate($pdo, $stmt, $userId, $displayName, $credo);
    $stmt = $pdo->prepare('UPDATE webauthn_credentials SET api_key = ? WHERE credential_id = ?');
    $stmt->execute([intval($challenge), $credentialId]);
    $_SESSION['modifyChallenge'] = $challenge;
} else {
    http_response_code(400);
    echo json_encode(['error' => 'API Key Mismatch']);
}

/***********************/
/**
    Updates the user table with the new values (or simply returns the current values).
    @param string $pdo The PDO instance to be used for the query/update.
    @param string $stmt The PDO statement to be used for the query/update.
    @param string $userID The user ID from the credentials.
    @param string $displayName The user's display name (if being changed). NOTE: This should be set for any change, even if this string is not changed from what's in the DB.
    @param string $credo The user's credo string (if being changed).
    @return the data provided, as a Base64URL-encoded string.
 */
function performUpdate($pdo, $stmt, $userID, $displayName = NULL, $credo = NULL) {
    $stmt = $pdo->prepare('SELECT display_name, credo FROM passkeys_demo_users WHERE user_id = ?');
    $stmt->execute([$userID]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
die(print_r($row, true));
    if (empty($row) && !empty($displayName)) {  // No existing user. Create a new one.
        $stmt = $pdo->prepare('INSERT INTO passkeys_demo_users (user_id, display_name, credo) VALUES (?, ?, ?)');
        $stmt->execute([$userID, $displayName, ""]);
        $row = ['display_name' => $displayName, 'credo' => $credo];
    } elseif (!empty($row) && !empty($displayName)) {    // Existing user, and we want to make a change.
        $stmt = $pdo->prepare('UPDATE passkeys_demo_users SET display_name = ?, credo = ? WHERE user_id = ?');
        $stmt->execute([$displayName, $credo, $userID]);
        $row = ['display_name' => $displayName, 'credo' => $credo];
    } else {
        http_response_code(404);
        echo json_encode(['error' => 'User not found']);
        exit;
    }
    
    if (!empty($row)) {
        header('Content-Type: application/json');
        echo json_encode(['userId' => $userID, 'displayName' => $row['display_name'], 'credo' => $row['credo']]);
    } else {
        http_response_code(400);
        echo json_encode(['error' => 'Unable to update']);
    }
}
