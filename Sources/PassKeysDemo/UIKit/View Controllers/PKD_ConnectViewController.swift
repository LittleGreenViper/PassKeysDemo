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

import UIKit
import AuthenticationServices

/* ###################################################################################################################################### */
// MARK: - Passkeys Interaction View Controller -
/* ###################################################################################################################################### */
/**
 This is the single view controller for the UIKit version of the PassKeys demo.
 
 If the user has not registerd a passkey, they are presented with a register button.
 */
class PKD_ConnectViewController: UIViewController {
    /* ################################################################################################################################## */
    // MARK: Used For Working With User Data
    /* ################################################################################################################################## */
    /**
     */
    private struct _UserDataStruct: Decodable {
        /* ################################################################## */
        /**
         */
        let displayName: String

        /* ################################################################## */
        /**
         */
        let credo: String
        
        /* ################################################################## */
        /**
         */
        let bearerToken: String
    }
    
    /* ################################################################################################################################## */
    // MARK: Used For Fetching Registration Data
    /* ################################################################################################################################## */
    /**
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
                 This is a Base64-encoded ID for the relying party.
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
                 This is the user's public display name (does not need to be unique).
                 */
                let displayName: String
            }

            /* ############################################################## */
            /**
             This has a base64URL-encoded challenge string.
             */
            let challenge: String

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
        }
        
        /* ################################################################## */
        /**
         The public key, associated with this credential.
         */
        let publicKey: PublicKeyStruct
        
        /* ################################################################## */
        /**
         The display name associated with the user.
         */
        let displayName: String
        
        /* ################################################################## */
        /**
         The credo associated with the user (will aways be empty, at first).
         */
        let credo: String
        
        /* ################################################################## */
        /**
         The login token.
         */
        let bearerToken: String
    }

    /* ###################################################################### */
    /**
     The error returned, if the credential is not in the server store.
     */
    static private let _errorResponseString = "User not found"
    
    /* ###################################################################### */
    /**
     The identifier for the relying party.
     */
    static private let _relyingParty = Bundle.main.defaultRelyingPartyString
    
    /* ###################################################################### */
    /**
     The main URI string for our transactions.
     */
    static private let _baseURIString = Bundle.main.defaultBaseURIString
    
    /* ###################################################################### */
    /**
     The User ID string.
     */
    static private let _userIDString = Bundle.main.defaultUserIDString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    
    /* ###################################################################### */
    /**
     The user name string.
     */
    static private let _userNameString = Bundle.main.defaultUserNameString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    
    /* ###################################################################### */
    /**
     This is set to true, if we are registering a new user, before logging in.
     */
    private var _loginAfter = false
    
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
     */
    private var _originalDisplayName: String = ""

    /* ###################################################################### */
    /**
     */
    private var _originalCredo: String = ""

    /* ###################################################################### */
    /**
     */
    private weak var _displayNameTextField: UITextField?

    /* ###################################################################### */
    /**
     */
    private weak var _credoTextField: UITextField?

    /* ###################################################################### */
    /**
     */
    private weak var _updateButton: UIButton?
}

/* ###################################################################################################################################### */
// MARK: Computed Properties
/* ###################################################################################################################################### */
extension PKD_ConnectViewController {
    /* ###################################################################### */
    /**
     This contains a display name.
     */
    private var _displayName: String? { self._displayNameTextField?.text }

    /* ###################################################################### */
    /**
     This contains a credo.
     */
    private var _credo: String? { self._credoTextField?.text }

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
     True, if we are currently logged in.
     */
    private var _isLoggedIn: Bool { nil != self._cachedSession }
}

/* ###################################################################################################################################### */
// MARK: Base Class Overrides
/* ###################################################################################################################################### */
extension PKD_ConnectViewController {
    /* ###################################################################### */
    /**
     Called when the view hierarchy has been created and initialized.
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        self._setUpUI()
    }
}

/* ###################################################################################################################################### */
// MARK: Callbacks
/* ###################################################################################################################################### */
extension PKD_ConnectViewController {
    /* ###################################################################### */
    /**
     Called whenever the text in one of our edit fields changes.
     
     We just use this to manage the enablement of the update button.
     */
    @objc func textFieldChanged() {
        _calculateUpdateButtonEnabledState()
    }

    /* ###################################################################### */
    /**
     Called when the "Logout" button is hit.
     */
    @objc func logout() {
        self._bearerToken = nil
        self._credentialID = nil
        self._cachedSession = nil
        self._setUpUI()
    }
    
    /* ###################################################################### */
    /**
     This is called when the login or update button is hit.
     
     - parameter inButton: This is the button, if called from pressing the update button, or login button. Can be omitted.
     */
    @objc func accessServerWithPasskey(_ inButton: UIButton! = nil) {
        /* ###################################################################### */
        /**
         This fetches the challenge, for a logged-in access.
         
         - parameter inCompletion: A tail completion proc. It will have a single argument, with the user information (if successful).
         */
        func _fetchAccessChallenge(completion inCompletion: @escaping (Result<[String: Any], Error>) -> Void) {
            var urlString = "\(Self._baseURIString)/modify_challenge.php?userId=\(Self._userIDString)"
            
            if let bearerToken = self._bearerToken,
               !bearerToken.isEmpty {
                urlString += "&token=\(bearerToken)"
                
                if self._isLoggedIn,
                   inButton == self._updateButton {
                    let displayName = self._displayNameTextField?.text?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self._originalDisplayName
                    let credo = self._credoTextField?.text?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self._originalCredo
                    urlString += "&displayName=\(displayName)&credo=\(credo)&update"
                }
            }
            
            guard let url = URL(string: urlString) else { return }
            let task = self._session.dataTask(with: url) { inData, inResponse, inError in
                if let error = inError {
                    inCompletion(.failure(error))
                    return
                }
                
                if let response = inResponse as? HTTPURLResponse,
                   404 == response.statusCode,
                   let data = inData,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorString = json["error"] as? String,
                   Self._errorResponseString == errorString {
                    inCompletion(.failure(NSError(domain: "user", code: 2)))
                }
                
                guard let data = inData,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      nil != (json["publicKey"] as? [String: Any]),
                      nil != (json["bearerToken"] as? String)
                else {
                    inCompletion(.failure(NSError(domain: "json", code: 1)))
                    return
                }
                
                print("Data: \(json)")
                inCompletion(.success(json))
            }
            task.resume()
        }
        
        /* ################################################################ */
        /**
         Called to continue connections, after verifying a prior login.
         
         - parameter inBearerToken: The logged-in bearer token.
         */
        func _loggedInCallback(bearerToken inBearerToken: String, credentialId inCredentialId: String) {
            self._bearerToken = inBearerToken
            self._postResponse(to: "\(Self._baseURIString)/modify_response.php", payload: ["credentialId": inCredentialId])
        }
        
        /* ################################################################ */
        /**
         Called to tell the user they need to register, first.
         */
        func _alertAndRegister() {
            /* ############################################################ */
            /**
             This registers a new account and passkey.
             */
            func _registerPasskey() {
                /* ######################################################## */
                /**
                 This fetches the registration options, for creating a new user on the server.
                 
                 - parameter inURLString: The string to use as a URI for the registration.
                 - parameter inCompletion: A tail completion proc. It will have a single argument, with the new user information.
                 */
                func _fetchRegistrationOptions(from inURLString: String, completion inCompletion: @escaping (_PublicKeyCredentialCreationOptionsStruct?) -> Void) {
                    guard let url = URL(string: inURLString)
                    else {
                        inCompletion(nil)
                        return
                    }
                    
                    let task = self._session.dataTask(with: url) { inData, _, error in
                        guard let data = inData else {
                            print("Failed to fetch options: \(error?.localizedDescription ?? "Unknown error")")
                            inCompletion(nil)
                            return
                        }
                        
                        do {
                            let decoder = JSONDecoder()
                            let options = try decoder.decode(_PublicKeyCredentialCreationOptionsStruct.self, from: data)
                            inCompletion(options)
                        } catch {
                            print("JSON decoding error: \(error)")
                            inCompletion(nil)
                        }
                    }
                    
                    task.resume()
                }
              
                self._loginAfter = false

                _fetchRegistrationOptions(from: "\(Self._baseURIString)/register_challenge.php?userId=\(Self._userIDString)&displayName=\(Self._userNameString)") { InResponse in
                    guard let publicKey = InResponse?.publicKey,
                          let challengeData = publicKey.challenge.base64urlDecodedData,
                          let userIDData = publicKey.user.id.base64urlDecodedData
                    else {
                        print("Invalid Base64URL in server response")
                        return
                    }

                    let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: publicKey.rp.id)

                    let request = provider.createCredentialRegistrationRequest(
                        challenge: challengeData,
                        name: publicKey.user.displayName,
                        userID: userIDData
                    )

                    let controller = ASAuthorizationController(authorizationRequests: [request])
                    controller.delegate = self
                    controller.presentationContextProvider = self
                    controller.performRequests()
                }
            }

            DispatchQueue.main.async {
                if let presentedBy = PKD_SceneDelegate.currentWindow?.rootViewController {
                    let style: UIAlertController.Style = .alert
                    let alertController = UIAlertController(title: "Must Register", message: "Since you have not set up a passkey yet, you must register a new account, before logging in.", preferredStyle: style)

                    let okAction = UIAlertAction(title: "OK", style: .cancel) { _ in
                        self._loginAfter = true
                        _registerPasskey()
                    }
                    
                    alertController.addAction(okAction)
                    
                    presentedBy.present(alertController, animated: true, completion: nil)
                }
            }
        }
            
        _fetchAccessChallenge() { inResult in
            self._loginAfter = false
            switch inResult {
            case .success(let challengeDict):
                if let publicKey = (challengeDict["publicKey"] as? [String: Any]),
                   let challengeData = (publicKey["challenge"] as? String)?.base64urlDecodedData {
                    // See if we have already logged in, and we're just making a subsequent call.
                    if let token = challengeDict["bearerToken"] as? String,
                       !token.isEmpty,
                       let credentialID = self._credentialID,
                       !credentialID.isEmpty {
                        _loggedInCallback(bearerToken: token, credentialId: credentialID)
                    } else {    // In this case, we have not previously signed in, so we need to sign in again, by creating a new record to be vetted by the server, and getting user approval.
                        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: Self._relyingParty)
                        let request = provider.createCredentialAssertionRequest(challenge: challengeData)
                        
                        let controller = ASAuthorizationController(authorizationRequests: [request])
                        controller.delegate = self
                        controller.presentationContextProvider = self
                        controller.performRequests()
                    }
                }   else {
                    print("No Public Key or Challenge.")
                }
            case .failure(let error):
                self._credentialID = nil
                self._bearerToken = nil
                // See if it's a "User not found" error, in which case, we will be creating a new user record.
                if "user" == (error as NSError).domain {
                    _alertAndRegister()
                } else {
                    print("Failed to fetch challenge: \(error)")
                }
            }
        }
    }
}

/* ###################################################################################################################################### */
// MARK: Private Instance Methods
/* ###################################################################################################################################### */
extension PKD_ConnectViewController {
    /* ###################################################################### */
    /**
     Sets up the screen to reflwct the current app state.
     */
    private func _setUpUI() {
        guard let view = self.view else { return }
        
        view.subviews.forEach { $0.removeFromSuperview() }
        
        if self._isLoggedIn {
            let displayNameEditField = UITextField()
            displayNameEditField.text = ""
            displayNameEditField.placeholder = "Enter A Display Name"
            displayNameEditField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
            displayNameEditField.clearButtonMode = .whileEditing
            displayNameEditField.borderStyle = .roundedRect
            self._displayNameTextField = displayNameEditField
            
            let credoEditField = UITextField()
            credoEditField.text = ""
            credoEditField.placeholder = "Enter A Credo"
            credoEditField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
            credoEditField.clearButtonMode = .always
            credoEditField.borderStyle = .roundedRect
            self._credoTextField = credoEditField

            let updateButton = UIButton(type: .system)
            updateButton.setTitle("Update", for: .normal)
            updateButton.addTarget(self, action: #selector(accessServerWithPasskey), for: .touchUpInside)
            self._updateButton = updateButton

            let logoutButton = UIButton(type: .system)
            logoutButton.setTitle("Logout", for: .normal)
            logoutButton.addTarget(self, action: #selector(logout), for: .touchUpInside)

            let buttonStack = UIStackView(arrangedSubviews: [logoutButton, updateButton])
            buttonStack.axis = .horizontal
            buttonStack.spacing = 20

            let stack = UIStackView(arrangedSubviews: [displayNameEditField, credoEditField, buttonStack])
            stack.axis = .vertical
            stack.spacing = 20
            stack.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(stack)
            
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
        } else {
            let loginButton = UIButton(type: .system)
            loginButton.setTitle("Login", for: .normal)
            loginButton.addTarget(self, action: #selector(accessServerWithPasskey), for: .touchUpInside)
            
            let stack = UIStackView(arrangedSubviews: [loginButton])
            stack.axis = .vertical
            stack.spacing = 20
            stack.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(stack)
            
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
        }
    }

    /* ###################################################################### */
    /**
     This looks for a dirty value, and enables the update button, if we have had a change.
     
     - returns: the current enablement state.
     */
    @discardableResult
    private func _calculateUpdateButtonEnabledState() -> Bool {
        let isEnabled = self._isLoggedIn && !(self._displayName?.isEmpty ?? true) && (self._displayName != self._originalDisplayName) || (self._credo != self._originalCredo)
        DispatchQueue.main.async { self._updateButton?.isEnabled = isEnabled }
        return isEnabled
    }
    
    /* ###################################################################### */
    /**
     Called to access or modify the user data, via a POST transaction.
     
     - parameter inURLString: The URL String we are calling.
     - parameter inPayload: The POST arguments.
     */
    private func _postResponse(to inURLString: String, payload inPayload: [String: Any]) {
        print("Connecting to URL: \(inURLString)")
        guard let url = URL(string: inURLString),
              let responseData = try? JSONSerialization.data(withJSONObject: inPayload),
              !responseData.isEmpty
        else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = responseData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(responseData.count)", forHTTPHeaderField: "Content-Length")
        let task = self._session.dataTask(with: request) { inData, inResponse, inError in
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
                    if self._loginAfter {
                        self.accessServerWithPasskey()
                    } else {
                        let decoder = JSONDecoder()
                        if let userData = try? decoder.decode(_UserDataStruct.self, from: data) {
                            displayName = userData.displayName
                            credo = userData.credo
                            self._originalDisplayName = displayName
                            self._originalCredo = credo
                        }
                    }
                    DispatchQueue.main.async {
                        self._setUpUI()
                        self._displayNameTextField?.text = displayName
                        self._credoTextField?.text = credo
                        self._calculateUpdateButtonEnabledState()
                    }
                } else {
                    self._credentialID = nil
                    DispatchQueue.main.async {
                        self._setUpUI()
                        let style: UIAlertController.Style = .alert
                        let alertController = UIAlertController(title: "Error Logging In", message: "Unable to log in.", preferredStyle: style)
                        
                        let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                        
                        alertController.addAction(okAction)
                        
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
            }
        }
        task.resume()
    }
}

/* ###################################################################################################################################### */
// MARK: ASAuthorizationControllerDelegate Conformance
/* ###################################################################################################################################### */
extension PKD_ConnectViewController: ASAuthorizationControllerDelegate {
    /* ###################################################################### */
    /**
     */
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            let payload: [String: String] = [
                "clientDataJSON": credential.rawClientDataJSON.base64EncodedString(),
                "attestationObject": credential.rawAttestationObject?.base64EncodedString() ?? ""
            ]
            self._credentialID = credential.credentialID.base64EncodedString()
            self._postResponse(to: "\(Self._baseURIString)/register_response.php", payload: payload)
        } else if let assertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            struct AssertionJSON: Codable {
                var type: String = ""
                var challenge: String = ""
                var origin: String = ""
            }
            
            let payload: [String: String] = [
                "clientDataJSON": assertion.rawClientDataJSON.base64EncodedString(),
                "authenticatorData": assertion.rawAuthenticatorData.base64EncodedString(),
                "signature": assertion.signature.base64EncodedString(),
                "credentialId": assertion.credentialID.base64EncodedString()
            ]
            self._credentialID = assertion.credentialID.base64EncodedString()
            self._postResponse(to: "\(Self._baseURIString)/modify_response.php", payload: payload)
        }
    }

    /* ###################################################################### */
    /**
     */
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError inError: Error) {
        print("Authorization error: \(inError)")
    }
}

/* ###################################################################################################################################### */
// MARK: ASAuthorizationControllerPresentationContextProviding Conformance
/* ###################################################################################################################################### */
extension PKD_ConnectViewController: ASAuthorizationControllerPresentationContextProviding {
    /* ###################################################################### */
    /**
     */
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { self.view?.window ?? UIWindow() }
}
