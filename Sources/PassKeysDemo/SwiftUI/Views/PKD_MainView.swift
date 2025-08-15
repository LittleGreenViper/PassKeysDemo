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
    static private let _buttonFont = Font.system(size: 20, weight: .bold)
    
    /* ###################################################################### */
    /**
     */
    @State private var _pkdInstance: PKD_Handler?

    /* ###################################################################### */
    /**
     */
    var body: some View {
        GeometryReader { inProxy in
            let columnWidth = inProxy.size.width * 0.6
            let spacing = CGFloat(30)
            
            VStack(spacing: spacing) {
                if let pkdInstance = _pkdInstance {
                    TextField("SLUG-DISPLAY-NAME-PLACEHOLDER".localizedVariant, text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.regular)
                    if pkdInstance.isLoggedIn {
                        TextField("SLUG-CREDO-PLACEHOLDER".localizedVariant, text: .constant(""))
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.regular)
                        HStack(alignment: .center) {
                            Button("SLUG-DELETE-BUTTON".localizedVariant) {
                                pkdInstance.delete()
                            }
                            .font(Self._buttonFont)
                            .frame(width: columnWidth / 3)
                            .foregroundStyle(.red)
                            Spacer()
                            Button("SLUG-LOGOUT-BUTTON".localizedVariant) {
                                pkdInstance.logout()
                            }
                            .font(Self._buttonFont)
                            .frame(width: columnWidth / 3)
                            Spacer()
                            Button("SLUG-UPDATE-BUTTON".localizedVariant) {
                            }
                            .font(Self._buttonFont)
                            .frame(width: columnWidth / 3)
                        }
                    } else {
                        HStack(alignment: .center) {
                            Button("SLUG-REGISTER-BUTTON".localizedVariant) {
                            }
                            .font(Self._buttonFont)
                            .frame(width: columnWidth / 2)
                            Button("SLUG-LOGIN-BUTTON".localizedVariant) {
                                pkdInstance.login { inSuccess in
                                    
                                }
                            }
                            .frame(width: columnWidth / 2)
                            .font(Self._buttonFont)
                        }
                    }
                } else {
                    Text("ERROR!")
                }
            }
            .frame(width: columnWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .onAppear {
            let presentationAnchor = UIApplication.shared
                .connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? UIWindow()
            
            self._pkdInstance = self._pkdInstance ?? PKD_Handler(relyingParty: Bundle.main.defaultRelyingPartyString, baseURIString: Bundle.main.defaultBaseURIString, presentationAnchor: presentationAnchor)
        }
    }
}
