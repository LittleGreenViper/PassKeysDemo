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
These are the various operation keys.

Every call needs to have a "operation" GET query argument, with one of these values.

The other query arguments/POST parameters, depend on the operation.

Each of these denotes a challenge/response pair of calls.
*/
enum Operation: String {
    /**************************************/
    /**
    Established a logged-in connection.
    
    The login only lasts as long as the session.
     */
    case login = 'login';

    /**************************************/
    /**
    This closes the login, and clears the session.
     */
    case logout = 'logout';

    /**************************************/
    /**
    This is called for creating a new user (must be unique).
    
    The call requires a unique userId, and displayName. Also, the session must be logged in.
     */
    case createUser = 'create';

    /**************************************/
    /**
    This reads an existing user, and returns the data associated with the user.
    
    The call requires a unique userId. Also, the session must be logged in.
     */
    case readUser = 'read';

    /**************************************/
    /**
    This updates an existing user.
    
    The call requires a unique userId, displayName, and credo. Also, the session must be logged in.
     */
    case updateUser = 'update';

    /**************************************/
    /**
    This is called delete an existing user.
    
    The call requires a unique userId. Also, the session must be logged in.
     */
    case deleteUser = 'delete';
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

        switch(Operation::from($this->getArgs->operation)) {
            case Operation::login:
                if (!empty($this->getArgs->userId)) {
                    $this->loginChallenge();
                } else {
                    $this->loginCompletion();
                }
                break;
                
            case Operation::createUser:
                if (!empty($this->getArgs->userId)) {
                    $this->createChallenge();
                } else {
                    $this->createCompletion();
                }
                break;
                
            case Operation::readUser:
                $this->handleRead();
                break;
                
            case Operation::updateUser:
                $this->handleUpdate();
                break;
                
            case Operation::logout:
                $this->doLogout();
                break;
                
            case Operation::deleteUser:
                $this->doDelete();
                break;

            default:
                http_response_code(400);
                echo '&#128169;';   // Oh, poo.
        }
    }
    
    /**************************************/
    /**
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
    
    /**************************************/
    /**
    The first part of the login operation.
    
    This is called with a userId, and returns the challenge string, as Base64 URL-encoded.
    */
    public function loginChallenge() {
        $stmt = $this->pdoInstance->prepare('SELECT credentialId FROM webauthn_credentials WHERE userId = ?');
        $stmt->execute([$this->getArgs->userId]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!empty($row)) {
            $challenge = random_bytes(32);  // Create a new challenge.
            // Pass these on to the next step.
            $_SESSION['loginChallenge'] = $challenge;
            $_SESSION['loginUserId'] = $this->getArgs->userId;
            echo(base64url_encode($challenge));
        } else {
            http_response_code(404);
            header('Content-Type: application/json');
            echo json_encode(['error' => 'User not found']);
        }
    }
    
    /**************************************/
    /**
    The second part of the login operation.
    
    This requires JSON structures in the POST, with the credentials from the app.
    
    It returns the bearerToken for the login.
    */
    public function loginCompletion() {
        $userId = $_SESSION['loginUserId'];
        $challenge = $_SESSION['loginChallenge'];
        if (!empty($userId)) {
            $stmt = $this->pdoInstance->prepare('SELECT credentialId, displayName, signCount, publicKey FROM webauthn_credentials WHERE userId = ?');
            $stmt->execute([$userId]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            $credentialId = $row['credentialId'];
            $clientDataJSON = base64_decode($this->postArgs['clientDataJSON']);   // This is a signed record, with various user data.
            $authenticatorData = base64_decode($this->postArgs['authenticatorData']); // A record, with any authenticator (YubiKey, etc. Not used for our demo).
            $signature = base64_decode($this->postArgs['signature']); // The signature for the record, against the public key.
            $publicKey = $row['publicKey'];
            $signCount = intval($row['signCount']);
            
            if (!empty($credentialId)) {
                // If there was no signed client data record, with a matching challenge, then game over, man.
                try {
                    $success = $this->webAuthnInstance->processGet(
                        $clientDataJSON,
                        $authenticatorData,
                        $signature,
                        $publicKey,
                        $challenge,
                        $signCount
                    );
                    
                    // Create a new token, as this is a new login. NOTE: This needs to be Base64URL encoded, not just Base64 encoded.
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
                echo json_encode(['error' => 'User not found']);
            }
        } else {
            http_response_code(400);
            echo '&#128169;';   // Oh, poo.
        }
    }
    
    /**************************************/
    /**
    The first part of the create operation.
    
    This is called with a userId (and optionally, a display name), and returns the public key struct, as JSON.
    */
    public function createChallenge() {
        $userId = $this->getArgs->userId;
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
    
    It responds with the displayName, credo, and bearerToken for the new user.
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
                    $data->credentialId,
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
    
    /***********************/
    /**
        Updates the user table with the new values (or simply returns the current values).
        @param string $userId The user ID from the credentials.
        @param string $displayName The user's display name (if being changed).
        NOTE: This should be set for any change, even if this string is not changed from what's in the DB.
        @param string $credo The user's credo string (if being changed).
        @return the data provided, as a Base64URL-encoded string.
     */
    function performUpdate($userId, $bearerToken, $displayName, $credo) {
        $stmt = $this->pdoInstance->prepare('SELECT displayName, credo FROM passkeys_demo_users WHERE userId = ?');
        $stmt->execute([$userId]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
    
        if (!empty($bearerToken) && !empty($row)&& !empty($row['displayName'])) {
            if ($update) {
                if (empty($displayName)) {
                    $displayName = $row['displayName'];
                }
                
                if (empty($credo)) {
                    $credo = '';
                }
                
                if (($displayName != $row['displayName']) || ($credo != $row['credo'])) {
                    $stmt = $this->pdoInstance->prepare('UPDATE passkeys_demo_users SET displayName = ?, credo = ? WHERE userId = ?');
                    $stmt->execute([$displayName, $credo, $userId]);
                    $row = ['displayName' => $displayName, 'credo' => $credo];
                }
            }
            
            header('Content-Type: application/json');
            echo json_encode(['displayName' => $row['displayName'], 'credo' => $row['credo'], 'bearerToken' => $bearerToken]);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'User not found']);
        }
    }
    
    /***********************/
    /**
    Performs a full logout (removes the bearer token from the DB, and sets the session to empty).
     */
    function doLogout() {
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
    function doDelete() {
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
                        try {   // We wrap in a transaction, so we won't have only one table row deleted, if there's an error.
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