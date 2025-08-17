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
 */
struct PKD_MainView: View {
    /* ###################################################################### */
    /**
     The font used for the buttons in the screen.
     */
    static private let _buttonFont = Font.system(size: 15, weight: .bold)
    
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
     */
    private func _errorMessage(for err: PKD_Handler.PKD_Errors, lastOp: PKD_Handler.UserOperation) -> String {
        // Map last operation to a base slug
        let opSlug: String = {
            switch lastOp {
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
        }()

        // Map error to description
        var detail = "SLUG-ERROR-PKDH-0".localizedVariant
        switch err {
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
            
        case .communicationError(let underlying):
            detail = "SLUG-ERROR-PKDH-6".localizedVariant
            
            if let u = underlying, !u.localizedDescription.isEmpty {
                detail += ": " + u.localizedDescription
            }
        case .badInputParameters:
            detail = "SLUG-ERROR-PKDH-7".localizedVariant
            
        case .biometricsNotAvailable:
            detail = "SLUG-ERROR-PKDH-8".localizedVariant
        }

        let base = opSlug.localizedVariant
        return detail.isEmpty ? base : "\(base)\n\(detail)"
    }
    
    /* ###################################################################### */
    /**
     */
    var body: some View {
        GeometryReader { inProxy in
            let columnWidth = inProxy.size.width * 0.6
            let spacing = CGFloat(30)
            
            VStack(spacing: spacing) {
                TextField("SLUG-\(self._pkdInstance.isLoggedIn ? "DISPLAY" : "PASSKEY")-NAME-PLACEHOLDER".localizedVariant, text: self.$_displayNameText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.regular)
                    .onChange(of: _displayNameText) {
                        if _displayNameText.count > 255 {
                            _displayNameText = String(_displayNameText.prefix(255))
                        }
                    }
                // If we are logged in, we read the data from the server, and show it in two text boxes. There are three buttons, below the text boxes, and the update button is enabled, if there has been a change in the text boxes.
                if self._pkdInstance.isLoggedIn {
                    TextField("SLUG-CREDO-PLACEHOLDER".localizedVariant, text: self.$_credoText)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.regular)
                        .onChange(of: _credoText) {
                            if _credoText.count > 255 {
                                _credoText = String(_credoText.prefix(255))
                            }
                        }
                    HStack(alignment: .center) {
                        Button("SLUG-DELETE-BUTTON".localizedVariant, role: .destructive) {
                            _showDeleteConfirm = true
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
                } else {    // If we are not logged in, we show a text field, a register button, and a login button.
                    HStack(alignment: .center) {
                        Button("SLUG-REGISTER-BUTTON".localizedVariant) {
                            self._pkdInstance.create(displayName: self._displayNameText) { _ in }
                        }
                        .font(Self._buttonFont)
                        .frame(width: columnWidth / 2)
                        .disabled(self._displayNameText.isEmpty)
                        Button("SLUG-LOGIN-BUTTON".localizedVariant) {
                            self._pkdInstance.login { _ in }
                        }
                        .frame(width: columnWidth / 2)
                        .font(Self._buttonFont)
                    }
                    .onAppear {
                        self._displayNameText = ""
                        self._credoText = ""
                    }
                }
            }
            .frame(width: columnWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .confirmationDialog(
                "SLUG-DELETE-CONFIRM-HEADER".localizedVariant,
                isPresented: $_showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("SLUG-DELETE-CONFIRM-OK-BUTTON".localizedVariant, role: .destructive) {
                    _pkdInstance.delete()
                }
                Button("SLUG-DELETE-CONFIRM-CANCEL-BUTTON".localizedVariant, role: .cancel) { }
            } message: {
                Text(String(format: "SLUG-DELETE-CONFIRM-MESSAGE-FORMAT".localizedVariant, "SLUG-DELETE-CONFIRM-OK-BUTTON".localizedVariant))
            }
            .alert(
                "SLUG-ERROR-ALERT-HEADER".localizedVariant,
                isPresented: Binding(
                    get: {
                        if case .none = _pkdInstance.lastError {
                            return false
                        } else {
                            return true
                        }
                    },
                    set: { if !$0 { _pkdInstance.lastError = .none } }
                ),
                presenting: _pkdInstance.lastError
            ) { _ in
                Button("SLUG-OK-BUTTON".localizedVariant, role: .cancel) {
                    _pkdInstance.lastError = .none
                }
            } message: { err in
                Text(self._errorMessage(for: err, lastOp: _pkdInstance.lastOperation))
            }
        }
    }
}
