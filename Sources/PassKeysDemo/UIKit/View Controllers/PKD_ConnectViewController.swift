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
 */
class PKD_ConnectViewController: UIViewController {
    /* ###################################################################### */
    /**
     */
    static let relyingParty = Bundle.main.defaultRelyingPartyString
    
    /* ###################################################################### */
    /**
     */
    static let baseURLString = Bundle.main.defaultBaseURIString
    
    /* ###################################################################### */
    /**
     */
    static let userIDString = Bundle.main.defaultUserIDString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    
    /* ###################################################################### */
    /**
     */
    static let userNameString = Bundle.main.defaultUserNameString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

    /* ###################################################################### */
    /**
     */
    var challenge: Data?
    
    /* ###################################################################### */
    /**
     */
    let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        return URLSession(configuration: config)
    }()
    
    /* ###################################################################### */
    /**
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        let registerButton = UIButton(type: .system)
        registerButton.setTitle("Register Passkey", for: .normal)
        registerButton.addTarget(self, action: #selector(registerPasskey), for: .touchUpInside)
        
        let loginButton = UIButton(type: .system)
        loginButton.setTitle("Login with Passkey", for: .normal)
        loginButton.addTarget(self, action: #selector(loginWithPasskey), for: .touchUpInside)
        
        let stack = UIStackView(arrangedSubviews: [registerButton, loginButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
    
    /* ###################################################################### */
    /**
     */
    @objc func registerPasskey() {
        fetchRegistrationOptions(from: "\(Self.baseURLString)/register_challenge.php?user_id=\(Self.userIDString)&display_name=\(Self.userNameString)") { InResponse in
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
                name: publicKey.user.name,
                userID: userIDData
            )

            self.challenge = challengeData

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
    
    /* ###################################################################### */
    /**
     */
    @objc func loginWithPasskey() {
        fetchChallenge(from: "\(Self.baseURLString)/login_challenge.php") { inResult in
            switch inResult {
            case .success(let challengeDict):
                guard let publicKey = challengeDict["publicKey"] as? [String: Any],
                      let challengeData = (publicKey["challenge"] as? String)?.base64urlDecodedData
                else {
                    print("Invalid challenge format")
                    return
                }
                
                let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: Self.relyingParty)
                let request = provider.createCredentialAssertionRequest(challenge: challengeData)
                
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self
                controller.presentationContextProvider = self
                controller.performRequests()
            case .failure(let error):
                print("Failed to fetch challenge: \(error)")
            }
        }
    }
    
    /* ###################################################################### */
    /**
     */
    struct PublicKeyCredentialCreationOptions: Decodable {
        struct PublicKey: Decodable {
            let challenge: String
            let rp: RP
            let user: User
            // other fields as needed

            struct RP: Decodable {
                let id: String
            }

            struct User: Decodable {
                let id: String
                let name: String
            }
        }

        let publicKey: PublicKey
    }
    
    /* ###################################################################### */
    /**
     */
    func fetchRegistrationOptions(from inURLString: String, completion: @escaping (PublicKeyCredentialCreationOptions?) -> Void) {
        guard let url = URL(string: inURLString)
        else {
            completion(nil)
            return
        }
        
        let task = session.dataTask(with: url) { inData, _, error in
            guard let data = inData else {
                print("Failed to fetch options: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let options = try decoder.decode(PublicKeyCredentialCreationOptions.self, from: data)
                completion(options)
            } catch {
                print("JSON decoding error: \(error)")
                completion(nil)
            }
        }
        
        task.resume()
    }

    /* ###################################################################### */
    /**
     */
    func fetchChallenge(from urlString: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        print("URL: \(urlString)")
        guard let url = URL(string: urlString) else { return }
        let task = session.dataTask(with: url) { inData, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = inData,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let publicKey = json["publicKey"] as? [String: Any],
                  let challengeData = (publicKey["challenge"] as? String)?.base64urlDecodedData
            else {
                completion(.failure(NSError(domain: "json", code: 1)))
                return
            }
            
            self.challenge = challengeData
            completion(.success(json))
        }
        task.resume()
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

            postResponse(to: "\(Self.baseURLString)/register_response.php", payload: payload)
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

            if let payloadStr = payload["authenticatorData"],
               let data = Data(base64Encoded: payloadStr),
               let decodedString = String(data: data, encoding: .utf8) {
                print("From Us: " + decodedString)
            }

            postResponse(to: "\(Self.baseURLString)/login_response.php", payload: payload)
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

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = responseData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(responseData.count)", forHTTPHeaderField: "Content-Length")
        let task = session.dataTask(with: request) { inData, _, inError in
            if let data = inData,
               let response = String(data: data, encoding: .utf8) {
                print("Server response: \(response)")
            }
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
