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

import Foundation
import AuthenticationServices
import KeychainSwift

/* ###################################################################################################################################### */
// MARK: - PassKeys Interaction Handling Class -
/* ###################################################################################################################################### */
/**
 This class abstracts the communication infrastructure with the server, and acts as a model for the user interface.
 */
open class PKD_Handler: NSObject {
    /* ###################################################################### */
    /**
     The responding callback to the context.
     
     This is always called in the main thread.
     
     The first argument is a simple tuple, with strings for the displayName and credo.
     
     The second argument is a LoginResponse, with a report on the transaction success or failure.
     
     Both may be nil.
     */
    public typealias TransactionCallback = ((displayName: String, credo: String)?, LoginResponse) -> Void

    /* ################################################################################################################################## */
    // MARK: Responses From Login Attempts
    /* ################################################################################################################################## */
    /**
     This is what is returned to the login callback.
     */
    public enum Errors: Error {
        /* ################################################################## */
        /**
         Failed, because we have no local userID registered.
         */
        case noUserID
        
        /* ################################################################## */
        /**
         Failed, because already have a user, but should not.
         */
        case alreadyRegistered

        /* ################################################################## */
        /**
         Failed, because not logged in, but should be logged in.
         */
        case notLoggedIn

        /* ################################################################## */
        /**
         Failed, because already logged in, but should be logged out.
         */
        case alreadyLoggedIn

        /* ################################################################## */
        /**
         Failed, because of a communication issue.
         */
        case communicationError

        /* ################################################################## */
        /**
         Returns a localized string, with the error description.
         */
        var localizedDescription: String {
            var ret = "Unknown error"
            
            switch self {
            case .noUserID:
                ret = "No user with this ID registered"
                break
                
            case .alreadyRegistered:
                ret = "A user with this ID is already registered"
                break
                
            case .notLoggedIn:
                ret = "Not logged in"
                break
                
            case .alreadyLoggedIn:
                ret = "Already logged in"
                break
                
            case .communicationError:
                ret = "Communication Error"
                break
           }
            
            return ret
        }
    }

    /* ################################################################################################################################## */
    // MARK: - Server Operation Enum -
    /* ################################################################################################################################## */
    /**
     This enumeration defines the keys that we send to the server, to enumerate which operation we are performing.
     */
    enum Operation: String {
        /* ################################################################## */
        /**
         Login a previously registered user, using the userId, and the PassKey.
         */
        case login

        /* ################################################################## */
        /**
         Log out a currently logged-in user.
         */
        case logout

        /* ################################################################## */
        /**
         Create a new user on the server.
         */
        case createUser

        /* ################################################################## */
        /**
         Read the displayName and credo of a registered (and logged-in) user.
         */
        case readUser

        /* ################################################################## */
        /**
         Change the displayName and/or credo of the registered (and logged-in) user.
         */
        case updateUser

        /* ################################################################## */
        /**
         Delete a registered (and logged-in) user.
         */
        case deleteUser
    }
    
    /* ################################################################################################################################## */
    // MARK: Responses From Login Attempts
    /* ################################################################################################################################## */
    /**
     This is what is returned to the login callback.
     */
    public enum LoginResponse {
        /* ################################################################## */
        /**
         There was an unrecoverable error.
         */
        case failure(Error)
        
        /* ################################################################## */
        /**
         No problems. Login successful.
         */
        case success
    }
    
    /* ################################################################################################################################## */
    // MARK: Used For Working With User Data
    /* ################################################################################################################################## */
    /**
     This has the data sent back, upon successful login or editing.
     */
    private struct _UserDataStruct: Decodable {
        /* ################################################################## */
        /**
         The user's displayed name.
         */
        let displayName: String

        /* ################################################################## */
        /**
         A bit of text, stored on the user's behalf.
         */
        let credo: String
        
        /* ################################################################## */
        /**
         The bearer token, for logged-in users.
         */
        let bearerToken: String
    }
    
    /* ################################################################################################################################## */
    // MARK: Used For Fetching Registration Data
    /* ################################################################################################################################## */
    /**
     This is what the server sends back, when we register,
     */
    private struct _PublicKeyCredentialCreationOptionsStruct: Decodable {
        /* ############################################################################################################################## */
        // MARK: Registration Credentials Structure
        /* ############################################################################################################################## */
        /**
         This struct is used to decode the response from the initial registration.
         */
        struct PublicKeyStruct: Decodable {
            /* ########################################################################################################################## */
            // MARK: Relying Party Structure
            /* ########################################################################################################################## */
            /**
             This struct is used to decode the relying party struct property.
             */
            struct RelyingPartyStruct: Decodable {
                /* ########################################################## */
                /**
                 */
                let id: String
            }

            /* ########################################################################################################################## */
            // MARK: User Information Struct
            /* ########################################################################################################################## */
            /**
             This has the ID and the display name for the user.
             */
            struct UserInfoStruct: Decodable {
                /* ########################################################## */
                /**
                 This is a Base64URL-encoded unique ID for the user.
                 */
                let id: String

                /* ########################################################## */
                /**
                 */
                let name: String
                
                /* ########################################################## */
                /**
                 This is the user's public display name (does not need to be unique).
                 */
                let displayName: String
            }

            /* ############################################################## */
            /**
             The relying party.
             */
            let rp: RelyingPartyStruct

            /* ############################################################## */
            /**
             The user information, associated with this credential.
             */
            let user: UserInfoStruct

            /* ############################################################## */
            /**
             This has a base64URL-encoded challenge string.
             */
            let challenge: String
        }
        
        /* ################################################################## */
        /**
         The public key, associated with this credential.
         */
        let publicKey: PublicKeyStruct
    }

    /* ###################################################################### */
    /**
     The key that we use to store the user ID in the KeyChain.
     */
    static private let _userIDKeychainKey = "PKD_UserID"

    /* ###################################################################### */
    /**
     The error returned, if the credential is not in the server store.
     */
    static private let _errorResponseString = "User not found"

    /* ###################################################################### */
    /**
     We maintain a consistent session, because the challenges are set to work across a session.
     */
    private var _cachedSession: URLSession?

    /* ###################################################################### */
    /**
     If we are currently logged in, this contains the bearer token. Nil, if not logged in.
     */
    private var _bearerToken: String?

    /* ###################################################################### */
    /**
     If we are currently logged in, this contains the credential ID. Nil, if not logged in.
     */
    private var _credentialID: String?

    /* ###################################################################### */
    /**
     This is set to true, if we are registering a new user, before logging in.
     */
    private var _loginAfter = false

    /* ###################################################################### */
    /**
     We hold onto this, so we can calculate a "dirty" state.
     */
    private var _originalDisplayName = ""

    /* ###################################################################### */
    /**
     We hold onto this, so we can calculate a "dirty" state.
     */
    private var _originalCredo = ""

    /* ###################################################################### */
    /**
     The identifier for the relying party.
     */
    let relyingParty: String
    
    /* ###################################################################### */
    /**
     The main URI string for our transactions.
     */
    let baseURIString: String
    
    /* ###################################################################### */
    /**
     The User ID string, as stored in the keychain. Nil, if no string stored.
     */
    private var _storedUserIDString: String? {
        let swiftKeychainWrapper = KeychainSwift()
        swiftKeychainWrapper.synchronizable = true
        
        return swiftKeychainWrapper.get(Self._userIDKeychainKey)
    }

    /* ###################################################################### */
    /**
     The user name string.
     */
    let userNameString: String

    /* ###################################################################### */
    /**
     This is whatever anchor we are providing the authentication services for their screens.
     */
    weak var presentationAnchor: ASPresentationAnchor?
    
    /* ###################################################################### */
    /**
     The user display name string.
     */
    let displayNameString = ""
    
    /* ###################################################################### */
    /**
     The user credo string.
     */
    let credoString = ""

    /* ###################################################################### */
    /**
     */
    init(relyingParty inRelyingParty: String,
         baseURIString inBaseURIString: String,
         userNameString inUserNameString: String,
         presentationAnchor inPresentationAnchor: ASPresentationAnchor) {
        self.relyingParty = inRelyingParty
        self.baseURIString = inBaseURIString
        self.userNameString = inUserNameString
        self.presentationAnchor = inPresentationAnchor
    }
}

/* ###################################################################################################################################### */
// MARK: Computed Properties
/* ###################################################################################################################################### */
extension PKD_Handler {
    /* ###################################################################### */
    /**
     Return our instance property session.
     */
    private var _session: URLSession {
        self._cachedSession ?? {
            let config = URLSessionConfiguration.default
            config.httpCookieStorage = HTTPCookieStorage.shared
            config.httpCookieAcceptPolicy = .always
            let session = URLSession(configuration: config)
            self._cachedSession = session
            return session
        }()
    }
    
    /* ###################################################################### */
    /**
     True, if we are currently logged in. Must also be registered (belt and suspenders).
     */
    private var _isLoggedIn: Bool { !(self._storedUserIDString ?? "").isEmpty && nil != self._cachedSession }
}

/* ###################################################################################################################################### */
// MARK:
/* ###################################################################################################################################### */
extension PKD_Handler {
    /* ###################################################################### */
    /**
     Creates a new random User ID string. This is stored in the keychain.
     It will not overwrite a preexisting string.
     */
    private func _createNewUserIdString() -> String {
        let ret = self._storedUserIDString ?? UUID().uuidString
        
        let swiftKeychainWrapper = KeychainSwift()
        swiftKeychainWrapper.synchronizable = true
        swiftKeychainWrapper.set(ret, forKey: Self._userIDKeychainKey)
        
        return ret
    }

    /* ###################################################################### */
    /**
     Called to log in a user, via a POST transaction.
     
     - parameter inURLString: The URL String we are calling.
     - parameter inPayload: The POST arguments.
     */
    private func _postLoginResponse(to inURLString: String, payload inPayload: [String: Any]) {
    }
    
    /* ###################################################################### */
    /**
     Called to create a new user, via a POST transaction.
     
     - parameter inURLString: The URL String we are calling.
     - parameter inPayload: The POST arguments.
     */
    private func _postCreateResponse(to inURLString: String, payload inPayload: [String: Any]) {
        guard let url = URL(string: inURLString),
              let responseData = try? JSONSerialization.data(withJSONObject: inPayload),
              !responseData.isEmpty
        else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = responseData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(responseData.count)", forHTTPHeaderField: "Content-Length")
        self._session.dataTask(with: request) { inData, inResponse, inError in
            guard let response = inResponse as? HTTPURLResponse else { return }
            print("Status Code: \(response.statusCode)\n")
            if let data = inData,
               let responseString = String(data: data, encoding: .utf8){
                print("Response: \(responseString)\n")
                var displayName = ""
                var credo = ""
                if 200 == response.statusCode,
                   let dict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: String],
                   let token = dict["bearerToken"],
                   !token.isEmpty {
                    self._bearerToken = token
                    let decoder = JSONDecoder()
                    if let userData = try? decoder.decode(_UserDataStruct.self, from: data) {
                        displayName = userData.displayName
                        credo = userData.credo
                        self._originalDisplayName = displayName
                        self._originalCredo = credo
                    }
                    DispatchQueue.main.async { }
                } else {
                    self._credentialID = nil
                    DispatchQueue.main.async { }
                }
            }
        }.resume()
    }
}

/* ###################################################################################################################################### */
// MARK:
/* ###################################################################################################################################### */
extension PKD_Handler {
    /* ###################################################################### */
    /**
     */
    private func _getCreateChallenge(completion inCompletion: @escaping (Result<_PublicKeyCredentialCreationOptionsStruct, Error>) -> Void) {
        let userIdString = self._createNewUserIdString()
        if !userIdString.isEmpty {
            let urlString = "\(self.baseURIString)/index.php?operation=create&userId=\(userIdString)"
            guard let url = URL(string: urlString) else { return }
            self._session.dataTask(with: url) { inData, inResponse, inError in
                if let error = inError {
                    inCompletion(.failure(error))
                } else if let data = inData {
                    do {
                        let decoder = JSONDecoder()
                        let options = try decoder.decode(_PublicKeyCredentialCreationOptionsStruct.self, from: data)
                        inCompletion(.success(options))

                        self.clearUserInfo()

                    } catch {
                        print("JSON decoding error: \(error)")
                        self.clearUserInfo()
                        inCompletion(.failure(Errors.communicationError))
                    }
                } else {
                    self.clearUserInfo()
                    if let error = inError {
                        print("Failed to fetch options: \(inError?.localizedDescription ?? "Unknown error")")
                        inCompletion(.failure(error))
                    } else {
                        print("Failed to fetch options: Communication error")
                        inCompletion(.failure(Errors.communicationError))
                    }
                    return
                }
            }.resume()
        } else {
        }
    }
    
    /* ###################################################################### */
    /**
     */
    private func _nextStepInCreate(with inOptions: _PublicKeyCredentialCreationOptionsStruct, completion inCompletion: @escaping (Result<String, Error>) -> Void) {
        if let userIdString = self._storedUserIDString,
           !userIdString.isEmpty,
           let challengeData = inOptions.publicKey.challenge.base64urlDecodedData,
           let userIDData = inOptions.publicKey.user.id.base64urlDecodedData {
            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: inOptions.publicKey.rp.id)

            let request = provider.createCredentialRegistrationRequest(
                challenge: challengeData,
                name: inOptions.publicKey.user.displayName,
                userID: userIDData
            )

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        } else {
            self.clearUserInfo()
            inCompletion(.failure(Errors.communicationError))
        }
    }
    
    /* ###################################################################### */
    /**
     */
    private func _getLoginChallenge(completion inCompletion: @escaping (Result<String, Error>) -> Void) {
        if let userIdString = self._storedUserIDString,
           !userIdString.isEmpty {
            let urlString = "\(self.baseURIString)/index.php?operation=login&userId=\(userIdString)"
            guard let url = URL(string: urlString) else { return }
            self._session.dataTask(with: url) { inData, inResponse, inError in
                if let error = inError {
                    inCompletion(.failure(error))
                } else {
                    
                }
            }.resume()
        } else {
        }
    }
    
    /* ###################################################################### */
    /**
     */
    private func _performLogin(completion inCompletion: @escaping (Result<String, Error>) -> Void) {
        if let userIdString = self._storedUserIDString,
           !userIdString.isEmpty {
            let urlString = "\(self.baseURIString)/index.php?operation=login"
            guard let url = URL(string: urlString) else { return }
            self._session.dataTask(with: url) { inData, inResponse, inError in
                if let error = inError {
                    inCompletion(.failure(error))
//                } else if let publicKey = inResponse?.publicKey,
//                          let challengeData = publicKey.challenge.base64urlDecodedData,
//                          let userIDData = publicKey.user.id.base64urlDecodedData {
//                    let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: publicKey.rp.id)
//
//                    let request = provider.createCredentialRegistrationRequest(
//                        challenge: challengeData,
//                        name: publicKey.user.displayName,
//                        userID: userIDData
//                    )
//
//                    let controller = ASAuthorizationController(authorizationRequests: [request])
//                    controller.delegate = self
//                    controller.presentationContextProvider = self
//                    controller.performRequests()
                } else {
                    
                }
            }.resume()
        } else {
        }
    }
}

/* ###################################################################################################################################### */
// MARK: ASAuthorizationControllerDelegate Conformance
/* ###################################################################################################################################### */
extension PKD_Handler: ASAuthorizationControllerDelegate {
    /* ###################################################################### */
    /**
     Called when the user completes an authorization screen.
     
     - parameter inAuthController: The auth controller.
     - parameter inAuthorization: The authorization generated by the controller.
     */
    public func authorizationController(controller inAuthController: ASAuthorizationController, didCompleteWithAuthorization inAuthorization: ASAuthorization) {
        if let credential = inAuthorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            let payload: [String: String] = [
                "clientDataJSON": credential.rawClientDataJSON.base64EncodedString(),
                "attestationObject": credential.rawAttestationObject?.base64EncodedString() ?? ""
            ]
            self._credentialID = credential.credentialID.base64EncodedString()
            self._postCreateResponse(to: "\(self.baseURIString)/index.php?operation=create", payload: payload)
        } else if let assertion = inAuthorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            struct AssertionJSON: Codable {
                var type: String = ""
                var challenge: String = ""
                var origin: String = ""
            }
            
            self._credentialID = assertion.credentialID.base64EncodedString()
            
            let payload: [String: String] = [
                "clientDataJSON": assertion.rawClientDataJSON.base64EncodedString(),
                "authenticatorData": assertion.rawAuthenticatorData.base64EncodedString(),
                "signature": assertion.signature.base64EncodedString(),
                "credentialId": self._credentialID ?? ""
            ]
            
            self._postLoginResponse(to: "\(self.baseURIString)/index.php?operation=login", payload: payload)
        }
    }
}

/* ###################################################################################################################################### */
// MARK: ASAuthorizationControllerPresentationContextProviding Conformance
/* ###################################################################################################################################### */
extension PKD_Handler: ASAuthorizationControllerPresentationContextProviding {
    /* ###################################################################### */
    /**
     Called to fetch an anchoring window for auth screens.
     
     - parameter for: The auth controller (ignored).
     - returns: stored presentation anchor. We force the unwrap, because bad things should happen, if it's not valid.
     */
    public func presentationAnchor(for: ASAuthorizationController) -> ASPresentationAnchor { self.presentationAnchor! }
}

/* ###################################################################################################################################### */
// MARK: External API
/* ###################################################################################################################################### */
public extension PKD_Handler {
    /* ###################################################################### */
    /**
     The stored User ID string. Empty, if none.
     */
    var userIDString: String { self._storedUserIDString ?? "" }

    /* ###################################################################### */
    /**
     Returns true, if we are registered (have a stored user ID).
     */
    var isRegistered: Bool { !(self._storedUserIDString ?? "").isEmpty }

    /* ###################################################################### */
    /**
     Returns true, if we are logged in (have an active session).
     */
    var isLoggedIn: Bool { self._isLoggedIn }

    /* ###################################################################### */
    /**
     This completely removes the user ID from the KeyChain.
     */
    func clearUserInfo() {
        let swiftKeychainWrapper = KeychainSwift()
        swiftKeychainWrapper.synchronizable = true
        swiftKeychainWrapper.delete(Self._userIDKeychainKey)
        swiftKeychainWrapper.clear()
    }
    
    /* ###################################################################### */
    /**
     This logs the user in.
     
     > NOTE: The user must be logged out, or this does nothing. The user must also be previously registered.

     - parameter inCompletion: A tail completion callback, with a single LoginResponse argument.
     */
    func login(completion inCompletion: @escaping (LoginResponse) -> Void) {
        if self.isRegistered {
            if !self.isLoggedIn {
                
            } else {
                inCompletion(.failure(Errors.alreadyLoggedIn))
            }
        } else {
            inCompletion(.failure(Errors.noUserID))
        }
    }

    /* ###################################################################### */
    /**
     This logs the user out.
     
     > NOTE: The user must be logged in, or this does nothing.
     
     - parameter inCompletion: This is an optional tail completion callback, with a single LoginResponse argument.
     */
    func logout(completion inCompletion: ((LoginResponse) -> Void)? = nil) {
        if self.isLoggedIn {
            
        } else {
            inCompletion?(.failure(Errors.notLoggedIn))
        }
    }

    /* ###################################################################### */
    /**
     Registers the user as a new one. This also logs in the user.
     
     > NOTE: The user cannot be logged in, and cannot have an existing account.
     
     - parameter inCompletion: A tail completion callback.
     */
    func create(displayName: String, credo: String, completion inCompletion: @escaping TransactionCallback) {
        if !self.isRegistered {
            if !self.isLoggedIn {
                self._getCreateChallenge { inCreateChallengeResponse in
                    print(inCreateChallengeResponse)
                    if case .success(let value) = inCreateChallengeResponse {
                        self._nextStepInCreate(with: value) { inResponse in
                            inCompletion(nil, .success)
                        }
                    }
                }
            } else {
                inCompletion(nil, .failure(Errors.alreadyLoggedIn))
            }
        } else {
            inCompletion(nil, .failure(Errors.alreadyRegistered))
        }
    }

    /* ###################################################################### */
    /**
     Reads the stored user data.
     
     > NOTE: The user needs to be logged in, and must have an existing account.

     - parameter inCompletion: A tail completion callback.
    */
    func read(completion inCompletion: @escaping TransactionCallback) {
        if self.isRegistered {
            if self.isLoggedIn {
                
            } else {
                inCompletion(nil, .failure(Errors.notLoggedIn))
            }
        } else {
            inCompletion(nil, .failure(Errors.noUserID))
        }
    }

    /* ###################################################################### */
    /**
     Modifies the stored user data.
     
     > NOTE: The user needs to be logged in, and must have an existing account.

     - parameter inCompletion: A tail completion callback.
          */
    func update(displayName: String, credo: String, completion inCompletion: @escaping TransactionCallback) {
        if self.isRegistered {
            if self.isLoggedIn {
                
            } else {
                inCompletion(nil, .failure(Errors.notLoggedIn))
            }
        } else {
            inCompletion(nil, .failure(Errors.noUserID))
        }
    }

    /* ###################################################################### */
    /**
     Removes the user record.
     
     > NOTE: The user needs to be logged in, and must have an existing account.

     > NOTE: This does not remove the PassKey! The user needs to do that manually.

     - parameter inCompletion: This is an optional tail completion callback, with a single LoginResponse argument.
     */
    func delete(completion inCompletion: ((LoginResponse) -> Void)? = nil) {
        if self.isLoggedIn {
            self.clearUserInfo()
        } else {
            inCompletion?(.failure(Errors.notLoggedIn))
        }
    }
}
