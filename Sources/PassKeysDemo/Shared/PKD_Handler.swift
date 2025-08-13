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
import Combine

/* ###################################################################################################################################### */
// MARK: - PassKeys Interaction Handling Class -
/* ###################################################################################################################################### */
/**
 This class abstracts the communication infrastructure with the server, and acts as a model for the user interface.
 
 This is a Combine ObservableObject, and can be used to subscribe for changes.
 */
open class PKD_Handler: NSObject, ObservableObject {
    /* ###################################################################### */
    /**
     The responding callback to the read method.
     
     This is always called in the main thread.
     
     The first argument is a simple tuple, with strings for the displayName and credo.
     
     The second argument is a LoginResponse, with a report on the transaction success or failure.
     
     Both may be nil.
     */
    public typealias ReadCallback = ((displayName: String, credo: String)?, ServerResponse) -> Void

    /* ###################################################################### */
    /**
     This is the callback from most server operations.
     */
    public typealias ServerResponseCallback = (ServerResponse) -> Void
    
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
         Failed, because of incorrect input parameters.
         */
        case badInputParameters

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
                
            case .badInputParameters:
                ret = "Bad Input Parameters"
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
    enum UserOperation: String {
        /* ################################################################## */
        /**
         No Op.
         */
        case none = ""

        /* ################################################################## */
        /**
         Login a previously registered user, using the userId, and the PassKey.
         */
        case login = "login"

        /* ################################################################## */
        /**
         Log out a currently logged-in user.
         */
        case logout = "logout"

        /* ################################################################## */
        /**
         Create a new user on the server.
         */
        case createUser = "create"

        /* ################################################################## */
        /**
         Read the displayName and credo of a registered (and logged-in) user.
         */
        case readUser = "read"

        /* ################################################################## */
        /**
         Change the displayName and/or credo of the registered (and logged-in) user.
         */
        case updateUser = "update"

        /* ################################################################## */
        /**
         Delete a registered (and logged-in) user.
         */
        case deleteUser = "delete"
    }
    
    /* ################################################################################################################################## */
    // MARK: Responses From Login Attempts
    /* ################################################################################################################################## */
    /**
     This is what is returned to some of the server callbacks.
     */
    public enum ServerResponse {
        /* ################################################################## */
        /**
         There was an unrecoverable error.
         */
        case failure(Error)
        
        /* ################################################################## */
        /**
         No problems. Operation successful.
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
                 This is used to specify the relying party, for the PassKey. It needs to match the one on the server.
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
                 
                 IDs are invisible to the user,a nd we generate a UUID for the ID.
                 */
                let id: String
                
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
     We maintain a consistent session, because the challenges are set to work across a session.
     */
    private var _cachedSession: URLSession?

    /* ###################################################################### */
    /**
     If we are currently logged in, this contains the bearer token. Nil, if not logged in.
     */
    private var _bearerToken: String? { didSet { DispatchQueue.main.async { self.isLoggedIn = !(self._bearerToken ?? "").isEmpty } } }

    /* ###################################################################### */
    /**
     If we are currently logged in, this contains the credential ID. Nil, if not logged in.
     */
    private var _credentialID: String?

    /* ###################################################################### */
    /**
     We hold onto this, so we can calculate a "dirty" state.
     */
    var originalDisplayName = ""

    /* ###################################################################### */
    /**
     We hold onto this, so we can calculate a "dirty" state.
     */
    var originalCredo = ""

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
     This is whatever anchor we are providing the authentication services for their screens.
     
     > NOTE: This should not be nil! Bad things happen, if it is!
     */
    weak var presentationAnchor: ASPresentationAnchor?
    
    /* ###################################################################### */
    /**
     The last operation.
     */
    var lastOperation = UserOperation.none

    /* ###################################################################### */
    /**
     The basic initializer.
     
     - Parameters:
        - inRelyingParty: The ID of the relying party (must match the server)
        - inBaseURIString: The base URI for the server PKDServer.php file
        - inUserNameString:
     */
    public init(relyingParty inRelyingParty: String,
                baseURIString inBaseURIString: String,
                presentationAnchor inPresentationAnchor: ASPresentationAnchor
    ) {
        self.relyingParty = inRelyingParty
        self.baseURIString = inBaseURIString
        self.presentationAnchor = inPresentationAnchor
    }
    
    // MARK: Public Observable Properties
    
    /* ###################################################################### */
    /**
     True, if we are currently logged in.
     */
    @Published public private(set) var isLoggedIn = false
    
    /* ###################################################################### */
    /**
     If the handler encounters an error, it sets this.
     */
    @Published public private(set) var lastError: Error?
}

/* ###################################################################################################################################### */
// MARK: Private Computed Properties
/* ###################################################################################################################################### */
extension PKD_Handler {
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
}

/* ###################################################################################################################################### */
// MARK: Private Instance Methods (Called From the Authorization Callback)
/* ###################################################################################################################################### */
extension PKD_Handler {
    /* ###################################################################### */
    /**
     Called to log in a user, via a POST transaction.
     
     - parameter inURLString: The URL String we are calling.
     - parameter inPayload: The POST arguments.
     */
    private func _postLoginResponse(to inURLString: String, payload inPayload: [String: Any]) {
        guard let url = URL(string: inURLString),
              let responseData = try? JSONSerialization.data(withJSONObject: inPayload),
              !responseData.isEmpty
        else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = responseData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(responseData.count)", forHTTPHeaderField: "Content-Length")
        DispatchQueue.main.async {
            self.lastError = nil
            self._session.dataTask(with: request) { inData, inResponse, inError in
                guard let response = inResponse as? HTTPURLResponse else { return }
                if let data = inData {
                    if 200 == response.statusCode,
                       let token = String(data: data, encoding: .utf8),
                       !token.isEmpty {
                        self._bearerToken = token
                    } else {
                        self._credentialID = nil
                        self._bearerToken = nil
                        DispatchQueue.main.async { self.lastError = Errors.communicationError }
                    }
                }
            }.resume()
        }
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
        DispatchQueue.main.async {
            self.lastError = nil
            self._session.dataTask(with: request) { inData, inResponse, inError in
                guard let response = inResponse as? HTTPURLResponse else { return }
                if let data = inData {
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
                            self.originalDisplayName = displayName
                            self.originalCredo = credo
                        }
                    } else {
                        self._credentialID = nil
                        self._bearerToken = nil
                        DispatchQueue.main.async { self.lastError = Errors.communicationError }
                    }
                }
            }.resume()
        }
    }
}

/* ###################################################################################################################################### */
// MARK: Private Instance Methods (Called From the Operation Dispatcher)
/* ###################################################################################################################################### */
extension PKD_Handler {
    /* ###################################################################### */
    /**
     The first part of registration.
     
     We call this, with a display name, and it starts the process of validating the PassKey, and sets up the session.
     
     - parameter inDisplayName: The display name for the new user. Optional. If not supplied, the server will specify "New User."
     - parameter inCompletion: A tail completion proc. This may be called in any thread. A sucessful result contains a bunch of data from the server, relevant to the PassKey authentication.
     */
    private func _getCreateChallenge(displayName inDisplayName: String? = nil, completion inCompletion: @escaping (Result<_PublicKeyCredentialCreationOptionsStruct, Error>) -> Void) {
        let userIdString = self._createNewUserIdString()
        if !userIdString.isEmpty {
            var urlString = "\(self.baseURIString)/index.php?operation=\(UserOperation.createUser.rawValue)&userId=\(userIdString)"
            if let displayName = inDisplayName?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
               !displayName.isEmpty {
                urlString += "&displayName=\(displayName)"
            }
            guard let url = URL(string: urlString) else { return }
            self._session.dataTask(with: url) { inData, inResponse, inError in
                if let error = inError {
                    inCompletion(.failure(error))
                } else if let data = inData {
                    do {
                        let decoder = JSONDecoder()
                        let options = try decoder.decode(_PublicKeyCredentialCreationOptionsStruct.self, from: data)
                        inCompletion(.success(options))
                    } catch {
                        self.clearUserInfo()
                        inCompletion(.failure(Errors.communicationError))
                    }
                } else {
                    self.clearUserInfo()
                    if let error = inError {
                        inCompletion(.failure(error))
                    } else {
                        inCompletion(.failure(Errors.communicationError))
                    }
                    return
                }
            }.resume()
        } else {
            self.clearUserInfo()
            inCompletion(.failure(Errors.noUserID))
        }
    }
    
    /* ###################################################################### */
    /**
     The second part of registration.
     
     Finalizes the process of validating the PassKey, and sets up the session.
     
     - parameter inOptions: The data supplied by the challenge.
     - parameter inCompletion: A tail completion proc. This may be called in any thread, and is only called for an error. A successful result does nothing, because we finish in the authentication callback.
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
            inCompletion(.failure(Errors.noUserID))
        }
    }
    
    /* ###################################################################### */
    /**
     The first part of login.
     
     Starts the process of validating the PassKey, and sets up the session.
     
     - parameter inCompletion: A tail completion proc. This may be called in any thread. A sucessful result contains the challenge string.
     */
    private func _getLoginChallenge(completion inCompletion: @escaping (Result<String, Error>) -> Void) {
        if let userIdString = self._storedUserIDString,
           !userIdString.isEmpty {
            let urlString = "\(self.baseURIString)/index.php?operation=\(UserOperation.login.rawValue)&userId=\(userIdString)"
            guard let url = URL(string: urlString) else { return }
            self._session.dataTask(with: url) { inData, inResponse, inError in
                if let error = inError {
                    inCompletion(.failure(error))
                } else if let data = inData {
                    if let responseString = String(data: data, encoding: .utf8),
                       !responseString.isEmpty {
                        if let jsonResponse = try? JSONDecoder().decode([String: String].self, from: data),
                           let _ = jsonResponse["error"] {
                            inCompletion(.failure(Errors.noUserID))
                        } else {
                            inCompletion(.success(responseString))
                        }
                    } else {
                        inCompletion(.failure(Errors.communicationError))
                    }
                }
            }.resume()
        } else {
            inCompletion(.failure(Errors.noUserID))
        }
    }
    
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
            self._postCreateResponse(to: "\(self.baseURIString)/index.php?operation=\(UserOperation.createUser.rawValue)", payload: payload)
        } else if let assertion = inAuthorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            self._credentialID = assertion.credentialID.base64EncodedString()
            
            let payload: [String: String] = [
                "clientDataJSON": assertion.rawClientDataJSON.base64EncodedString(),
                "authenticatorData": assertion.rawAuthenticatorData.base64EncodedString(),
                "signature": assertion.signature.base64EncodedString(),
                "credentialId": self._credentialID ?? ""
            ]
            
            self._postLoginResponse(to: "\(self.baseURIString)/index.php?operation=\(UserOperation.login.rawValue)", payload: payload)
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
     This completely removes the user ID from the KeyChain.
     */
    func clearUserInfo() {
        let swiftKeychainWrapper = KeychainSwift()
        swiftKeychainWrapper.synchronizable = true
        swiftKeychainWrapper.delete(Self._userIDKeychainKey)
        swiftKeychainWrapper.clear()
        self._credentialID = nil
        self._bearerToken = nil
    }
    
    /* ###################################################################### */
    /**
     This logs the user in.
     
     > NOTE: The user must be logged out, or this does nothing. The user must also be previously registered.

     - parameter inCompletion: A tail completion callback, with a single LoginResponse argument. Always called on the main thread.
     */
    func login(completion inCompletion: @escaping ServerResponseCallback) {
        self.lastOperation = .login
        DispatchQueue.main.async { self.lastError = nil }
        if self.isRegistered {
            if !self.isLoggedIn {
                self._getLoginChallenge { inResponse in
                    DispatchQueue.main.async {
                        switch inResponse {
                        case .success(let inChallenge):
                            if let challengeData = inChallenge.base64urlDecodedData {
                                let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: self.relyingParty)
                                let request = provider.createCredentialAssertionRequest(challenge: challengeData)
                                
                                let controller = ASAuthorizationController(authorizationRequests: [request])
                                controller.delegate = self
                                controller.presentationContextProvider = self
                                controller.performRequests()
                            } else {
                                self.lastError = Errors.communicationError
                                inCompletion(.failure(Errors.communicationError))
                            }
                            break
                            
                        case .failure(let inError):
                            self.lastError = inError
                            inCompletion(.failure(inError))
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.lastError = Errors.alreadyLoggedIn
                    inCompletion(.failure(Errors.alreadyLoggedIn))
                }
            }
        } else {
            DispatchQueue.main.async {
                self.lastError = Errors.noUserID
                inCompletion(.failure(Errors.noUserID))
            }
        }
    }

    /* ###################################################################### */
    /**
     This logs the user out.
     
     > NOTE: The user must be logged in, or this does nothing.
     
     - parameter inLocalOnly: If true (default is false), then the server will not be sent a logout command.
     - parameter inCompletion: This is an optional tail completion callback, with a single LoginResponse argument. Always called on the main thread.
     */
    func logout(isLocalOnly inLocalOnly: Bool = false, completion inCompletion: ServerResponseCallback? = nil) {
        self.lastOperation = .logout
        guard !inLocalOnly else {
            self._bearerToken = nil
            self._cachedSession = nil
            DispatchQueue.main.async {
                self.lastError = nil
                self.isLoggedIn = false
                inCompletion?(.success)
            }
            return
        }
        DispatchQueue.main.async {
            self.lastError = nil
            if self.isLoggedIn {
                self.lastOperation = .logout
                if self.isRegistered {
                    if self.isLoggedIn,
                       let bearerToken = self._bearerToken,
                       !bearerToken.isEmpty {
                        let urlString = "\(self.baseURIString)/index.php?operation=\(UserOperation.logout.rawValue)"
                        guard let url = URL(string: urlString) else { return }
                        
                        var request = URLRequest(url: url)
                        request.httpMethod = "GET"
                        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
                        
                        self._session.dataTask(with: request) { inData, inResponse, inError in
                            DispatchQueue.main.async {
                                if let error = inError {
                                    self.lastError = error
                                    inCompletion?(.failure(error))
                                } else if let response = inResponse as? HTTPURLResponse,
                                          200 == response.statusCode {
                                    self.isLoggedIn = false
                                    self._bearerToken = nil
                                    self._cachedSession = nil
                                    inCompletion?(.success)
                                } else {
                                    self.lastError = Errors.communicationError
                                    inCompletion?(.failure(Errors.communicationError))
                                }
                            }
                       }.resume()
                    } else {
                        self.lastError = Errors.notLoggedIn
                        inCompletion?(.failure(Errors.notLoggedIn))
                    }
                } else {
                    self.lastError = Errors.noUserID
                    inCompletion?(.failure(Errors.noUserID))
                }
            } else {
                self.lastError = Errors.notLoggedIn
                inCompletion?(.failure(Errors.notLoggedIn))
            }
        }
    }

    /* ###################################################################### */
    /**
     Registers the user as a new one. This also logs in the user.
     
     > NOTE: The user cannot be logged in, and cannot have an existing account.
     
     - parameter inDisplayName: A new display name. If omitted (or blank), then "New User" will be assigned.
     - parameter inCompletion: A tail completion callback. Always called on the main thread.
     */
    func create(displayName inDisplayName: String? = nil, completion inCompletion: @escaping ServerResponseCallback) {
        self.lastOperation = .createUser
        DispatchQueue.main.async { self.lastError = nil }
        if !self.isRegistered {
            if !self.isLoggedIn {
                self._getCreateChallenge(displayName: inDisplayName) { inCreateChallengeResponse in
                    if case .success(let value) = inCreateChallengeResponse {
                        self._nextStepInCreate(with: value) { inResponse in
                            DispatchQueue.main.async {
                                if case let .failure(inReason) = inResponse {
                                    self.lastError = inReason
                                    inCompletion(.failure(inReason))
                                } else {
                                    inCompletion(.success)
                                }
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.lastError = Errors.communicationError
                            inCompletion(.failure(Errors.communicationError))
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.lastError = Errors.alreadyLoggedIn
                    inCompletion(.failure(Errors.alreadyLoggedIn))
                }
            }
        } else {
            DispatchQueue.main.async {
                self.lastError = Errors.alreadyRegistered
                inCompletion(.failure(Errors.alreadyRegistered))
            }
        }
    }

    /* ###################################################################### */
    /**
     Reads the stored user data.
     
     > NOTE: The user needs to be logged in, and must have an existing account.

     - parameter inCompletion: A tail completion callback. Always called on the main thread.
    */
    func read(completion inCompletion: @escaping ReadCallback) {
        self.lastOperation = .readUser
        DispatchQueue.main.async { self.lastError = nil }
        if self.isRegistered {
            if self.isLoggedIn,
            let bearerToken = self._bearerToken,
               !bearerToken.isEmpty {
                let urlString = "\(self.baseURIString)/index.php?operation=\(UserOperation.readUser.rawValue)"
                guard let url = URL(string: urlString) else { return }

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")

                self._session.dataTask(with: request) { inData, inResponse, inError in
                    DispatchQueue.main.async {
                        if let error = inError {
                            inCompletion(nil, .failure(error))
                        } else if let response = inResponse as? HTTPURLResponse,
                                  200 == response.statusCode,
                                  let data = inData, !data.isEmpty,
                                  let dict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: String],
                                  let displayName = dict["displayName"],
                                  let credo = dict["credo"] {
                            self.originalDisplayName = displayName
                            self.originalCredo = credo
                            inCompletion((displayName, credo), .success)
                        } else {
                            self.lastError = Errors.communicationError
                            inCompletion(nil, .failure(Errors.communicationError))
                        }
                    }
                }.resume()
            } else {
                DispatchQueue.main.async {
                    self.lastError = Errors.notLoggedIn
                    inCompletion(nil, .failure(Errors.notLoggedIn))
                }
            }
        } else {
            DispatchQueue.main.async {
                self.lastError = Errors.noUserID
                inCompletion(nil, .failure(Errors.noUserID))
            }
        }
    }

    /* ###################################################################### */
    /**
     Modifies the stored user data.
     
     > NOTE: The user needs to be logged in, and must have an existing account.

     - parameter inDisplayName: The new displayName value.
     - parameter inCredo: The new credo value.
     - parameter inCompletion: A tail completion callback. Always called on the main thread.
          */
    func update(displayName inDisplayName: String, credo inCredo: String, completion inCompletion: @escaping ServerResponseCallback) {
        self.lastOperation = .updateUser
        DispatchQueue.main.async { self.lastError = nil }
        if self.isRegistered {
            if self.isLoggedIn,
               let bearerToken = self._bearerToken,
               !bearerToken.isEmpty {
                if let displayName = inDisplayName.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
                   !displayName.isEmpty {
                    let credo = inCredo.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
                    let urlString = "\(self.baseURIString)/index.php?operation=\(UserOperation.updateUser.rawValue)&displayName=\(displayName)&credo=\(credo)"
                    guard let url = URL(string: urlString) else { return }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
                    
                    self._session.dataTask(with: request) { _, inResponse, inError in
                        DispatchQueue.main.async {
                            if let error = inError {
                                self.lastError = error
                                inCompletion(.failure(error))
                            } else if let response = inResponse as? HTTPURLResponse,
                                      200 == response.statusCode {
                                self.originalDisplayName = displayName
                                self.originalCredo = credo
                                inCompletion(.success)
                            } else {
                                self.lastError = Errors.communicationError
                                inCompletion(.failure(Errors.communicationError))
                            }
                        }
                   }.resume()
               } else {
                   DispatchQueue.main.async {
                       self.lastError = Errors.badInputParameters
                       inCompletion(.failure(Errors.badInputParameters))
                   }
               }
            } else {
                DispatchQueue.main.async {
                    self.lastError = Errors.notLoggedIn
                    inCompletion(.failure(Errors.notLoggedIn))
                }
            }
        } else {
            DispatchQueue.main.async {
                self.lastError = Errors.noUserID
                inCompletion(.failure(Errors.noUserID))
            }
        }
    }

    /* ###################################################################### */
    /**
     Removes the user record.
     
     > NOTE: The user needs to be logged in, and must have an existing account.

     > NOTE: This does not remove the PassKey! The user needs to do that manually.

     - parameter inCompletion: This is an optional tail completion callback, with a single LoginResponse argument. Always called on the main thread.
     */
    func delete(completion inCompletion: ServerResponseCallback? = nil) {
        self.lastOperation = .deleteUser
        DispatchQueue.main.async { self.lastError = nil }
        if self.isRegistered {
            if self.isLoggedIn,
               let bearerToken = self._bearerToken,
               !bearerToken.isEmpty {
                let urlString = "\(self.baseURIString)/index.php?operation=\(UserOperation.deleteUser.rawValue)"
                guard let url = URL(string: urlString) else { return }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
                
                self._session.dataTask(with: request) { _, inResponse, inError in
                    DispatchQueue.main.async {
                        if let error = inError {
                            self.lastError = error
                            inCompletion?(.failure(error))
                        } else if let response = inResponse as? HTTPURLResponse,
                                  200 == response.statusCode {
                            self.logout(isLocalOnly: true) { inResult in
                                DispatchQueue.main.async {
                                    if case let .failure(error) = inResult {
                                        self.lastError = error
                                        inCompletion?(.failure(error))
                                    } else {
                                        self.clearUserInfo()
                                        inCompletion?(.success)
                                    }
                                }
                            }
                        } else {
                            self.lastError = Errors.communicationError
                            inCompletion?(.failure(Errors.communicationError))
                        }
                    }
               }.resume()
            } else {
                DispatchQueue.main.async {
                    self.lastError = Errors.notLoggedIn
                    inCompletion?(.failure(Errors.notLoggedIn))
                }
            }
        } else {
            DispatchQueue.main.async {
                self.lastError = Errors.noUserID
                inCompletion?(.failure(Errors.noUserID))
            }
        }
    }
}
