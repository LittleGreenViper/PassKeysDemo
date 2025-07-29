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
        let userId: String

        /* ################################################################## */
        /**
         */
        let displayName: String

        /* ################################################################## */
        /**
         */
        let credo: String
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
     This contains a display name (cannot be empty), if we are logged in. Nil, otherwise.
     */
    private var _displayName: String?

    /* ###################################################################### */
    /**
     This contains a credo (may be empty), if we are logged in. Nil, otherwise.
     */
    private var _credo: String?
    
    /* ###################################################################### */
    /**
     We maintain a consistent session, because the challenges are set to work across a session.
     */
    private let _session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        return URLSession(configuration: config)
    }()
}

/* ###################################################################################################################################### */
// MARK: private Instance Methods
/* ###################################################################################################################################### */
extension PKD_ConnectViewController {
    /* ###################################################################### */
    /**
     Sets up the screen to reflwct the current app state.
     */
    private func _setUpUI() {
        guard let view = self.view else { return }
        
        view.subviews.forEach { $0.removeFromSuperview() }
        
        if let displayName = self._displayName {
            let displayNameEditField = UITextField()
            displayNameEditField.text = displayName

            let logoutButton = UIButton(type: .system)
            logoutButton.setTitle("Logout", for: .normal)
            logoutButton.addTarget(self, action: #selector(logout), for: .touchUpInside)

            let buttonStack = UIStackView(arrangedSubviews: [logoutButton])
            buttonStack.axis = .horizontal
            buttonStack.spacing = 20

            let stack = UIStackView(arrangedSubviews: [displayNameEditField, buttonStack])
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
     Called when the "Logout" button is hit.
     */
    @objc func logout() {
        self._displayName = nil
        self._credo = nil
        self._setUpUI()
    }
    
    /* ###################################################################### */
    /**
     Called when the "Login" button is hit.
     */
    @objc func accessServerWithPasskey() {
        /* ###################################################################### */
        /**
         This fetches the challenge, for a logged-in access.
         
         - parameter inCompletion: A tail completion proc. It will have a single argument, with the user information (if successful).
         */
        func _fetchAccessChallenge(completion inCompletion: @escaping (Result<[String: Any], Error>) -> Void) {
            guard let url = URL(string: "\(Self._baseURIString)/modify_challenge.php?user_id=\(Self._userIDString)") else { return }
            let task = _session.dataTask(with: url) { inData, inResponse, inError in
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
                      nil != (json["args"] as? [String: Any])?["publicKey"] as? [String: Any]
                else {
                    inCompletion(.failure(NSError(domain: "json", code: 1)))
                    return
                }
                
                inCompletion(.success(json))
            }
            task.resume()
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
              
                _fetchRegistrationOptions(from: "\(Self._baseURIString)/register_challenge.php?user_id=\(Self._userIDString)&display_name=\(Self._userNameString)") { InResponse in
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
                guard let publicKey = (challengeDict["args"] as? [String: Any])?["publicKey"] as? [String: Any],
                      let challengeData = (publicKey["challenge"] as? String)?.base64urlDecodedData
                else {
                    print("No Public Key or Challenge.")
                    return
                }
                
                if let apiKey = challengeDict["apiKey"] as? String,
                   !apiKey.isEmpty {
                    print("We have a previous key: \(apiKey)")
                } else {
                    let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: Self._relyingParty)
                    let request = provider.createCredentialAssertionRequest(challenge: challengeData)
                    
                    let controller = ASAuthorizationController(authorizationRequests: [request])
                    controller.delegate = self
                    controller.presentationContextProvider = self
                    controller.performRequests()
                }
                
            case .failure(let error):
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
// MARK:
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

            postResponse(to: "\(Self._baseURIString)/register_response.php", payload: payload)
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

            postResponse(to: "\(Self._baseURIString)/modify_response.php", payload: payload)
        }
    }

    /* ###################################################################### */
    /**
     */
    func postResponse(to urlString: String, payload: [String: String]) {
        guard let url = URL(string: urlString),
              let responseData = try? JSONSerialization.data(withJSONObject: payload),
              !responseData.isEmpty
        else { return }

        self._displayName = nil
        self._credo = nil
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = responseData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(responseData.count)", forHTTPHeaderField: "Content-Length")
        let task = _session.dataTask(with: request) { inData, inResponse, inError in
            guard let response = inResponse as? HTTPURLResponse else { return }
            print("Status Code: \(response.statusCode)")
            if 200 == response.statusCode,
               let data = inData {
                if self._loginAfter {
                    self.accessServerWithPasskey()
                } else {
                    let decoder = JSONDecoder()
                    if let userData = try? decoder.decode(_UserDataStruct.self, from: data) {
                        self._displayName = userData.displayName
                        self._credo = userData.credo
                    }
                }
            }
            DispatchQueue.main.async { self._setUpUI() }
        }
        task.resume()
    }

    /* ###################################################################### */
    /**
     */
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError inError: Error) {
        print("Authorization error: \(inError)")
    }
}

/* ###################################################################################################################################### */
// MARK:
/* ###################################################################################################################################### */
extension PKD_ConnectViewController: ASAuthorizationControllerPresentationContextProviding {
    /* ###################################################################### */
    /**
     */
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { self.view?.window ?? UIWindow() }
}
