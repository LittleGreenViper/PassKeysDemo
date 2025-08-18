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
Demonstration PassKey Server

This file implements a simple CRUD server, accessed via basic PassKeys. It uses PassKeys for registration
and login, and a basic bearer token for post-login functionality, supported by a continuous session.

DEPENDENCIES:

This requires [the lbuchs/WebAuthn library](https://github.com/lbuchs/WebAuthn), and has been tested on PHP 8.

USAGE:

The script is called via HTTP, and uses GET and POST query arguments (as required by the operation specified).

There will always be an "operation=" GET query argument. This is a dispatcher argument.

Once logged in, the session must be maintained, and the bearer token returned by create or login, must
be supplied in the authentication header. This token is only valid while the session is contiguous.

STRUCTURE:

The server implements a database (currently MySQL/MariaDB), with two tables:
    - `webauthn_credentials`, which contains the authentication information.
        It has the PassKey public key, as well as the bearer token, once the session is logged in.
        
    - `passkeys_demo_users`, which has the actual user data.
        This is only accessed, once the session is authenticated.
        
We implement an instance of lbuchs/WebAuthn, and use that for PassKey authentication, and store
an instance of PDO, for secure database interaction.
*/
require 'vendor/autoload.php';  // This is the WebAuthn library.
require_once "./Config.php";    // This is the server-specific configuration.

// We will be using a shared HTTP session.
session_start();

// We rely on the WebAuthn library.
use lbuchs\WebAuthn\WebAuthn;

// MARK: - Global Utility Functions

/***********************/
/**
    Converts a binary value to a Base64 URL string.
    @param string $data The data (can be binary) to be converted to Base64URL
    @return the data provided, as a Base64URL-encoded string.
 */
function base64url_encode(string $data): string {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

/***********************/
/**
    Converts a Base64URL string back to its original form.
    @param string $data The Base64URL-encoded string to be converted to its original data.
    @return the Base64URL-encoded string provided, as the original (possibly binary) data. FALSE, if the conversion fails.
 */
function base64url_decode(string $data): string|false {
    return base64_decode(str_pad(strtr($data, '-_', '+/'), strlen($data) % 4, '=', STR_PAD_RIGHT));
}

// MARK: - Operation Keys

/******************************************/
/**
These are the various operation keys.

Every call needs to have a "operation" GET query argument, with one of these values.

The other query arguments/POST parameters, depend on the operation.

Some of these denote a challenge/response pair of calls.
*/
enum Operation: String {
    /**************************************/
    /**
    Create a new user (must be unique).
    
    This is a two-part operation, so it must be called twice. The first part accepts a displayName and userID.
    
    The second part requires POST parameters, with the PassKey authentication information.
    
    The login only lasts as long as the session.
    
    Requires a unique userId, and optional displayName GET arguments. Also, the session must not be logged in.
    
    Returns the displayName, and empty credo, and a bearer token.
    
    The token is required for the read, update, logout, and delete operations.
     */
    case createUser = 'create';

    /**************************************/
    /**
    Establish a logged-in connection.
    
    This is a two-part operation, so it must be called twice. The first part accepts a displayName and userID.
    
    The second part requires POST parameters, with the PassKey authentication information.
    
    The login only lasts as long as the session.
    
    Returns a bearer token, required for the read, update, logout, and delete operations.
     */
    case login = 'login';

    /**************************************/
    /**
    Closes the login, and clears the session.
    
    The session must be logged in, which requires the token be supplied in the authentication header.
     */
    case logout = 'logout';

    /**************************************/
    /**
    Reads the currently logged-in user, and returns the associated data.
    
    The session must be logged in, which requires the token be supplied in the authentication header.
     */
    case readUser = 'read';

    /**************************************/
    /**
    This updates the currently logged-in user.
    
    Requires a unique userId, displayName, and credo GET arguments.
    
    The session must be logged in, which requires the token be supplied in the authentication header.
     */
    case updateUser = 'update';

    /**************************************/
    /**
    Deletes the currently logged-in user.
    
    The session must be logged in, which requires the token be supplied in the authentication header.
     */
    case deleteUser = 'delete';
}

// MARK: - Main Class

/******************************************/
/**
This class is the main server implementation. Everything happens in the constructor.
*/
class PKDServer {
    /**************************************/
    /**
    This contains an object, with any arguments sent via GET (as object properties).
    */
    var $getArgs;

    /**************************************/
    /**
    This contains an associative array, with any arguments sent via POST (We only have JSON sent by POST).
    */
    var $postArgs;

    /**************************************/
    /**
    This is an initialized instance of lbuchs/WebAuthn that we'll be using for checking credentials.
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
    
    All the action happens here. Just construct the class, to make it work.
    */
    public function __construct() {
        // Since any POST arguments are simply JSON, we access them this way.
        $rawPostData = file_get_contents("php://input");
        
        // This is the configuration for our PDO property.
        // Config is supplied in the Config.php file, referenced above.
        $pdoHostDBConfig = Config::$g_db_type.':host='.Config::$g_db_host.';dbname='.Config::$g_db_name;

        // Set up our instance properties.
        $this->getArgs = (object)$_GET;
        $this->postArgs = json_decode($rawPostData, true);
        $this->pdoInstance = new PDO($pdoHostDBConfig, Config::$g_db_login, Config::$g_db_password);
        $this->webAuthnInstance = new WebAuthn(Config::$g_relying_party_name, Config::$g_relying_party_uri);

        // We dispatch, according to the operation GET argument value.
        switch(Operation::from($this->getArgs->operation)) {
            // This is a two-part operation.
            // The first call generates a challenge string, that is signed and submitted in the second call.
            // It also stashes the GET values for the userID and displayName, in the session variable.
            case Operation::login:
                if (empty($this->postArgs)) {
                    $this->loginChallenge();
                } else {
                    $this->loginCompletion();
                }
                break;
                
            // This is a two-part operation.
            // The first call generates a challenge string, that is signed and submitted in the second call.
            case Operation::createUser:
                if (empty($this->postArgs)) {
                    $this->createChallenge();
                } else {
                    $this->createCompletion();
                }
                break;
                
            // This simply reads the user table, and returns the values, therein.
            case Operation::readUser:
                $this->handleRead();
                break;
            
            // This updates the user table, with the values provided in the GET arguments.
            case Operation::updateUser:
                $this->handleUpdate();
                break;
            
            // This simply logs up out, and removes the bearer token from the database.
            case Operation::logout:
                $this->handleLogout();
                break;
            
            // This completely deletes the currently logged-in user from the database.
            case Operation::deleteUser:
                $this->handleDelete();
                break;
            
            // We send back a poo emoji, if an illegal operation was prescribed.
            default:
                http_response_code(400);
                echo '&#128169;';   // Oh, poo.
        }
    }
    
    // MARK: - PassKey Operations -
    
    /**************************************/
    /**
    The first part of the login operation.
    
    This is called with a userId, and returns the challenge string, as Base64 URL-encoded.
    */
    public function loginChallenge() {
        $challenge = random_bytes(32);
        // Pass on to the next step.
        $_SESSION['loginChallenge'] = $challenge;
        echo(base64url_encode($challenge));
    }
    
    /**************************************/
    /**
    The second part of the login operation.
    
    This requires JSON structures in the POST, with the credentials from the app.
    
    It returns the bearerToken for the login.
    */
    public function loginCompletion() {
        $userId = "";
        $credentialId = $this->getArgs->credentialId;
        if (empty($credentialId)) {
            http_response_code(400);
            echo '&#128169;';   // Oh, poo.
            exit;
        }
        
        $row = [];
        $stmt = $this->pdoInstance->prepare('SELECT userId, displayName, signCount, publicKey FROM webauthn_credentials WHERE credentialId = ?');
        $stmt->execute([$credentialId]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        $userId = $row['userId'];
            
        if (empty($userId)) {
            http_response_code(404);
            header('Content-Type: application/json');
            echo json_encode(['error' => 'User not found']);
            exit;
        }
        
        // This is a signed record, with various user data.
        $clientDataJSON = base64_decode($this->postArgs['clientDataJSON']);
        // A record, with any authenticator (YubiKey, etc. Not used for our demo). 
        $authenticatorData = base64_decode($this->postArgs['authenticatorData']);
        // The signature for the record, against the public key.
        $signature = base64_decode($this->postArgs['signature']); 
        // The public key for the passkey.
        $publicKey = $row['publicKey'];
        // The challenge that was returned to the client, for signing.
        $challenge = $_SESSION['loginChallenge'];
        // The number of times it has been validated.
        $signCount = intval($row['signCount']);
        
        // If there was no signed client data record, with a matching challenge, then game over, man.
        if (!empty($publicKey) && !empty($credentialId) && !empty($userId)) {
            try {
                $success = $this->webAuthnInstance->processGet(
                    $clientDataJSON,
                    $authenticatorData,
                    $signature,
                    $publicKey,
                    $challenge,
                    $signCount
                );
                
                // Create a new token, as this is a new login.
                // NOTE: This needs to be Base64URL encoded, not just Base64 encoded.
                $bearerToken = base64url_encode(random_bytes(32));  
                
                // Increment the sign count and store the new bearer token.
                $newSignCount = intval($this->webAuthnInstance->getSignatureCounter());
                $stmt = $this->pdoInstance->prepare('UPDATE webauthn_credentials SET signCount = ?, bearerToken = ? WHERE credentialId = ?');
                $stmt->execute([$newSignCount, $bearerToken, $credentialId]);
                
                $_SESSION['bearerToken'] = $bearerToken;    // Pass it on, in the session.
                echo($bearerToken);
            } catch (Exception $e) {
                // Try to clear the token, if we end up here.
                $stmt = $this->pdoInstance->prepare('UPDATE webauthn_credentials SET bearerToken = NULL WHERE credentialId = ?');
                $stmt->execute([$credentialId]);
                
                http_response_code(401);
                header('Content-Type: application/json');
                echo json_encode(['error' => $e->getMessage()]);
            }
        } else {
            http_response_code(404);
            header('Content-Type: application/json');
            echo json_encode(['error' => 'User Not Found']);
        }
    }
    
    /**************************************/
    /**
    The first part of the create operation.
    
    This is called with a userId (and optionally, a display name), and returns the public key struct, as JSON.
    */
    public function createChallenge() {
        $userId = $this->getArgs->userId;   // The user ID needs, to be unique in this server.
        // After this, the client can forget the user ID. It will no longer be used in exchanges.
        $displayName = $this->getArgs->displayName;
        if (empty($displayName)) {
            $displayName = "New User";
        }
        
        $stmt = $this->pdoInstance->prepare('SELECT credentialId FROM webauthn_credentials WHERE userId = ?');
        $stmt->execute([$userId]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!empty($userId) && empty($row)) {
            // We will use the function to create a registration object,
            // which will need to be presented in a subsequent call.
            $args = $this->webAuthnInstance->getCreateArgs($userId, $userId, $displayName);
            
            // We encode the challenge data as a Base64 URL-encoded string.
            $binaryString = $this->webAuthnInstance->getChallenge()->getBinaryString();
            $base64urlChallenge = base64url_encode($binaryString);
            // We do the same for the binary unique user ID.
            // NOTE: This needs to be Base64URL encoded, not just Base64 encoded.
            $userIdEncoded = base64url_encode($args->publicKey->user->id->getBinaryString());
              
            // We replace the ones given by the function (basic Base64), with the Base64 URL-encoded strings.
            $args->publicKey->challenge = $base64urlChallenge;
            $args->publicKey->user->id = $userIdEncoded;
            
            // We will save these in the session, which must be preserved for the next step.
            $_SESSION['createUserID'] = $userId;
            $_SESSION['createDisplayName'] = $displayName;
            $_SESSION['createChallenge'] = $base64urlChallenge;
        
            header('Content-Type: application/json');
            echo json_encode(['publicKey' => $args->publicKey]);
        } elseif (!empty($row)) {
            http_response_code(409);
            echo json_encode(['error' => 'User Already Registered']);
        } else {
            http_response_code(400);
            echo '&#128169;';   // Oh, poo.
        }
    }
    
    /**************************************/
    /**
    This completes the creation.
    
    It ensures that the PassKey is valid, and matches the challenge we sent up, then creates
    a record in each of the database tables.
    
    It responds with the displayName, credo, and bearerToken for the new user and login, as JSON.
    */
    public function createCompletion() {
        // Create a new token, as this is a new login.
        // NOTE: This needs to be Base64URL encoded, not just Base64 encoded.
        $bearerToken = base64url_encode(random_bytes(32));
        $userId = $_SESSION['createUserID'];
        $displayName = $_SESSION['createDisplayName'];
        $clientDataJSON = base64_decode($this->postArgs['clientDataJSON']);
        $attestationObject = base64_decode($this->postArgs['attestationObject']);
        $challenge = base64url_decode($_SESSION['createChallenge']);  // NOTE: Base64URL encoded.
        
        if (!empty($clientDataJSON) && !empty($attestationObject)) {
            try {
                // This is where the data to be stored for the subsequent logins is generated.
                $data = $this->webAuthnInstance->processCreate( $clientDataJSON,
                                                                $attestationObject,
                                                                $challenge);
                
                // We will be storing all this into the database.
                $params = [
                    $userId,
                    base64_encode($data->credentialId),
                    $displayName,
                    intval($data->signCount),
                    $bearerToken,
                    $data->credentialPublicKey
                ];
                
                // Create a new credential record.
                $stmt = $this->pdoInstance->prepare('INSERT INTO webauthn_credentials (userId, credentialId, displayName, signCount, bearerToken, publicKey) VALUES (?, ?, ?, ?, ?, ?)');
                $stmt->execute($params);
                // Create a new user data record.
                $stmt = $this->pdoInstance->prepare('INSERT INTO passkeys_demo_users (userId, displayName, credo) VALUES (?, ?, ?)');
                $stmt->execute([$userId, $displayName, ""]);
                // Send these on to the next step.
                $_SESSION['bearerToken'] = $bearerToken;
        
                header('Content-Type: application/json');
                echo json_encode(['displayName' => $displayName, 'credo' => '', 'bearerToken' => $bearerToken]);
            } catch (Exception $e) {
                http_response_code(400);
                header('Content-Type: application/json');
                echo json_encode(['error' => $e->getMessage()]);
            }
        } else {
            http_response_code(400);
            echo '&#128169;';   // Oh, poo.
        }
    }
    
    // MARK: - Post-Login Operations -
    
    /**************************************/
    /**
    Simply reads the data for the currently logged-in user, and returns it as JSON.
    
    Responds with the displayName and credo for the current user, as JSON.
    */
    public function handleRead() {
        $originalToken = $_SESSION['bearerToken'];
        $headers = getallheaders();
        
        if (!empty($originalToken) && isset($headers['Authorization'])) {
            $authHeader = $headers['Authorization'];
        
            if (preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
                $token = $matches[1];
                if (!empty($token) && ($originalToken == $token)) {
                    $stmt = $this->pdoInstance->prepare('SELECT userId FROM webauthn_credentials WHERE bearerToken = ?');
                    $stmt->execute([$originalToken]);
                    $row = $stmt->fetch(PDO::FETCH_ASSOC);
                    
                    if (!empty($row) && !empty($row['userId'])) {
                        $userId = $row['userId'];
                        $stmt = $this->pdoInstance->prepare('SELECT displayName, credo FROM passkeys_demo_users WHERE userId = ?');
                        $stmt->execute([$userId]);
                        $row = $stmt->fetch(PDO::FETCH_ASSOC);
                        
                        if (!empty($row) && !empty($row['displayName'])) {
                            $displayName = $row['displayName'];
                            $credo = $row['credo'];
                            if (empty($credo)) {
                                $credo = '';
                            }
                            header('Content-Type: application/json');
                            echo json_encode(['displayName' => $displayName, 'credo' => $credo]);
                        } else {
                            http_response_code(500);
                            header('Content-Type: application/json');
                            echo json_encode(['error' => 'Database Sync Issues']);
                            exit;
                        }
                    } else {
                        http_response_code(401);
                        header('Content-Type: application/json');
                        echo json_encode(['error' => 'User Not Found']);
                        exit;
                    }
                } else {
                    http_response_code(401);
                    header('Content-Type: application/json');
                    echo json_encode(['error' => 'Authorization Mismatch']);
                    exit;
                }
            } else {
                http_response_code(401);
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Invalid Authorization header']);
                exit;
            }
        } else {
            http_response_code(401);
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Missing Authorization']);
            exit;
        }
    }
    
    /**************************************/
    /**
    Updates the user data for the currently logged-in user. Uses GET arguments for displayName and credo.
    
    Responds with the displayName and credo for the current user, as JSON.
    */
    public function handleUpdate() {
        $originalToken = $_SESSION['bearerToken'];
        $headers = getallheaders();
        
        if (!empty($originalToken) && isset($headers['Authorization'])) {
            $authHeader = $headers['Authorization'];
        
            if (preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
                $token = $matches[1];
                if (!empty($token) && ($originalToken == $token)) {
                    $stmt = $this->pdoInstance->prepare('SELECT userId FROM webauthn_credentials WHERE bearerToken = ?');
                    $stmt->execute([$originalToken]);
                    $row = $stmt->fetch(PDO::FETCH_ASSOC);
                    
                    if (!empty($row) && !empty($row['userId'])) {
                        $userId = $row['userId'];
                        $displayName = $this->getArgs->displayName;
                        $credo = $this->getArgs->credo;
                        
                        $stmt = $this->pdoInstance->prepare('UPDATE webauthn_credentials SET displayName = ? WHERE userId = ?');
                        $stmt->execute([$displayName, $userId]);
                        $stmt = $this->pdoInstance->prepare('UPDATE passkeys_demo_users SET displayName = ?, credo = ? WHERE userId = ?');
                        $stmt->execute([$displayName, $credo, $userId]);
                    } else {
                        http_response_code(401);
                        header('Content-Type: application/json');
                        echo json_encode(['error' => 'User Not Found']);
                        exit;
                    }
                } else {
                    http_response_code(401);
                    header('Content-Type: application/json');
                    echo json_encode(['error' => 'Authorization Mismatch']);
                    exit;
                }
            } else {
                http_response_code(401);
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Invalid Authorization header']);
                exit;
            }
        } else {
            http_response_code(401);
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Missing Authorization']);
            exit;
        }
    }
    
    /***********************/
    /**
    Performs a full logout (removes the bearer token from the DB, and sets the session to empty).
     */
    function handleLogout() {
        $originalToken = $_SESSION['bearerToken'];
        $headers = getallheaders();
        
        if (!empty($originalToken) && isset($headers['Authorization'])) {
            $authHeader = $headers['Authorization'];
        
            if (preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
                $token = $matches[1];
                if (!empty($token) && ($originalToken == $token)) {
                        $stmt = $this->pdoInstance->prepare('UPDATE webauthn_credentials SET bearerToken = NULL WHERE bearerToken = ?');
                        $stmt->execute([$token]);
                        $_SESSION = [];
                } else {
                    http_response_code(403);
                    header('Content-Type: application/json');
                    echo json_encode(['error' => 'Authorization Failure']);
                }
            } else {
                http_response_code(403);
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Authorization Failure']);
            }
        } else {
            http_response_code(400);
            echo '&#128169;';   // Oh, poo.
        }
    }
    
    /***********************/
    /**
    This deletes the logged-in user from both tables. It also forces a logout.
     */
    function handleDelete() {
        $originalToken = $_SESSION['bearerToken'];
        $headers = getallheaders();
        
        if (!empty($originalToken) && isset($headers['Authorization'])) {
            $authHeader = $headers['Authorization'];
        
            if (preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
                $token = $matches[1];
                if (!empty($token) && ($originalToken == $token)) {
                    $stmt = $this->pdoInstance->prepare('SELECT userId FROM webauthn_credentials WHERE bearerToken = ?');
                    $stmt->execute([$token]);
                    $row = $stmt->fetch(PDO::FETCH_ASSOC);
                    
                    if (!empty($row) && isset($row['userId']) && !empty($row['userId'])) {
                        try {   // We wrap in a transaction, so we won't have only one table row deleted,
                                // if there's an error.
                            $this->pdoInstance->beginTransaction();
                                $stmt = $this->pdoInstance->prepare('DELETE FROM webauthn_credentials WHERE userId = ?');
                                $stmt->execute([$row['userId']]);
                                $stmt = $this->pdoInstance->prepare('DELETE FROM passkeys_demo_users WHERE userId = ?');
                                $stmt->execute([$row['userId']]);
                            $this->pdoInstance->commit();
                            $_SESSION = [];
                        } catch (Exception $e) {
                            $this->pdoInstance->rollBack();
                            http_response_code(500);
                            header('Content-Type: application/json');
                            echo json_encode(['error' => 'Delete Operation Failure']);
                        }
                    } else {
                        http_response_code(404);
                        header('Content-Type: application/json');
                        echo json_encode(['error' => 'User Not Found']);
                    }
                } else {
                    http_response_code(403);
                    header('Content-Type: application/json');
                    echo json_encode(['error' => 'Authorization Failure']);
                }
            } else {
                http_response_code(403);
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Authorization Failure']);
            }
        } else {
            http_response_code(400);
            echo '&#128169;';   // Oh, poo.
        }
    }
}