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

// We will be extracting a User ID, display name, and credo from what the app sends in, for the challenge query. Default is nothing.
$userId = "";
$displayName = "";
$credo = "";
$apiKey = "";

$_SESSION = [];

// We pick through each of the supplied GET arguments, and get the user ID, display name, credo, ands any API key. We don't care about anything else.
$auth = explode('&', $_SERVER['QUERY_STRING']);
foreach ($auth as $query) {
    $exp = explode('=', $query);
    if ('user_id' == $exp[0]) {
        $userId = rawurldecode(trim($exp[1]));
    } elseif ('display_name' == $exp[0]) {
        $displayName = rawurldecode(trim($exp[1]));
    } elseif ('credo' == $exp[0]) {
        $credo = rawurldecode(trim($exp[1]));
    } elseif ('key' == $exp[0]) {
        $apiKey = rawurldecode(trim($exp[1]));
    }
}

try {
    // Load credentials from DB
    $pdo = new PDO(Config::$g_db_type.':host='.Config::$g_db_host.';dbname='.Config::$g_db_name, Config::$g_db_login, Config::$g_db_password);
    $stmt = $pdo->prepare('SELECT credential_id FROM webauthn_credentials WHERE user_id = ?');
    $stmt->execute([$userId]);
    
    $credentials = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $credentials[] = $row['credential_id'];
    }
    
    if (!empty($credentials)) {
        $challenge = random_bytes(32);
        $_SESSION['modifyChallenge'] = $challenge;
        $_SESSION['displayName'] = $displayName;
        $_SESSION['credo'] = $credo;
        $_SESSION['apiKey'] = $apiKey;
        $webAuthn = new WebAuthn(Config::$g_relying_party_name, $_SERVER['HTTP_HOST']);
        $args = $webAuthn->getGetArgs($credentials);
        $args->publicKey->challenge = base64url_encode($challenge);

        header('Content-Type: application/json');
        echo json_encode(['args' => $args, 'apiKey' => $oldChallenge]);
    } else {
        http_response_code(404);
        echo json_encode(['error' => 'User not found']);
    }
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['error' => $e->getMessage()]);
}
