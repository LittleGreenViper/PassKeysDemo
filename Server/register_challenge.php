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
    \brief Generate a challenge for the initial user registration process.
    
    This is called (via GET) to prepare some basic arguments for the next step in the registration.
    
    The registration is a two-step process, both of which need to be done in the same HTTP session.
    
    This is the first step, where the credentials are created, and returned to the app.
    
    The app must then return the credentials, along with the generated challenge string.
    
    The file is called with two GET arguments that must be supplied:
    
        - `userId`: This will have a URL-encoded string, with the unique (to this server) user ID that identifies this user.
    
        - `displayName`: This is a URL-encoded readable name for the user. It does not need to be unique, but is required. 
*/

require 'vendor/autoload.php';
require_once "./Config.php";

// We will be using a shared HTTP session.
session_start();

// We rely on the WebAuthn library.
use lbuchs\WebAuthn\WebAuthn;

// We will be extracting a User ID, and a display name, from what the app sends in, for the challenge query. Default is nothing.
$userId = '';
$displayName = '';

// We pick through each of the supplied GET arguments, and get the user ID and the display name. We don't care about anything else.
$auth = explode('&', $_SERVER['QUERY_STRING']);
foreach ($auth as $query) {
    $exp = explode('=', $query);
    if ('userId' == $exp[0]) {
        $userId = rawurldecode(trim($exp[1]));
    } elseif ('displayName' == $exp[0]) {
        $displayName = rawurldecode(trim($exp[1]));
    }
}

// WE must have BOTH a user ID AND a display name. We also should not already be logged in.
if (!empty($_SESSION['bearerToken']) || empty($userId) || empty($displayName)) {
    $_SESSION = []; // Clear the poop deck (of poop).
    http_response_code(400);
    echo '&#128169;';   // Oh, poo.
} else {
// We fetch the user credentials from the credential DB.
    $pdo = new PDO(Config::$g_db_type.':host='.Config::$g_db_host.';dbname='.Config::$g_db_name, Config::$g_db_login, Config::$g_db_password);
    $stmt = $pdo->prepare('SELECT credentialId FROM webauthn_credentials WHERE userId = ?');
    $stmt->execute([$userId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    
    // If we didn't have one, we will create a new one. This is the only sucess path. Anything else is FAIL.
    if (empty($row)) {
        // Create a new WebAuthn instance, using our organization name, and the serving host.
        $webAuthn = new WebAuthn(Config::$g_relying_party_name, Config::$g_relying_party_uri);
       
        // We will use the function to create a registration object, which will need to be presented in a subsequent call.
        $args = $webAuthn->getCreateArgs($userId, $userId, $displayName);
        
        // We encode the challenge data as a Base64 URL-encoded string.
        $base64urlChallenge = base64url_encode($webAuthn->getChallenge()->getBinaryString());
        // We do the same for the binary unique user ID. NOTE: This needs to be Base64URL encoded, not just Base64 encoded.
        $userIdEncoded = base64url_encode($args->publicKey->user->id->getBinaryString());
          
        // We replace the ones given by the function (basic Base64), with the Base64 URL-encoded strings.
        $args->publicKey->challenge = $base64urlChallenge;
        $args->publicKey->user->id = $userIdEncoded;
        
        // We will save these in the session, which must be preserved for the next step.
        $_SESSION['registerChallenge'] = $base64urlChallenge;
        $_SESSION['registerUserID'] = $userId;
        $_SESSION['registerDisplayName'] = $displayName;
    
        header('Content-Type: application/json');
        echo json_encode(['publicKey' => $args->publicKey, 'displayName' => $displayName, 'credo' => '', 'bearerToken' => '']);
    } else {
        $_SESSION = []; // Clear the poop deck (of poop).
        http_response_code(400);
        echo '&#128169;';   // Oh, poo.
    }
}