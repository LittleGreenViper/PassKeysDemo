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

import SwiftUI
import AuthenticationServices

/* ###################################################################################################################################### */
// MARK: - Main Screen View -
/* ###################################################################################################################################### */
/**
 This is the main display of the app.
 
 If we have not logged in, then a text field (PassKey title) is presented, and two buttons (Register and Login) are presented under it.
 
 These are the two PassKey operations. All the rest are only valid, once we have used a passkey to login (or create a new account, via the Register button).
 
 If we are logged in, then two text fields (display name and credo) are presented, with three buttons under (Delete, Logout, and Update).
 
 These do not involve the passkey.
 */
struct PKD_MainView: View {
    /* ###################################################################### */
    /**
     The font used for the buttons in the screen.
     */
    static private let _buttonFont = Font.system(size: 15, weight: .bold)
    
    /* ###################################################################### */
    /**
     This generates the error body message, based on the state of the ``PKD_Handler`` instance.
     
     - parameter inError: The error being displayed.
     - parameter inLastOperation: The last operation performed by the handler.
     - returns: A string, with the localized error message.
     */
    static private func _errorMessage(for inError: PKD_Handler.PKD_Errors, lastOp inLastOperation: PKD_Handler.UserOperation) -> String {
        // Map the last operation to a base slug
        let opSlug: String = {
            switch inLastOperation {
            case .login:
                return "SLUG-ERROR-0"
                
            case .logout:
                return "SLUG-ERROR-1"
                
            case .createUser:
                return "SLUG-ERROR-2"
                
            case .readUser:
                return "SLUG-ERROR-3"
                
            case .updateUser:
                return "SLUG-ERROR-4"
                
            case .deleteUser:
                return "SLUG-ERROR-5"
                
            case .none:
                return "SLUG-ERROR-6"
            }
        }().localizedVariant

        // Map the error to a localized description
        var detail = "SLUG-ERROR-PKDH-0".localizedVariant
        
        switch inError {
        case .none:
            detail = ""
            
        case .noAvailablePassKeys:
            detail = "SLUG-ERROR-PKDH-1".localizedVariant
            
        case .noUserID:
            detail = "SLUG-ERROR-PKDH-2".localizedVariant
            
        case .alreadyRegistered:
            detail = "SLUG-ERROR-PKDH-3".localizedVariant
            
        case .notLoggedIn:
            detail = "SLUG-ERROR-PKDH-4".localizedVariant
            
        case .alreadyLoggedIn:
            detail = "SLUG-ERROR-PKDH-5".localizedVariant
            
        case .communicationError(let inUnderlyingError):
            detail = "SLUG-ERROR-PKDH-6".localizedVariant
            
            if let err = inUnderlyingError,
               !err.localizedDescription.isEmpty {
                detail += ": " + err.localizedDescription
            }
            
        case .badInputParameters:
            detail = "SLUG-ERROR-PKDH-7".localizedVariant
            
        case .biometricsNotAvailable:
            detail = "SLUG-ERROR-PKDH-8".localizedVariant
        }
        
        return detail.isEmpty ? opSlug : "\(opSlug)\n\(detail)"
    }

    /* ###################################################################### */
    /**
     This is our observable ``PKD_Handler`` instance.
     */
    @StateObject private var _pkdInstance = PKD_Handler(relyingParty: Bundle.main.defaultRelyingPartyString,
                                                        baseURIString: Bundle.main.defaultBaseURIString,
                                                        presentationAnchor: UIApplication.shared
                                                                                            .connectedScenes
                                                                                            .compactMap { $0 as? UIWindowScene }
                                                                                            .flatMap { $0.windows }
                                                                                            .first { $0.isKeyWindow } ?? UIWindow()
    )

    /* ###################################################################### */
    /**
     We track the text in the display name text field, here.
     */
    @State private var _displayNameText = ""

    /* ###################################################################### */
    /**
     We track the text in the credo text field, here.
     */
    @State private var _credoText = ""
    
    /* ###################################################################### */
    /**
     This is set to true, when we hit the delete button, so that the confirmation alert is shown.
     */
    @State private var _showDeleteConfirm = false
    
    /* ###################################################################### */
    /**
     All the action happens in this View.
     
     If we are not logged in, we show a single text field, and below that, a register button, and a login button.

     If we are logged in, we read the data from the server, and show it in two text boxes.
     There are three buttons, below the text boxes, and the update button is enabled, if there has been a change in the text boxes.
     */
    var body: some View {
        GeometryReader { inProxy in
            let columnWidth = inProxy.size.width * 0.6  // 60% width.
            let spacing = CGFloat(30)
            
            VStack(spacing: spacing) {
                // We display a displayName (passkeyName, for logged out) text field for both conditions.
                // If we are logged in, we fill with the display name. If logged out, it is empty by default.
                TextField("SLUG-\(self._pkdInstance.isLoggedIn ? "DISPLAY" : "PASSKEY")-NAME-PLACEHOLDER".localizedVariant, text: self.$_displayNameText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.regular)
                    .onChange(of: self._displayNameText) {
                        if self._displayNameText.count > 255 {
                            self._displayNameText = String(self._displayNameText.prefix(255))
                        }
                    }

                if self._pkdInstance.isLoggedIn {
                    // We show a credo field, when logged in.
                    TextField("SLUG-CREDO-PLACEHOLDER".localizedVariant, text: self.$_credoText)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.regular)
                        .onChange(of: self._credoText) {
                            if self._credoText.count > 255 {
                                self._credoText = String(self._credoText.prefix(255))
                            }
                        }
                    // Three buttons, below that.
                    HStack(alignment: .center) {
                        Button("SLUG-DELETE-BUTTON".localizedVariant, role: .destructive) {
                            self._showDeleteConfirm = true
                        }
                        .font(Self._buttonFont)
                        .frame(width: columnWidth / 3)
                        Spacer()
                        Button("SLUG-LOGOUT-BUTTON".localizedVariant) {
                            self._pkdInstance.logout()
                        }
                        .font(Self._buttonFont)
                        .frame(width: columnWidth / 3)
                        Spacer()
                        Button("SLUG-UPDATE-BUTTON".localizedVariant) {
                            if !self._displayNameText.isEmpty {
                                self._pkdInstance.update(displayName: self._displayNameText, credo: self._credoText) { _ in
                                    self._displayNameText = self._pkdInstance.originalDisplayName
                                    self._credoText = self._pkdInstance.originalCredo
                                }
                            }
                        }
                        .font(Self._buttonFont)
                        .frame(width: columnWidth / 3)
                        .disabled(self._displayNameText.isEmpty || ((self._pkdInstance.originalCredo == self._credoText) && (self._pkdInstance.originalDisplayName == self._displayNameText)))
                    }
                    .onAppear {
                        self._pkdInstance.read { inData, _  in
                            self._displayNameText = inData?.displayName ?? ""
                            self._credoText = inData?.credo ?? ""
                        }
                    }
                } else {
                    // If we are not logged in, we just show two buttons, under the single text field.
                    HStack(alignment: .center) {
                        Button("SLUG-REGISTER-BUTTON".localizedVariant) {
                            self._pkdInstance.create(passKeyName: self._displayNameText) { _ in }
                        }
                        .font(Self._buttonFont)
                        .frame(width: columnWidth / 2)
                        .disabled(self._displayNameText.isEmpty)
                        Button("SLUG-LOGIN-BUTTON".localizedVariant) {
                            self._pkdInstance.login { _ in }
                        }
                        .frame(width: columnWidth / 2)
                        .font(Self._buttonFont)
                        .disabled(!self._displayNameText.isEmpty)
                    }
                    .onAppear {
                        self._displayNameText = ""
                        self._credoText = ""
                    }
                }
            }
            .frame(width: columnWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)   // Makes sure we are completely centered.
            // This is the "are you sure?" confirmation dialog, if the user selects the Delete button.
            .confirmationDialog(
                "SLUG-DELETE-CONFIRM-HEADER".localizedVariant,
                isPresented: self.$_showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("SLUG-DELETE-CONFIRM-OK-BUTTON".localizedVariant, role: .destructive) {
                    self._pkdInstance.delete()
                }
                Button("SLUG-DELETE-CONFIRM-CANCEL-BUTTON".localizedVariant, role: .cancel) { }
            } message: {
                Text(String(format: "SLUG-DELETE-CONFIRM-MESSAGE-FORMAT".localizedVariant, "SLUG-DELETE-CONFIRM-OK-BUTTON".localizedVariant))
            }
            // This is the error alert, shown if the handler encounters an error.
            .alert(
                "SLUG-ERROR-ALERT-HEADER".localizedVariant,
                isPresented: Binding(
                    get: {
                        if case .none = self._pkdInstance.lastError {
                            return false
                        } else {
                            return true
                        }
                    },
                    set: { if !$0 { self._pkdInstance.lastError = .none } }
                ),
                presenting: self._pkdInstance.lastError
            ) { _ in
                Button("SLUG-OK-BUTTON".localizedVariant, role: .cancel) {
                    self._pkdInstance.lastError = .none
                }
            } message: { err in
                Text(Self._errorMessage(for: err, lastOp: self._pkdInstance.lastOperation))
            }
        }
    }
}
