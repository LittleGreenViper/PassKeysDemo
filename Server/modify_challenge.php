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
    \brief Generate a challenge for the user modification process.
    
    This is called before we attempt access to the user data. It generates a new challenge, which is going to be incorporated into the client data.
    
    Any GET parameters need to be provided here. They will be passed on to the next step in the session array.
    
    We do a cusory check of the bearer token, and pass it on, if it matches, so it can be matched again, at the next step.
    
    The file is called with up to four GET arguments that can be supplied:
    
        - `userId`: This will have a URL-encoded string, with the unique (to this server) user ID that identifies this user. It is required.
    
        - `displayName`: This is a URL-encoded readable name for the user. This is optional.
    
        - `credo`: This is a URL-encoded "crdeo" (any text) the user wants stored. This is optional.
    
        - `token`: This is the bearer token. This is optional, but if not supplied (or valid), then the user will need to sign in again, in the next step.
        
    This returns a JSON record with signature information to be supplied to the app, along with whatever GET data the user supplied.
    
    The GET data is supplied to the next step, via the session. It will not be needed for anything else.
*/
require 'vendor/autoload.php';
require_once "./Config.php";

// We will be using a shared HTTP session.
session_start();

// We rely on the WebAuthn library.
use lbuchs\WebAuthn\WebAuthn;

// We will be extracting a User ID, display name, and credo from what the app sends in, for the challenge query. Default is nothing.
$userId = '';
$displayName = '';
$credo = '';
$bearerToken = '';

$_SESSION = []; // Start fresh.

// We pick through each of the supplied GET arguments, and get the user ID, display name, credo, ands any bearer token. We don't care about anything else.
$auth = explode('&', $_SERVER['QUERY_STRING']);
foreach ($auth as $query) {
    $exp = explode('=', $query);
    if ('userId' == $exp[0]) { 
        $userId = rawurldecode(trim($exp[1]));
    } elseif ('displayName' == $exp[0]) {
        $displayName = rawurldecode(trim($exp[1]));
    } elseif ('credo' == $exp[0]) {
        $credo = rawurldecode(trim($exp[1]));
    } elseif ('token' == $exp[0]) {
        $bearerToken = rawurldecode(trim($exp[1]));
    }
}

try {
    // Load credentials from DB
    $pdo = new PDO(Config::$g_db_type.':host='.Config::$g_db_host.';dbname='.Config::$g_db_name, Config::$g_db_login, Config::$g_db_password);
    $stmt = $pdo->prepare('SELECT credentialId, displayName, bearerToken FROM webauthn_credentials WHERE userId = ?');
    $stmt->execute([$userId]);
    
    $credentials = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $credentials[] = $row['credentialId'];

        // If we don't match the bearer token, we ensure an empty string.
        if ($row['bearerToken'] != $bearerToken) {
            $bearerToken = '';
        }
    }
    
    if (!empty($credentials)) {
        $challenge = random_bytes(32);  // Create a new challenge.
        
        // Pass these on to the next step.
        $_SESSION['modifyChallenge'] = $challenge;
        $_SESSION['displayName'] = $displayName;
        $_SESSION['credo'] = $credo;
        $_SESSION['bearerToken'] = $bearerToken;
        
        // Now, we create a record for the app to incorporate into a signed structure.
        $webAuthn = new WebAuthn(Config::$g_relying_party_name, $_SERVER['HTTP_HOST']);
        $args = $webAuthn->getGetArgs($credentials);
        // We need to replace the default stuff with what we have on deck.
        $args->publicKey->challenge = base64url_encode($challenge); // NOTE: This needs to be Base64URL encoded, not just Base64 encoded.
        // We add these fields. We're just using this struct as an envelope to send them to the app.
        $args->displayName = $displayName;
        $args->credo = $credo;
        $args->bearerToken = $bearerToken;
        
        header('Content-Type: application/json');
        echo json_encode($args);
    } else {
        http_response_code(404);
        echo json_encode(['error' => 'User not found']);
    }
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['error' => $e->getMessage()]);
}
