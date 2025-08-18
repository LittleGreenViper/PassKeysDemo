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
import AuthenticationServices   // PassKey Access
import LocalAuthentication      // To test whether or not biometrics are enabled
import Combine                  // To make the class observable.

/* ###################################################################################################################################### */
// MARK: - PassKeys Interaction Handling Class -
/* ###################################################################################################################################### */
/**
 This class abstracts the communication infrastructure with the server, and acts as a model for the user interface.
 
 It can be integrated into either a UIKit app, or a SwiftUI one.
 
 This is a Combine ObservableObject, and can be observed for changes.
 
 ## FUNCTIONALITY:
 
 This uses a shared `URLSession` (stored locally in ``PKD_Handler._cachedSession``) to interact with the server component of this demonstration app.
 
 In order to access PassKeys, it uses an `AuthenticationServices` `ASAuthorizationController` Instance, to create a new PassKey (Create),
 or it instantiates an `ASAuthorizationPlatformPublicKeyCredentialProvider` instance, to access existing PassKeys (Login).
 
 PassKey use is a two-step interaction with the server. We only use them in Create and Login.
 
 Once logged in, we use a bearer token, and maintain the session.
 The server matches the token in its session variable, against the one sent by the client, and also stores a copy in the credential database table.

 The first step in either of the PassKey operations, is to fetch a "challenge" from the server. This is a simple numeric token, generated randomly by the server.
 The client then uses `AuthenticationServices` to integrate this challenge into a signed credential payload, that is returned to the server.
 The server then validates the signed credential, and also verifies that the challenge is the same one that it just sent.
 
 In the case of Create, the server challenge is somewhat involved, as it returns some other data to be used by the client.
 
 For login, it is just a simple number.
 
 ## USAGE:
 
 Use the methods exposed as public, at the end of this file:
 
 ### PassKey Operations:
 
 These operations will involve PassKeys, and use `AuthenticationServices` to access them.
 
 - ``PKD_Handler.create()``: This expects a name for the passKey. It must be unique for the server. Once set, it cannot be changed, and will be displayed as the PassKey name.
 
 - ``PKD_Handler.login()``: This uses the `AuthenticationServices` to present a PassKey selection screen to the user. If there is only one passkey, it will be named, otherwise, a list is presented. The user then executes a biometric authentication, and the login begins. A successful login operation returns a bearer token, to be returned, in subsequent operations, via the authentication header.
 
 ### Post-Login Operations:
 
 These operations require a successful login, and that the URL session be retained (the app is not quit).
 
 - ``PKD_Handler.logout()``: This logs the user out, deletes the local credentials, and closes the session. It will usually contact the server, to ensure that the bearer token is removed, but can also be local-only.
 
 - ``PKD_Handler.read()``: This reads the user data from the data table, and returns it to the calling context.
 
 - ``PKD_Handler.update()``: This changes the user data.
 
 - ``PKD_Handler.delete()``: This deletes the user data from the server, and also performs a logout.
 
 ### Published Observable Properties:
 
 These properties can be observed, using Combine.
 
 - ``PKD_Handler.originalDisplayName``: This is the display name, as stored on the server. It can be used to compare for changes, in the UI-controlled text. It is updated, whenever an update is sent to the server, so it can be assumed to always reflect the server-stored value.
 
 - ``PKD_Handler.originalCredo``: This is the credo, as stored on the server. It can be used to compare for changes, in the UI-controlled text. It is updated, whenever an update is sent to the server, so it can be assumed to always reflect the server-stored value.
 
 - ``PKD_Handler.isLoggedIn``: This is set to true, when the handler has successfully logged in. It remains true, until logout.
 
 - ``PKD_Handler.lastError``: This is any error that the handler wants the calling context to know about. It is changed at the time the error is recorded by the handler, so may come before completion.
 
 The observable properties, and the completion closures for the public methods, are always changed/called in the main thread.
 */
public class PKD_Handler: NSObject, ObservableObject {
    // MARK: Private Data Types
    
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
    
    // MARK: Private Properties
    
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
     The identifier for the relying party.
     */
    private let _relyingParty: String
    
    /* ###################################################################### */
    /**
     The main URI string for our transactions.
     */
    private let _baseURIString: String

    /* ###################################################################### */
    /**
     This is whatever anchor we are providing the authentication services for their screens.
     
     > NOTE: This should not be nil at runtime! Bad things happen, if it is!
     */
    private var _presentationAnchor: ASPresentationAnchor! = nil

    // MARK: Public Init and Properties
    
    /* ###################################################################### */
    /**
     The basic initializer.
     
     - Parameters:
        - inRelyingParty: The ID of the relying party (must match the server)
        - inBaseURIString: The base URI for the server PKDServer.php file
        - inPresentationAnchor: The anchor to be used, when alerts are shown.
     */
    public init(relyingParty inRelyingParty: String,
                baseURIString inBaseURIString: String,
                presentationAnchor inPresentationAnchor: ASPresentationAnchor
    ) {
        self._relyingParty = inRelyingParty
        self._baseURIString = inBaseURIString
        self._presentationAnchor = inPresentationAnchor
    }
    
    /* ###################################################################### */
    /**
     The last operation.
     */
    public var lastOperation = UserOperation.none

    // MARK: Public Observable Properties

    /* ###################################################################### */
    /**
     We hold onto this, so we can calculate a "dirty" state.
     */
    @Published public private(set) var originalDisplayName = ""

    /* ###################################################################### */
    /**
     We hold onto this, so we can calculate a "dirty" state.
     */
    @Published public private(set) var originalCredo = ""

    /* ###################################################################### */
    /**
     True, if we are currently logged in.
     */
    @Published public private(set) var isLoggedIn = false
    
    /* ###################################################################### */
    /**
     If the handler encounters an error, it sets this.
     */
    @Published public var lastError: PKD_Errors = .none
}

/* ###################################################################################################################################### */
// MARK: Private Computed Properties
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
     Returns true, if we have biometrics available.
     */
    private var _isBiometricAuthAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        
        // Check if device can evaluate policy
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            // At least one biometric type (Face ID or Touch ID) is enrolled and available
            return true
        } else {
            // No biometrics enrolled, or not available (error explains why)
            return false
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
     
     - parameter inPassKeyName: The "tag" name for the new user's PassKey. This is fixed, after creation, and always displayed when the PassKey is referenced by the Authentication Services.
     - parameter inCompletion: A tail completion proc. This may be called in any thread. A sucessful result contains a bunch of data from the server, relevant to the PassKey authentication.
     */
    private func _getCreateChallenge(passKeyName inPassKeyName: String, completion inCompletion: @escaping (Result<_PublicKeyCredentialCreationOptionsStruct, Error>) -> Void) {
        // We need to create a unique user ID. After this, we're done with it. We do it here, because PHP doesn't actually have a true built-in UUID generator, and we do.
        if let urlIDString = UUID().uuidString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) {    // Need to use alphanumerics, because the Base64 encoding can have "+".
            var urlString = "\(self._baseURIString)/index.php?operation=\(UserOperation.createUser.rawValue)&userId=\(urlIDString)"
            if let passKeyName = inPassKeyName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               !passKeyName.isEmpty {
                urlString += "&displayName=\(passKeyName)"
            }
            guard let url = URL(string: urlString) else { return }
            self._session.dataTask(with: url) { inData, inResponse, inError in
                if let error = inError {
                    inCompletion(.failure(error))
                } else if let data = inData,
                          let response = inResponse as? HTTPURLResponse {
                    if 200 == response.statusCode {
                        do {
                            let decoder = JSONDecoder()
                            let options = try decoder.decode(_PublicKeyCredentialCreationOptionsStruct.self, from: data)
                            inCompletion(.success(options))
                        } catch {
                            self._clearUserInfo()
                            inCompletion(.failure(PKD_Errors.communicationError(nil)))
                        }
                    } else if 409 == response.statusCode {
                        self._clearUserInfo()
                        inCompletion(.failure(PKD_Errors.alreadyRegistered))
                    } else {
                        self._clearUserInfo()
                        inCompletion(.failure(PKD_Errors.communicationError(nil)))
                    }
                } else {
                    self._clearUserInfo()
                    if let error = inError {
                        inCompletion(.failure(error))
                    } else {
                        inCompletion(.failure(PKD_Errors.communicationError(nil)))
                    }
                    return
                }
            }.resume()
        } else {
            self._clearUserInfo()
            inCompletion(.failure(PKD_Errors.noUserID))
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
        if let challengeData = inOptions.publicKey.challenge.base64urlDecodedData,
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
            self._clearUserInfo()
            inCompletion(.failure(PKD_Errors.noUserID))
        }
    }
    
    /* ###################################################################### */
    /**
     The first part of login.
     
     Starts the process of validating the PassKey, and sets up the session.
     
     - parameter inCompletion: A tail completion proc. This may be called in any thread. A sucessful result contains the challenge string, as well as any allowed credential IDs..
     */
    private func _getLoginChallenge(completion inCompletion: @escaping (Result<(challenge: String, allowedIDs: [String]), Error>) -> Void) {
        let urlString = "\(self._baseURIString)/index.php?operation=\(UserOperation.login.rawValue)"
        
        guard let url = URL(string: urlString) else { return }
        
        self._session.dataTask(with: url) { inData, inResponse, inError in
            if let error = inError {
                inCompletion(.failure(error))
            } else if let data = inData,
                      !data.isEmpty,
                      let simpleJSON = try? JSONSerialization.jsonObject(with: data, options: []),
                      let mainDict = simpleJSON as? [String: Any] {
                guard let allowedIDs = mainDict["allowedIDs"] as? [String]
                else {
                    inCompletion(.failure(PKD_Errors.noAvailablePassKeys))
                    return
                }
                if let challenge = mainDict["challenge"] as? String {
                    inCompletion(.success((challenge, allowedIDs)))
                }
            } else {
                inCompletion(.failure(PKD_Errors.communicationError(nil)))
            }
        }.resume()
    }
    
    /* ###################################################################### */
    /**
     This completely removes the user data from the instance.
     
     > NOTE: This only works locally. It does not send anything to the server.
     */
    private func _clearUserInfo() {
        self.originalCredo = ""
        self.originalDisplayName = ""
        self._credentialID = nil
        self._bearerToken = nil
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
            self._credentialID = credential.credentialID.base64EncodedString()
            let payload: [String: String] = [
                "clientDataJSON": credential.rawClientDataJSON.base64EncodedString(),
                "attestationObject": credential.rawAttestationObject?.base64EncodedString() ?? ""
            ]
            
            self._postCreateResponse(to: "\(self._baseURIString)/index.php?operation=\(UserOperation.createUser.rawValue)", payload: payload)
        } else if let assertion = inAuthorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            self._credentialID = assertion.credentialID.base64EncodedString()
            if let idString = self._credentialID,
               !idString.isEmpty,
               let urlIDString = idString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) {    // Need to use alphanumerics, because the Base64 encoding can have "+".
                let payload: [String: String] = [
                    "clientDataJSON": assertion.rawClientDataJSON.base64EncodedString(),
                    "authenticatorData": assertion.rawAuthenticatorData.base64EncodedString(),
                    "signature": assertion.signature.base64EncodedString(),
                    "credentialId": idString
                ]
                
                self._postLoginResponse(to: "\(self._baseURIString)/index.php?operation=\(UserOperation.login.rawValue)&credentialId=\(urlIDString)", payload: payload)
            }
        }
    }
    
    /* ###################################################################### */
    /**
     Called when the passKey auth fails.
     
     - parameter inAuthController: The auth controller.
     - parameter inError: The authorization generated by the controller.
     */
    public func authorizationController(controller inAuthController: ASAuthorizationController, didCompleteWithError inError: Error) {
        self.lastError = .login == self.lastOperation ? PKD_Errors.noAvailablePassKeys : PKD_Errors.communicationError(inError)
    }
}

/* ###################################################################################################################################### */
// MARK: Private Instance Methods (Called From the Authorization Callback)
/* ###################################################################################################################################### */
extension PKD_Handler {
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
            self.lastError = .none
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
                            DispatchQueue.main.async {
                                self.originalDisplayName = displayName
                                self.originalCredo = credo
                                self.isLoggedIn = true
                            }
                        } else {
                            self._credentialID = nil
                            self._bearerToken = nil
                            DispatchQueue.main.async {
                                self.lastError = PKD_Errors.communicationError(nil)
                                self.isLoggedIn = false
                            }
                        }
                    } else {
                        self._credentialID = nil
                        self._bearerToken = nil
                        DispatchQueue.main.async {
                            self.lastError = PKD_Errors.communicationError(nil)
                            self.isLoggedIn = false
                        }
                    }
                }
            }.resume()
        }
    }
    
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
            self.lastError = .none
            self._session.dataTask(with: request) { inData, inResponse, inError in
                guard let response = inResponse as? HTTPURLResponse else { return }
                print(response.statusCode)
                if let data = inData {
                    if 200 == response.statusCode,
                       let token = String(data: data, encoding: .utf8),
                       !token.isEmpty {
                        self._bearerToken = token
                        DispatchQueue.main.async { self.isLoggedIn = true }
                    } else if 404 == response.statusCode {
                        self._credentialID = nil
                        self._bearerToken = nil
                        DispatchQueue.main.async {
                            self.lastError = PKD_Errors.noUserID
                            self.isLoggedIn = false
                        }
                    } else {
                        self._credentialID = nil
                        self._bearerToken = nil
                        DispatchQueue.main.async {
                            self.lastError = PKD_Errors.communicationError(nil)
                            self.isLoggedIn = false
                        }
                    }
                } else {
                    self._credentialID = nil
                    self._bearerToken = nil
                    DispatchQueue.main.async {
                        self.lastError = PKD_Errors.communicationError(nil)
                        self.isLoggedIn = false
                    }
                }
            }.resume()
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
    public func presentationAnchor(for: ASAuthorizationController) -> ASPresentationAnchor { self._presentationAnchor! }
}

/* ###################################################################################################################################### */
// MARK: External API
/* ###################################################################################################################################### */
public extension PKD_Handler {
    /* ################################################################################################################################## */
    // MARK: Responses From Login Attempts
    /* ################################################################################################################################## */
    /**
     This is what is returned to the login callback.
     */
    enum PKD_Errors: Error {
        /* ################################################################## */
        /**
         No error.
         */
        case none
        
        /* ################################################################## */
        /**
         Failed, because yes, we have no PassKeys!
         */
        case noAvailablePassKeys
        
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
         Failed, because of a communication issue. The associated value is any system error provided.
         */
        case communicationError(Error?)
        
        /* ################################################################## */
        /**
         Failed, because of incorrect input parameters.
         */
        case badInputParameters
        
        /* ################################################################## */
        /**
         Failed, because the device does not have biometrics enabled.
         */
        case biometricsNotAvailable
    }
    
    /* ################################################################################################################################## */
    // MARK: Server Operation Enum
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
         Login a previously registered user, using the PassKey.
         */
        case login = "login"
        
        /* ################################################################## */
        /**
         Log out a currently logged-in user.
         */
        case logout = "logout"
        
        /* ################################################################## */
        /**
         Create a new user on the server, and set up a local PassKey.
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
    // MARK: Response Data Type
    /* ################################################################################################################################## */
    /**
     This is what is returned to some of the server callbacks.
     */
    enum ServerResponse {
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
    // MARK: Callback/Completion Types
    /* ################################################################################################################################## */
    /**
     These are typealiases for our completion callbacks.
     */
    /* ###################################################################### */
    /**
     The responding callback to the read method.
     
     This is always called in the main thread.
     
     The first argument is a simple tuple, with strings for the displayName and credo, and may be nil.
     
     The second argument is a ``PKD_Handler.ServerResponse``, with a report on the transaction success or failure.
     */
    typealias ReadCallback = ((displayName: String, credo: String)?, ServerResponse) -> Void
    
    /* ###################################################################### */
    /**
     This is the callback from most server operations.
     */
    typealias ServerResponseCallback = (ServerResponse) -> Void
    
    /* ################################################################################################################################## */
    // MARK: Public API Methods
    /* ################################################################################################################################## */
    /**
     These are the various methods that can be called to use the API.
     */
    /* ###################################################################### */
    /**
     This logs the user in.
     
     > NOTE: The user must be logged out, or this does nothing. The user must also be previously registered.
     
     - parameter inCompletion: A tail completion callback, with a single LoginResponse argument. Always called on the main thread.
     */
    func login(completion inCompletion: @escaping ServerResponseCallback) {
        self.lastOperation = .login
        guard self._isBiometricAuthAvailable else {
            DispatchQueue.main.async { self.lastError = PKD_Errors.biometricsNotAvailable }
            return
        }
        DispatchQueue.main.async { self.lastError = .none }
        if !self.isLoggedIn {
            self._getLoginChallenge { inResponse in
                DispatchQueue.main.async {
                    switch inResponse {
                    case .success(let inResponse):
                        // inResponse.challenge is the challenge string (Base64URL-encoded).
                        // inResponse.allowedIDs is an Array of String, with each string being an allowed credential ID (Base64-encoded).
                        if let challengeData = inResponse.challenge.base64urlDecodedData {
                            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: self._relyingParty)
                            let request = provider.createCredentialAssertionRequest(challenge: challengeData)
                            let controller = ASAuthorizationController(authorizationRequests: [request])
                            controller.delegate = self
                            controller.presentationContextProvider = self

                            // This part will filter out IDs that we have deleted on the server, but not on the device. It makes sure that we only present PassKeys that exist on the server.
                            let allowedCredentials: [ASAuthorizationPlatformPublicKeyCredentialDescriptor] = inResponse.allowedIDs.compactMap { Data(base64Encoded: $0) }.filter { !$0.isEmpty }.map {
                                ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0)
                            }
                            
                            guard !allowedCredentials.isEmpty else {
                                self.lastError = PKD_Errors.noAvailablePassKeys
                                inCompletion(.failure(PKD_Errors.noAvailablePassKeys))
                                break
                            }
                            
                            request.allowedCredentials = allowedCredentials
                            
                            controller.performRequests()
                        } else {
                            self.lastError = PKD_Errors.communicationError(nil)
                            inCompletion(.failure(PKD_Errors.communicationError(nil)))
                        }
                        
                    case .failure(let inError):
                        if let error = inError as? PKD_Errors {
                            self.lastError = error
                            inCompletion(.failure(error))
                        } else {
                            self.lastError = PKD_Errors.communicationError(inError)
                            inCompletion(.failure(PKD_Errors.communicationError(inError)))
                        }
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                self.lastError = PKD_Errors.alreadyLoggedIn
                inCompletion(.failure(PKD_Errors.alreadyLoggedIn))
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
                self.lastError = .none
                self.isLoggedIn = false
                inCompletion?(.success)
            }
            return
        }
        
        DispatchQueue.main.async {
            self.lastError = .none
            if self.isLoggedIn {
                self.lastOperation = .logout
                if self.isLoggedIn,
                   let bearerToken = self._bearerToken,
                   !bearerToken.isEmpty {
                    let urlString = "\(self._baseURIString)/index.php?operation=\(UserOperation.logout.rawValue)"
                    guard let url = URL(string: urlString) else { return }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
                    
                    self._session.dataTask(with: request) { inData, inResponse, inError in
                        DispatchQueue.main.async {
                            if let error = inError {
                                self.lastError = PKD_Errors.communicationError(error)
                                inCompletion?(.failure(PKD_Errors.communicationError(error)))
                            } else if let response = inResponse as? HTTPURLResponse,
                                      200 == response.statusCode {
                                self.isLoggedIn = false
                                self._bearerToken = nil
                                self._cachedSession = nil
                                inCompletion?(.success)
                            } else {
                                self.lastError = PKD_Errors.communicationError(nil)
                                inCompletion?(.failure(PKD_Errors.communicationError(nil)))
                            }
                        }
                    }.resume()
                } else {
                    self.lastError = PKD_Errors.notLoggedIn
                    inCompletion?(.failure(PKD_Errors.notLoggedIn))
                }
            } else {
                self.lastError = PKD_Errors.notLoggedIn
                inCompletion?(.failure(PKD_Errors.notLoggedIn))
            }
        }
    }
    
    /* ###################################################################### */
    /**
     Registers the user as a new one. This also logs in the user.
     
     > NOTE: The user cannot be already logged in, and cannot have an existing account.
     
     - parameter inPassKeyName: A new passkey name. This must be unique. Once assigned, this cannot be changed.
     - parameter inCompletion: A tail completion callback. Always called on the main thread.
     */
    func create(passKeyName inPassKeyName: String, completion inCompletion: @escaping ServerResponseCallback) {
        self.lastOperation = .createUser
        guard self._isBiometricAuthAvailable else {
            DispatchQueue.main.async { self.lastError = PKD_Errors.biometricsNotAvailable }
            return
        }
        
        DispatchQueue.main.async { self.lastError = .none }
        
        if !self.isLoggedIn {
            self._getCreateChallenge(passKeyName: inPassKeyName) { inCreateChallengeResponse in
                if case .success(let inValue) = inCreateChallengeResponse {
                    self._nextStepInCreate(with: inValue) { inResponse in
                        DispatchQueue.main.async {
                            if case let .failure(inReason) = inResponse {
                                self.lastError = PKD_Errors.communicationError(inReason)
                                inCompletion(.failure(PKD_Errors.communicationError(inReason)))
                            } else {
                                inCompletion(.success)
                            }
                        }
                    }
                } else if case .failure(let inError) = inCreateChallengeResponse,
                          let error = inError as? PKD_Errors {
                    DispatchQueue.main.async {
                        self.lastError = error
                        inCompletion(.failure(error))
                    }
                } else {
                    DispatchQueue.main.async {
                        self.lastError = PKD_Errors.communicationError(nil)
                        inCompletion(.failure(PKD_Errors.communicationError(nil)))
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                self.lastError = PKD_Errors.alreadyLoggedIn
                inCompletion(.failure(PKD_Errors.alreadyLoggedIn))
            }
        }
    }
    
    /* ###################################################################### */
    /**
     Reads the stored user data.
     
     > NOTE: The user needs to be logged in.
     
     - parameter inCompletion: A tail completion callback. Always called on the main thread.
     */
    func read(completion inCompletion: @escaping ReadCallback) {
        self.lastOperation = .readUser
        
        DispatchQueue.main.async { self.lastError = .none }
        
        if self.isLoggedIn,
           let bearerToken = self._bearerToken,
           !bearerToken.isEmpty {
            let urlString = "\(self._baseURIString)/index.php?operation=\(UserOperation.readUser.rawValue)"
            guard let url = URL(string: urlString) else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
            
            self._session.dataTask(with: request) { inData, inResponse, inError in
                print("Response: \((inResponse as? HTTPURLResponse)?.statusCode ?? -1)")
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
                        self.lastError = PKD_Errors.communicationError(nil)
                        inCompletion(nil, .failure(PKD_Errors.communicationError(nil)))
                    }
                }
            }.resume()
        } else {
            DispatchQueue.main.async {
                self.lastError = PKD_Errors.notLoggedIn
                inCompletion(nil, .failure(PKD_Errors.notLoggedIn))
            }
        }
    }
    
    /* ###################################################################### */
    /**
     Modifies the stored user data.
     
     > NOTE: The user needs to be logged in.
     
     - parameter inDisplayName: The new displayName value.
     - parameter inCredo: The new credo value.
     - parameter inCompletion: A tail completion callback. Always called on the main thread.
     */
    func update(displayName inDisplayName: String, credo inCredo: String, completion inCompletion: @escaping ServerResponseCallback) {
        self.lastOperation = .updateUser
        
        DispatchQueue.main.async { self.lastError = .none }
        
        if self.isLoggedIn,
           let bearerToken = self._bearerToken,
           !bearerToken.isEmpty {
            if let displayName = inDisplayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               !displayName.isEmpty {
                let credo = inCredo.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let urlString = "\(self._baseURIString)/index.php?operation=\(UserOperation.updateUser.rawValue)&displayName=\(displayName)&credo=\(credo)"
                guard let url = URL(string: urlString) else { return }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
                
                self._session.dataTask(with: request) { _, inResponse, inError in
                    DispatchQueue.main.async {
                        if let error = inError {
                            self.lastError = PKD_Errors.communicationError(error)
                            inCompletion(.failure(PKD_Errors.communicationError(error)))
                        } else if let response = inResponse as? HTTPURLResponse,
                                  200 == response.statusCode {
                            self.originalDisplayName = displayName
                            self.originalCredo = credo
                            inCompletion(.success)
                        } else {
                            self.lastError = PKD_Errors.communicationError(nil)
                            inCompletion(.failure(PKD_Errors.communicationError(nil)))
                        }
                    }
                }.resume()
            } else {
                DispatchQueue.main.async {
                    self.lastError = PKD_Errors.badInputParameters
                    inCompletion(.failure(PKD_Errors.badInputParameters))
                }
            }
        } else {
            DispatchQueue.main.async {
                self.lastError = PKD_Errors.notLoggedIn
                inCompletion(.failure(PKD_Errors.notLoggedIn))
            }
        }
    }
    
    /* ###################################################################### */
    /**
     Removes the user record.
     
     > NOTE: The user needs to be logged in.
     
     > NOTE: This does not remove the PassKey! The user needs to do that manually.
     
     - parameter inCompletion: This is an optional tail completion callback, with a single LoginResponse argument. Always called on the main thread.
     */
    func delete(completion inCompletion: ServerResponseCallback? = nil) {
        self.lastOperation = .deleteUser
        
        DispatchQueue.main.async { self.lastError = .none }
        
        if self.isLoggedIn,
           let bearerToken = self._bearerToken,
           !bearerToken.isEmpty {
            let urlString = "\(self._baseURIString)/index.php?operation=\(UserOperation.deleteUser.rawValue)"
            guard let url = URL(string: urlString) else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
            
            self._session.dataTask(with: request) { _, inResponse, inError in
                DispatchQueue.main.async {
                    if let error = inError {
                        self.lastError = PKD_Errors.communicationError(error)
                        inCompletion?(.failure(PKD_Errors.communicationError(error)))
                    } else if let response = inResponse as? HTTPURLResponse,
                              200 == response.statusCode {
                        self.logout(isLocalOnly: true) { inResult in
                            DispatchQueue.main.async {
                                if case let .failure(error) = inResult {
                                    self.lastError = PKD_Errors.communicationError(error)
                                    inCompletion?(.failure(PKD_Errors.communicationError(error)))
                                } else {
                                    self._clearUserInfo()
                                    inCompletion?(.success)
                                }
                            }
                        }
                    } else {
                        self.lastError = PKD_Errors.communicationError(nil)
                        inCompletion?(.failure(PKD_Errors.communicationError(nil)))
                    }
                }
            }.resume()
        } else {
            DispatchQueue.main.async {
                self.lastError = PKD_Errors.notLoggedIn
                inCompletion?(.failure(PKD_Errors.notLoggedIn))
            }
        }
    }
}
