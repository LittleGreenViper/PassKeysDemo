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

$userId = "";
$displayName = "";

$auth = explode('&', $_SERVER['QUERY_STRING']);
foreach ($auth as $query) {
    $exp = explode('=', $query);
    if ('user_id' == $exp[0]) {
        $userId = rawurldecode(trim($exp[1]));
    } elseif ('display_name' == $exp[0]) {
        $displayName = rawurldecode(trim($exp[1]));
    }
}

if (empty($userId) || empty($displayName)) {
    header('HTTP/1.1 400 Bad Arguments');
    echo '&#128169;';
} else {
    $webAuthn = new WebAuthn(ConfigW::$g_relying_party_name, $_SERVER['HTTP_HOST']);
   
    $args = $webAuthn->getCreateArgs($userId, $displayName, $userId);
    
    $rawChallenge = $webAuthn->getChallenge()->getBinaryString();
    $base64urlChallenge = base64url_encode($rawChallenge);
    $userIdEncoded = base64url_encode($args->publicKey->user->id->getBinaryString());
      
    // Patch the object before encoding
    $args->publicKey->challenge = $base64urlChallenge;
    $args->publicKey->user->id = $userIdEncoded;
    
    $_SESSION['registerChallenge'] = $base64urlChallenge;
    $_SESSION['registerUserID'] = $userId;

    header('Content-Type: application/json');
    echo json_encode($args);
}