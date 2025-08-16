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
     */
    @State private var _displayNameText = ""

    /* ###################################################################### */
    /**
     */
    @State private var _credoText = ""

    /* ###################################################################### */
    /**
     */
    var body: some View {
        GeometryReader { inProxy in
            let columnWidth = inProxy.size.width * 0.6
            let spacing = CGFloat(30)
            
            VStack(spacing: spacing) {
                TextField("SLUG-DISPLAY-NAME-PLACEHOLDER".localizedVariant, text: self.$_displayNameText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.regular)
                    .onChange(of: _displayNameText) {
                        if _displayNameText.count > 255 {
                            _displayNameText = String(_displayNameText.prefix(255))
                        }
                    }
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
                        Button("SLUG-DELETE-BUTTON".localizedVariant) {
                            self._pkdInstance.delete()
                        }
                        .font(Self._buttonFont)
                        .frame(width: columnWidth / 3)
                        .foregroundStyle(.red)
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
                    HStack(alignment: .center) {
                        Button("SLUG-REGISTER-BUTTON".localizedVariant) {
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
        }
    }
}
