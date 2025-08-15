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
import Combine  // For the subscriptions in viewDidAppear

/* ###################################################################################################################################### */
// MARK: - Passkeys Interaction View Controller -
/* ###################################################################################################################################### */
/**
 This is the single view controller for the UIKit version of the PassKeys demo.
 
 If the user has not logge in, they are presented with a register button, and a display name text field, along with a login button.
 
 If they are logged in, they are presented with two text fields, and three buttons (Delete, Logout, and Update).
 */
class PKD_ConnectViewController: UIViewController {
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
    }
    
    /* ###################################################################### */
    /**
     The font used for the buttons in the screen.
     */
    static private let _buttonFont = UIFont.systemFont(ofSize: 20, weight: .bold)
    
    /* ###################################################################### */
    /**
     This is the instance of the PKD API Handler that we use to communicate with the server.
     */
    private var _pkdInstance: PKD_Handler?

    /* ###################################################################### */
    /**
     This is used for the login subscription.
     */
    private var _loginBag = Set<AnyCancellable>()

    /* ###################################################################### */
    /**
     This is used for the error subscription.
     */
    private var _errorBag = Set<AnyCancellable>()

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
     The button for registering (so it can be enabled or disabled).
     */
    private weak var _registerButton: UIButton?

    /* ###################################################################### */
    /**
     The button for updating (so it can be enabled or disabled).
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
    private var _displayName: String? { self._displayNameTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines) }

    /* ###################################################################### */
    /**
     This contains a credo.
     */
    private var _credo: String? { self._credoTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines) }
}

/* ###################################################################################################################################### */
// MARK: Base Class Overrides
/* ###################################################################################################################################### */
extension PKD_ConnectViewController {
    /* ###################################################################### */
    /**
     Called after the view appears. We use this to establish the handler and the subscriptions. We also initially set up the screen.
     */
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let window = self.view.window else { return }
        
        if nil == self._pkdInstance {
            self._pkdInstance = PKD_Handler(relyingParty: Bundle.main.defaultRelyingPartyString, baseURIString: Bundle.main.defaultBaseURIString, presentationAnchor: window)

            // Combine Subscriptions
            
            // This listens for changes to the login state.
            self._pkdInstance?.$isLoggedIn
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?._setUpUI() }
                .store(in: &self._loginBag)
            
            // This reacts to errors.
            self._pkdInstance?.$lastError
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?._handleError() }
                .store(in: &self._errorBag)
        }
        
        self._setUpUI()
    }
}

/* ###################################################################################################################################### */
// MARK: Instance Methods
/* ###################################################################################################################################### */
private extension PKD_ConnectViewController {
    /* ###################################################################### */
    /**
     Called if the handler error property changes.
     */
    func _handleError() {
        if let error = self._pkdInstance?.lastError {
            if case .none = error {
                return
            }
            let title = "SLUG-ERROR-ALERT-HEADER".localizedVariant
            var message = ""
            
            switch self._pkdInstance?.lastOperation ?? .none {
            case .login:
                message = "SLUG-ERROR-0"
                
            case .logout:
                message = "SLUG-ERROR-1"
                
            case .createUser:
                message = "SLUG-ERROR-2"
        
            case .readUser:
                message = "SLUG-ERROR-3"
                
            case .updateUser:
                message = "SLUG-ERROR-4"
                
            case .deleteUser:
                message = "SLUG-ERROR-5"
                
            case .none:
                message = "SLUG-ERROR-6"
            }
            
            // We need to create the error string locally, because it looks like Combine screws with the casting of the enum, and we get a generic localizedDescription.
            var localizedErrorDescripion = "SLUG-ERROR-PKDH-6".localizedVariant
            
            switch error {
            case .none:
                localizedErrorDescripion = ""
                break
                
            case .noUserID:
                localizedErrorDescripion = "SLUG-ERROR-PKDH-0".localizedVariant
                break
                
            case .alreadyRegistered:
                localizedErrorDescripion = "SLUG-ERROR-PKDH-1".localizedVariant
                break
                
            case .notLoggedIn:
                localizedErrorDescripion = "SLUG-ERROR-PKDH-2".localizedVariant
                break
                
            case .alreadyLoggedIn:
                localizedErrorDescripion = "SLUG-ERROR-PKDH-3".localizedVariant
                break
                
            case .communicationError(let inError):
                localizedErrorDescripion = "SLUG-ERROR-PKDH-4".localizedVariant
                
                if let err = inError,
                   !err.localizedDescription.isEmpty {
                    localizedErrorDescripion += ": " + err.localizedDescription
                }
                break
                
            case .badInputParameters:
                localizedErrorDescripion = "SLUG-ERROR-PKDH-5".localizedVariant
                break
            }
            
            message = message.localizedVariant + (!localizedErrorDescripion.isEmpty ? "\n\(localizedErrorDescripion)" : "")
            
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "SLUG-OK-BUTTON".localizedVariant, style: .default))
            self.present(alertController, animated: true)
        }
    }
    
    /* ###################################################################### */
    /**
     Sets up the screen to reflect the current app state.
     */
    func _setUpUI() {
        guard let view = self.view else { return }
        
        view.subviews.forEach { $0.removeFromSuperview() }
        
        // If we are not logged in, we show a login button, and a text field and a register button.
        if !(self._pkdInstance?.isLoggedIn ?? false) {
            let displayNameEditField = UITextField()
            displayNameEditField.text = ""
            displayNameEditField.placeholder = "SLUG-DISPLAY-NAME-PLACEHOLDER".localizedVariant
            displayNameEditField.addTarget(self, action: #selector(_textFieldChanged), for: .editingChanged)
            displayNameEditField.clearButtonMode = .whileEditing
            displayNameEditField.borderStyle = .roundedRect
            self._displayNameTextField = displayNameEditField
            
            let loginButton = UIButton(type: .system)
            var config = UIButton.Configuration.plain()
            config.attributedTitle = AttributedString("SLUG-LOGIN-BUTTON".localizedVariant, attributes: AttributeContainer([.font: Self._buttonFont]))
            loginButton.configuration = config
            loginButton.addTarget(self, action: #selector(_login), for: .touchUpInside)

            let registerButton = UIButton(type: .system)
            config = UIButton.Configuration.plain()
            config.attributedTitle = AttributedString("SLUG-REGISTER-BUTTON".localizedVariant, attributes: AttributeContainer([.font: Self._buttonFont]))
            registerButton.configuration = config
            registerButton.addTarget(self, action: #selector(_register), for: .touchUpInside)
            self._registerButton = registerButton
            
            let buttonStack = UIStackView(arrangedSubviews: [registerButton, loginButton])
            buttonStack.axis = .horizontal
            buttonStack.spacing = 20
            buttonStack.translatesAutoresizingMaskIntoConstraints = false
            
            let stack = UIStackView(arrangedSubviews: [displayNameEditField, buttonStack])
            stack.axis = .vertical
            stack.spacing = 20
            stack.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(stack)

            NSLayoutConstraint.activate([
                stack.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6),
                stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        // If we are logged in, we read the data from the server, and show it in two text boxes. There are three buttons, below the text boxes, and the update button is enabled, if there has been a change in the text boxes.
        } else if self._pkdInstance?.isLoggedIn ?? false {
            let displayNameEditField = UITextField()
            displayNameEditField.text = ""
            displayNameEditField.placeholder = "SLUG-DISPLAY-NAME-PLACEHOLDER".localizedVariant
            displayNameEditField.addTarget(self, action: #selector(_textFieldChanged), for: .editingChanged)
            displayNameEditField.clearButtonMode = .whileEditing
            displayNameEditField.borderStyle = .roundedRect
            self._displayNameTextField = displayNameEditField
            
            let credoEditField = UITextField()
            credoEditField.text = ""
            credoEditField.placeholder = "SLUG-CREDO-PLACEHOLDER".localizedVariant
            credoEditField.addTarget(self, action: #selector(_textFieldChanged), for: .editingChanged)
            credoEditField.clearButtonMode = .always
            credoEditField.borderStyle = .roundedRect
            self._credoTextField = credoEditField

            let updateButton = UIButton(type: .system)
            var config = UIButton.Configuration.plain()
            config.attributedTitle = AttributedString("SLUG-UPDATE-BUTTON".localizedVariant, attributes: AttributeContainer([.font: Self._buttonFont]))
            updateButton.configuration = config
            updateButton.addTarget(self, action: #selector(_update), for: .touchUpInside)
            self._updateButton = updateButton

            let logoutButton = UIButton(type: .system)
            config = UIButton.Configuration.plain()
            config.attributedTitle = AttributedString("SLUG-LOGOUT-BUTTON".localizedVariant, attributes: AttributeContainer([.font: Self._buttonFont]))
            logoutButton.configuration = config
            logoutButton.addTarget(self, action: #selector(_logout), for: .touchUpInside)

            let deleteButton = UIButton(type: .system)
            config = UIButton.Configuration.plain()
            config.baseForegroundColor = .systemRed
            config.attributedTitle = AttributedString("SLUG-DELETE-BUTTON".localizedVariant, attributes: AttributeContainer([.font: Self._buttonFont]))
            deleteButton.configuration = config
            deleteButton.addTarget(self, action: #selector(_deleteUser), for: .touchUpInside)

            let buttonStack = UIStackView(arrangedSubviews: [deleteButton, logoutButton, updateButton])
            buttonStack.axis = .horizontal
            buttonStack.spacing = 20

            let stack = UIStackView(arrangedSubviews: [displayNameEditField, credoEditField, buttonStack])
            stack.axis = .vertical
            stack.spacing = 20
            stack.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(stack)
            
            NSLayoutConstraint.activate([
                stack.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6),
                stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
            
            self._pkdInstance?.read { [weak self] inResponseData, inResponseResult in
                if let responseData = inResponseData {
                    self?._displayNameTextField?.text = responseData.0
                    self?._credoTextField?.text = responseData.1
                } else {
                    self?._displayNameTextField?.text = nil
                    self?._credoTextField?.text = nil
                }
                self?._calculateUpdateButtonEnabledState()
            }
        }
        
        self._calculateUpdateButtonEnabledState()
    }

    /* ###################################################################### */
    /**
     This looks for a dirty value, and enables the update button, if we have had a change.
     */
    func _calculateUpdateButtonEnabledState() {
        DispatchQueue.main.async {
            let hasTextChanged = (self._displayName != self._pkdInstance?.originalDisplayName) || (self._credo != self._pkdInstance?.originalCredo)
            let displayName = self._displayName ?? ""
            let isLoggedIn = self._pkdInstance?.isLoggedIn ?? false
            let isEnabled = isLoggedIn && !displayName.isEmpty && hasTextChanged
            self._updateButton?.isEnabled = isEnabled
            self._registerButton?.isEnabled = !displayName.isEmpty
        }
    }
}

/* ###################################################################################################################################### */
// MARK: Text Field Callback
/* ###################################################################################################################################### */
private extension PKD_ConnectViewController {
    /* ###################################################################### */
    /**
     Called whenever the text in one of our edit fields changes.
     
     We just use this to manage the enablement of the update button.
     
     - parameter inTextField: The text field that changed. We also look for more than 255 characters, and truncate, if so.
     */
    @objc func _textFieldChanged(_ inTextField: UITextField) {
        let oldText = inTextField.text ?? ""
        inTextField.text = oldText.count > 255 ? String(oldText[inTextField.text!.startIndex..<inTextField.text!.index(inTextField.text!.startIndex, offsetBy: 255)]) : oldText
        self._calculateUpdateButtonEnabledState()
    }
}

/* ###################################################################################################################################### */
// MARK: Button Callbacks
/* ###################################################################################################################################### */
private extension PKD_ConnectViewController {
    /* ###################################################################### */
    /**
     Called to begin the process of registration.
     
     Whatever is in the displayName field will be used as the PassKey name.
     */
    @objc func _register() {
        self._pkdInstance?.create(displayName: self._displayName) { [weak self] _ in self?._setUpUI() }
    }
    
    /* ###################################################################### */
    /**
     Logs in the saved user (stored in the keychain).
     */
    @objc func _login() {
        self._pkdInstance?.login { [weak self] _ in self?._setUpUI() }
    }
    
    /* ###################################################################### */
    /**
     This is called when the user selects the "Delete" button. They are given a confirmation prompt, before the operation is done.
     */
    @objc func _deleteUser() {
        let alertController = UIAlertController(title: "SLUG-DELETE-CONFIRM-HEADER".localizedVariant, message: String(format: "SLUG-DELETE-CONFIRM-MESSAGE-FORMAT".localizedVariant, "SLUG-DELETE-CONFIRM-OK-BUTTON".localizedVariant), preferredStyle: .alert)

        let deleteAction = UIAlertAction(title: "SLUG-DELETE-CONFIRM-OK-BUTTON".localizedVariant, style: UIAlertAction.Style.destructive) { [weak self] _ in self?._pkdInstance?.delete { _ in self?._setUpUI() } }
        
        alertController.addAction(deleteAction)
        
        let cancelAction = UIAlertAction(title: "SLUG-DELETE-CONFIRM-CANCEL-BUTTON".localizedVariant, style: UIAlertAction.Style.default, handler: nil)
        
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }

    /* ###################################################################### */
    /**
     Called when the "Update" button is hit.
     */
    @objc func _update() {
        if let displayName = self._displayName,
           !displayName.isEmpty,
           let credo = self._credo {
            self._pkdInstance?.update(displayName: displayName, credo: credo) { [weak self] _ in self?._setUpUI() }
        }
    }

    /* ###################################################################### */
    /**
     Called when the "Logout" button is hit.
     */
    @objc func _logout() {
        self._pkdInstance?.logout { [weak self] _ in self?._setUpUI() }
    }
}
