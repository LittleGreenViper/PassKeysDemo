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
import Combine

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
     This is the instance of the PKD API Handler that we use to communicate with the server.
     */
    private var _pkdInstance: PKD_Handler?
    
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
     The text field that allows the user to edit their display name.
     */
    private weak var _displayNameTextField: UITextField?

    /* ###################################################################### */
    /**
     The text field that allows the user to edit their credo text.
     */
    private weak var _credoTextField: UITextField?

    /* ###################################################################### */
    /**
     The button for updating (so it can be enabled or disabled).
     */
    private weak var _updateButton: UIButton?

    /* ###################################################################### */
    /**
     */
    private var _bag = Set<AnyCancellable>()
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
}

/* ###################################################################################################################################### */
// MARK: Base Class Overrides
/* ###################################################################################################################################### */
extension PKD_ConnectViewController {
    /* ###################################################################### */
    /**
     */
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let window = self.view.window else { return }
        
        if self._pkdInstance == nil {
            let handler = PKD_Handler(relyingParty: Self._relyingParty,
                                      baseURIString: Self._baseURIString,
                                      userNameString: Self._userNameString,
                                      presentationAnchor: window)
            self._pkdInstance = handler
            
            handler.$isLoggedIn
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?._setUpUI() }
                .store(in: &self._bag)
            
            handler.$lastError
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?._handleError() }
                .store(in: &self._bag)
        }
        
        self._setUpUI()
    }
}

/* ###################################################################################################################################### */
// MARK: Callbacks
/* ###################################################################################################################################### */
extension PKD_ConnectViewController {
    /* ###################################################################### */
    /**
     */
    @objc func register() {
        self._pkdInstance?.create(displayName: "NEW USER", credo: "") { inData, inResponse  in
            if let responseData = inData {
                print("Display Name: \(responseData.displayName)")
                print("Credo: \(responseData.credo)")
                DispatchQueue.main.async { self._setUpUI() }
            }
        }
    }
    
    /* ###################################################################### */
    /**
     */
    @objc func login() {
        self._pkdInstance?.login { [weak self] inResult in
            switch inResult {
            case .success:
                break
                
            case .failure(let inError):
                print("Error: \(inError.localizedDescription)")
                break
            }
            DispatchQueue.main.async { self?._setUpUI() }
        }
    }
    
    /* ###################################################################### */
    /**
     */
    @objc func deleteUser() {
    }
    
    /* ###################################################################### */
    /**
     Called whenever the text in one of our edit fields changes.
     
     We just use this to manage the enablement of the update button.
     */
    @objc func textFieldChanged() {
        self._calculateUpdateButtonEnabledState()
    }

    /* ###################################################################### */
    /**
     Called when the "Update" button is hit.
     */
    @objc func update() {
        if let displayName = self._displayName,
           !displayName.isEmpty,
           let credo = self._credo {
            self._pkdInstance?.update(displayName: displayName, credo: credo) { _, _ in
                DispatchQueue.main.async { self._setUpUI() }
            }
        }
    }

    /* ###################################################################### */
    /**
     Called when the "Logout" button is hit.
     */
    @objc func logout() {
        self._pkdInstance?.logout { inResult in
            DispatchQueue.main.async { self._setUpUI() }
        }
    }
}

/* ###################################################################################################################################### */
// MARK: Private Instance Methods
/* ###################################################################################################################################### */
extension PKD_ConnectViewController {
    /* ###################################################################### */
    /**
     */
    private func _handleError() {
        if let error = self._pkdInstance?.lastError {
            let alertController = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alertController, animated: true)
        }
    }
    
    /* ###################################################################### */
    /**
     Sets up the screen to reflect the current app state.
     */
    private func _setUpUI() {
        guard let view = self.view else { return }
        
        view.subviews.forEach { $0.removeFromSuperview() }
        
        if !(self._pkdInstance?.isRegistered ?? false) {
            let registerButton = UIButton(type: .system)
            registerButton.setTitle("Register", for: .normal)
            registerButton.addTarget(self, action: #selector(register), for: .touchUpInside)
            
            let stack = UIStackView(arrangedSubviews: [registerButton])
            stack.axis = .vertical
            stack.spacing = 20
            stack.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(stack)
            
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        } else if !(self._pkdInstance?.isLoggedIn ?? false) {
            let loginButton = UIButton(type: .system)
            loginButton.setTitle("Login", for: .normal)
            loginButton.addTarget(self, action: #selector(login), for: .touchUpInside)
            
            let stack = UIStackView(arrangedSubviews: [loginButton])
            stack.axis = .vertical
            stack.spacing = 20
            stack.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(stack)
            
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        } else if self._pkdInstance?.isLoggedIn ?? false {
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
            updateButton.addTarget(self, action: #selector(update), for: .touchUpInside)
            self._updateButton = updateButton

            let logoutButton = UIButton(type: .system)
            logoutButton.setTitle("Logout", for: .normal)
            logoutButton.addTarget(self, action: #selector(logout), for: .touchUpInside)

            let deleteButton = UIButton(type: .system)
            deleteButton.setTitle("Delete", for: .normal)
            deleteButton.addTarget(self, action: #selector(deleteUser), for: .touchUpInside)

            let buttonStack = UIStackView(arrangedSubviews: [deleteButton, logoutButton, updateButton])
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
            
            self._pkdInstance?.read { [weak self] inResponseData, inResponseResult in
                if let self = self {
                    DispatchQueue.main.async {
                        if let responseData = inResponseData {
                            self._displayNameTextField?.text = responseData.0
                            self._credoTextField?.text = responseData.1
                        } else {
                            self._displayNameTextField?.text = nil
                            self._credoTextField?.text = nil
                        }
                        self._calculateUpdateButtonEnabledState()
                    }
                }
            }
        }
    }

    /* ###################################################################### */
    /**
     This looks for a dirty value, and enables the update button, if we have had a change.
     
     - returns: the current enablement state.
     */
    @discardableResult
    private func _calculateUpdateButtonEnabledState() -> Bool {
        let hasTextChanged = (self._displayName != self._pkdInstance?.originalDisplayName) || (self._credo != self._pkdInstance?.originalCredo)
        let displayName = self._displayName ?? ""
        let isLoggedIn = self._pkdInstance?.isLoggedIn ?? false
        let isEnabled = isLoggedIn && !displayName.isEmpty && hasTextChanged
        DispatchQueue.main.async { self._updateButton?.isEnabled = isEnabled }
        return isEnabled
    }
}
