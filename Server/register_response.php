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

/**
This is the second step in the registration process.

This is called via POST, and contains two JSON arguments in the POST body:

- clientDataJSON: This is the client data that was supplied in the first step, processed by the app.
- attestationObject: This is the app-supplied registration attestation.
*/

require 'vendor/autoload.php';
require_once "./Config.php";

// We will be using a shared HTTP session.
session_start();

// We rely on the WebAuthn library.
use lbuchs\WebAuthn\WebAuthn;

// This is how we extract the supplied arguments from the POST (they may not show up in the $_POST environment variable).
$input = json_decode(file_get_contents("php://input"), true);
$clientDataJSON = base64_decode($input['clientDataJSON']);
$attestationObject = base64_decode($input['attestationObject']);

// We also fetch the three session-transmitted properties.
$userId = $_SESSION['registerUserID'];
$displayName = $_SESSION['registerDisplayName'];
$challenge = base64url_decode($_SESSION['registerChallenge']);

$_SESSION = [];

// We need all the information from the first step, plus the information supplied by the app.
if (empty($userId) || empty($displayName) || empty($challenge) || empty($clientDataJSON) || empty($attestationObject)) {
    http_response_code(400);
    echo '&#128169;';   // Oh, poo.
} else {
    // Create a new WebAuthn instance, using our organization name, and the serving host.
    $webAuthn = new WebAuthn(Config::$g_relying_party_name, $_SERVER['HTTP_HOST']);
    $token = base64url_encode(random_bytes(32));
    
    try {
        // This is where the data to be stored for the subsequent logins is generated.
        $data = $webAuthn->processCreate($clientDataJSON, $attestationObject, $challenge);
        
        // We will be storing all this into the database.
        $params = [
            $userId,
            $data->credentialId,
            $displayName,
            intval($data->signCount),
            $token,
            $data->credentialPublicKey
        ];
        
        // Store in the database webauthn table (WE use PDO, for safety).
        $pdo = new PDO( Config::$g_db_type.':host='.Config::$g_db_host.';dbname='.Config::$g_db_name,
                        Config::$g_db_login,
                        Config::$g_db_password);
                        
        $stmt = $pdo->prepare('INSERT INTO webauthn_credentials (user_id, credential_id, display_name, sign_count, bearer_token, public_key) VALUES (?, ?, ?, ?, ?, ?)');
        $stmt->execute($params);
        $stmt = $pdo->prepare('INSERT INTO passkeys_demo_users (user_id, display_name, credo) VALUES (?, ?, ?)');
        $stmt->execute([$userId, $displayName, ""]);
        $_SESSION['modifyChallenge'] = $challenge;
        $_SESSION['bearer_token'] = $token;
        $_SESSION['displayName'] = $displayName;
        header('Content-Type: application/json');
        if (empty($token)) {
            $token = '';
        }
        echo json_encode(['displayName' => $displayName, 'credo' => '', 'bearerToken' => $token]);
    } catch (Exception $e) {
        http_response_code(400);
        echo json_encode(['error' => $e->getMessage()]);
    }
}