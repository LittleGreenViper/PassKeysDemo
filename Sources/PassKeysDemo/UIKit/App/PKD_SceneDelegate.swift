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

/* ###################################################################################################################################### */
// MARK: - Main Scene Delegate Class -
/* ###################################################################################################################################### */
/**
 This is the scene delegate. It also doesn't do much.
 */
class PKD_SceneDelegate: UIResponder {
    /* ###################################################################### */
    /**
     The required window object.
     */
    var window: UIWindow?

    /* ###################################################################### */
    /**
     This allows us to easily access the scene's window (for the auth attachment).
     */
    static var currentWindow: UIWindow? {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .delegate as? PKD_SceneDelegate
        )?.window
    }
}

/* ###################################################################################################################################### */
// MARK: UIWindowSceneDelegate Conformance
/* ###################################################################################################################################### */
extension PKD_SceneDelegate: UIWindowSceneDelegate {
    /* ###################################################################### */
    /**
     Called as the scene is about to connect.
     
     - parameter inScene: The scene instance that will connect.
     - parameter willConnectTo: The session we're connecting to (ignored).
     - parameter options: The connection options (also ignored).
     */
    func scene(_ inScene: UIScene, willConnectTo: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let _ = (inScene as? UIWindowScene) else { return }
    }
}
