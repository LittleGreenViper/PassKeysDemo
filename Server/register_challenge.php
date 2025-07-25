<?php
/***************************************************************************************************************************/
/**
    Webauthn Handler
    
    © Copyright 2025, Little Green Viper Software Development LLC
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