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

// We rely on the WebAuthn library.
use lbuchs\WebAuthn\WebAuthn;

// We will be using a shared HTTP session.
session_start();

// MARK: - Global Utility Functions

/***********************/
/**
    Converts a binary value to a Base64 URL string.
    @param string $data The data (can be binary) to be converted to Base64URL
    @returns: the data provided, as a Base64URL-encoded string.
 */
function base64url_encode(string $data): string {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

/***********************/
/**
    Converts a Base64URL string back to its original form.
    @param string $data The Base64URL-encoded string to be converted to its original data.
    @returns: the Base64URL-encoded string provided, as the original (possibly binary) data. FALSE, if the conversion fails.
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

// MARK: - MAIN CLASS -

/******************************************/
/**
This class is the main server implementation. Everything happens in the constructor.
*/
class PKDServer {
    // MARK: Class Properties
    
    /**************************************/
    /**
    This contains an object, with any arguments sent via GET (as object properties).
    */
    var $_getArgs;

    /**************************************/
    /**
    This contains an associative array, with any arguments sent via POST (We only have JSON sent by POST).
    */
    var $_postArgs;

    /**************************************/
    /**
    This is an initialized instance of lbuchs/WebAuthn that we'll be using for checking credentials.
    */
    var $_webAuthnInstance;

    /**************************************/
    /**
    This is an initialized instance of PDO, that we'll be using to interact with the database.
    */
    var $_pdoInstance;
    
    // MARK: Private Utility Methods
    
    /**************************************/
    /**
    This acts like a "guard" clause.
    
    This should be called before performing any logged-in operations.
    
    It will validate the bearer token, and will terminate the script with a 400 error, if the token fails.
    
    @returns: The token.
    */
    private function _vetLogin() {
        $originalToken = $_SESSION['bearerToken'];
        $headers = getallheaders();
        
        if (!empty($originalToken) && isset($headers['Authorization'])) {
            $authHeader = $headers['Authorization'];
        
            if (preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
                $token = $matches[1];
                if (!empty($token) && ($originalToken == $token)) {
                    return $originalToken;
                } else {
                    http_response_code(401);
                    header('Content-Type: application/json');
                    echo json_encode(['error' => 'Authorization Mismatch']);
                }
            } else {
                http_response_code(401);
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Invalid Authorization header']);
            }
        } else {
            http_response_code(401);
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Missing Authorization']);
        }
      
        exit;
    }
    
    // MARK: Private PassKey Operation Methods
    
    /**************************************/
    /**
    The first part of the login operation.
    
    @returns: the challenge string, as Base64URL-encoded, and an array of allowed credential IDs,
    each Base64-encoded.
    */
    private function _loginChallenge() {
        $challenge = random_bytes(32);
        // Pass on to the next step.
        $_SESSION['loginChallenge'] = $challenge;
        $stmt = $this->_pdoInstance->prepare('SELECT credentialId FROM webauthn_credentials');
        $stmt->execute();
        $allowedIDs = [];
        
        foreach($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
            if (!empty($row['credentialId'])) {
                $allowedIDs[] = $row['credentialId'];
            }
        }
        
        header('Content-Type: application/json');
        echo json_encode(['challenge' => base64url_encode($challenge), 'allowedIDs' => $allowedIDs]);
    }
    
    /**************************************/
    /**
    The second part of the login operation.
    
    This requires JSON structures in the POST, with the credentials from the app.
    
    @returns: the bearerToken for the login.
    */
    private function _loginCompletion() {
        $userId = "";
        $credentialId = $this->_getArgs->credentialId;
        if (empty($credentialId)) {
            http_response_code(400);
            echo '&#128169;';   // Oh, poo.
            exit;
        }
        
        $row = [];
        $stmt = $this->_pdoInstance->prepare('SELECT userId, displayName, signCount, publicKey FROM webauthn_credentials WHERE credentialId = ?');
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
        $clientDataJSON = base64_decode($this->_postArgs['clientDataJSON']);
        // A record, with any authenticator (YubiKey, etc. Not used for our demo). 
        $authenticatorData = base64_decode($this->_postArgs['authenticatorData']);
        // The signature for the record, against the public key.
        $signature = base64_decode($this->_postArgs['signature']); 
        // The public key for the passkey.
        $publicKey = $row['publicKey'];
        // The challenge that was returned to the client, for signing.
        $challenge = $_SESSION['loginChallenge'];
        // The number of times it has been validated.
        $signCount = intval($row['signCount']);
        
        // If there was no signed client data record, with a matching challenge, then game over, man.
        if (!empty($publicKey) && !empty($credentialId) && !empty($userId)) {
            try {
                $success = $this->_webAuthnInstance->processGet(
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
                $newSignCount = intval($this->_webAuthnInstance->getSignatureCounter());
                $stmt = $this->_pdoInstance->prepare('UPDATE webauthn_credentials SET signCount = ?, bearerToken = ? WHERE credentialId = ?');
                $stmt->execute([$newSignCount, $bearerToken, $credentialId]);
                
                $_SESSION['bearerToken'] = $bearerToken;    // Pass it on, in the session.
                echo($bearerToken);
            } catch (Exception $e) {
                // Try to clear the token, if we end up here.
                $stmt = $this->_pdoInstance->prepare('UPDATE webauthn_credentials SET bearerToken = NULL WHERE credentialId = ?');
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
    
    This is called with a userId (and optionally, a display name).
    @returns: the public key struct, as JSON.
    */
    private function _createChallenge() {
        $userId = $this->_getArgs->userId;   // The user ID needs, to be unique in this server.
        // After this, the client can forget the user ID. It will no longer be used in exchanges.
        $displayName = $this->_getArgs->displayName;
        if (empty($displayName)) {
            $displayName = "New User";
        }
        
        $stmt = $this->_pdoInstance->prepare('SELECT credentialId FROM webauthn_credentials WHERE userId = ?');
        $stmt->execute([$userId]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!empty($userId) && empty($row)) {
            // We will use the function to create a registration object,
            // which will need to be presented in a subsequent call.
            $args = $this->_webAuthnInstance->getCreateArgs($userId, $userId, $displayName);
            
            // We encode the challenge data as a Base64 URL-encoded string.
            $binaryString = $this->_webAuthnInstance->getChallenge()->getBinaryString();
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
    
    @returns: the displayName, credo, and bearerToken for the new user and login, as JSON.
    */
    private function _createCompletion() {
        // Create a new token, as this is a new login.
        // NOTE: This needs to be Base64URL encoded, not just Base64 encoded.
        $bearerToken = base64url_encode(random_bytes(32));
        $userId = $_SESSION['createUserID'];
        $displayName = $_SESSION['createDisplayName'];
        $clientDataJSON = base64_decode($this->_postArgs['clientDataJSON']);
        $attestationObject = base64_decode($this->_postArgs['attestationObject']);
        $challenge = base64url_decode($_SESSION['createChallenge']);  // NOTE: Base64URL encoded.
        
        if (!empty($clientDataJSON) && !empty($attestationObject)) {
            try {
                // This is where the data to be stored for the subsequent logins is generated.
                $data = $this->_webAuthnInstance->processCreate(    $clientDataJSON,
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
                $stmt = $this->_pdoInstance->prepare('INSERT INTO webauthn_credentials (userId, credentialId, displayName, signCount, bearerToken, publicKey) VALUES (?, ?, ?, ?, ?, ?)');
                $stmt->execute($params);
                // Create a new user data record.
                $stmt = $this->_pdoInstance->prepare('INSERT INTO passkeys_demo_users (userId, displayName, credo) VALUES (?, ?, ?)');
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
    
    // MARK: Private Post-Login Operation Methods
    
    /**************************************/
    /**
    Simply reads the data for the currently logged-in user, and returns it as JSON.
    
    @returns: the displayName and credo for the current user, as JSON.
    */
    Private function _handleRead() {
        $bearerToken = $this->_vetLogin();
        
        $stmt = $this->_pdoInstance->prepare('SELECT userId FROM webauthn_credentials WHERE bearerToken = ?');
        $stmt->execute([$bearerToken]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!empty($row) && !empty($row['userId'])) {
            $userId = $row['userId'];
            $stmt = $this->_pdoInstance->prepare('SELECT displayName, credo FROM passkeys_demo_users WHERE userId = ?');
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
    }
    
    /**************************************/
    /**
    Updates the user data for the currently logged-in user. Uses GET arguments for displayName and credo.
    
    @returns: the displayName and credo for the current user, as JSON.
    */
    private function _handleUpdate() {
        $bearerToken = $this->_vetLogin();
        
        $stmt = $this->_pdoInstance->prepare('SELECT userId FROM webauthn_credentials WHERE bearerToken = ?');
        $stmt->execute([$bearerToken]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!empty($row) && !empty($row['userId'])) {
            $userId = $row['userId'];
            $displayName = $this->_getArgs->displayName;
            $credo = $this->_getArgs->credo;
            
            $stmt = $this->_pdoInstance->prepare('UPDATE webauthn_credentials SET displayName = ? WHERE userId = ?');
            $stmt->execute([$displayName, $userId]);
            $stmt = $this->_pdoInstance->prepare('UPDATE passkeys_demo_users SET displayName = ?, credo = ? WHERE userId = ?');
            $stmt->execute([$displayName, $credo, $userId]);
        } else {
            http_response_code(401);
            header('Content-Type: application/json');
            echo json_encode(['error' => 'User Not Found']);
            exit;
        }
    }
    
    /***********************/
    /**
    Performs a full logout (removes the bearer token from the DB, and sets the session to empty).
     */
    private function _handleLogout() {
        $bearerToken = $this->_vetLogin();
        
        $stmt = $this->_pdoInstance->prepare('UPDATE webauthn_credentials SET bearerToken = NULL WHERE bearerToken = ?');
        $stmt->execute([$bearerToken]);
        $_SESSION = [];
    }
    
    /***********************/
    /**
    This deletes the logged-in user from both tables. It also forces a logout.
     */
    private function _handleDelete() {
        $bearerToken = $this->_vetLogin();

        $stmt = $this->_pdoInstance->prepare('SELECT userId FROM webauthn_credentials WHERE bearerToken = ?');
        $stmt->execute([$bearerToken]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!empty($row) && isset($row['userId']) && !empty($row['userId'])) {
            try {   // We wrap in a transaction, so we won't have only one table row deleted,
                    // if there's an error.
                $this->_pdoInstance->beginTransaction();
                    $stmt = $this->_pdoInstance->prepare('DELETE FROM webauthn_credentials WHERE userId = ?');
                    $stmt->execute([$row['userId']]);
                    $stmt = $this->_pdoInstance->prepare('DELETE FROM passkeys_demo_users WHERE userId = ?');
                    $stmt->execute([$row['userId']]);
                $this->_pdoInstance->commit();
                $_SESSION = [];
            } catch (Exception $e) {
                $this->_pdoInstance->rollBack();
                http_response_code(500);
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Delete Operation Failure']);
            }
        } else {
            http_response_code(404);
            header('Content-Type: application/json');
            echo json_encode(['error' => 'User Not Found']);
        }
    }
    
    // MARK: Public API
    
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
        $this->_getArgs = (object)$_GET;
        $this->_postArgs = json_decode($rawPostData, true);
        $this->_pdoInstance = new PDO($pdoHostDBConfig, Config::$g_db_login, Config::$g_db_password);
        $this->_webAuthnInstance = new WebAuthn(Config::$g_relying_party_name, Config::$g_relying_party_uri);

        // We dispatch, according to the operation GET argument value.
        switch(Operation::from($this->_getArgs->operation)) {
            // This is a two-part operation.
            // The first call generates a challenge string, that is signed and submitted in the second call.
            // It also stashes the GET values for the userID and displayName, in the session variable.
            case Operation::login:
                if (empty($this->_postArgs)) {
                    $this->_loginChallenge();
                } else {
                    $this->_loginCompletion();
                }
                break;
                
            // This is a two-part operation.
            // The first call generates a challenge string, that is signed and submitted in the second call.
            case Operation::createUser:
                if (empty($this->_postArgs)) {
                    $this->_createChallenge();
                } else {
                    $this->_createCompletion();
                }
                break;
                
            // This simply reads the user table, and returns the values, therein.
            case Operation::readUser:
                $this->_handleRead();
                break;
            
            // This updates the user table, with the values provided in the GET arguments.
            case Operation::updateUser:
                $this->_handleUpdate();
                break;
            
            // This simply logs up out, and removes the bearer token from the database.
            case Operation::logout:
                $this->_handleLogout();
                break;
            
            // This completely deletes the currently logged-in user from the database.
            case Operation::deleteUser:
                $this->_handleDelete();
                break;
            
            // We send back a poo emoji, if an illegal operation was prescribed.
            default:
                http_response_code(400);
                echo '&#128169;';   // Oh, poo.
        }
    }
}
