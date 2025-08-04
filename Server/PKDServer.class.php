<?php
/*
    © Copyright 2025, Little Green Viper Software Development LLC

    LICENSE:

    MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
/**
*/
require 'vendor/autoload.php';
require_once "./Config.php";

// We will be using a shared HTTP session.
session_start();

// We rely on the WebAuthn library.
use lbuchs\WebAuthn\WebAuthn;

/******************************************/
/**
*/
enum Operation: String {
    /**************************************/
    /**
     */
    case login = 'login';

    /**************************************/
    /**
     */
    case logout = 'logout';

    /**************************************/
    /**
     */
    case createUser = 'createUser';

    /**************************************/
    /**
     */
    case readUser = 'readUser';

    /**************************************/
    /**
     */
    case updateUser = 'updateUser';

    /**************************************/
    /**
     */
    case deleteUser = 'deleteUser';
}

/******************************************/
/**
This class implements the server-side PassKeys (WebAuthn) component.
*/
class PKDServer {
    /**************************************/
    /**
    This contains an object, with any arguments sent via GET.
    */
    var $getArgs;

    /**************************************/
    /**
    This contains an object, with any arguments sent via POST (We only have JSON sent by POST).
    */
    var $postArgs;

    /**************************************/
    /**
    This is an initialized instance of WebAuthn that we'll be using for checking credentials.
    */
    var $webAuthnInstance;

    /**************************************/
    /**
    This is an initialized instance of PDO, that we'll be using to interact with the database.
    */
    var $pdoInstance;
    
    /**************************************/
    /**
    Main constructor.
    */
    public function __construct() {
        $rawPostData = file_get_contents("php://input");
        $pdoHostDBConfig = Config::$g_db_type.':host='.Config::$g_db_host.';dbname='.Config::$g_db_name;

        $this->getArgs = (object)$_GET;
        $this->postArgs = json_decode($rawPostData, true);
        $this->pdoInstance = new PDO($pdoHostDBConfig, Config::$g_db_login, Config::$g_db_password);
        $this->webAuthnInstance = new WebAuthn(Config::$g_relying_party_name, Config::$g_relying_party_uri);
        $operation = Operation::from($this->getArgs->operation);
        $userId = $this->getArgs->userId;
        switch($operation) {
            case Operation::login:
                if (!empty($userId)) {
                    $this->loginChallenge();
                }
                break;
                
            default:
                echo("<h1>ERROR</h1>");
        }
    }
    
    /**************************************/
    /**
    */
    public function loginChallenge() {
        $userId = $this->getArgs->userId;
        echo('<h2>User: '.$userId.'</h2>');
    }
}