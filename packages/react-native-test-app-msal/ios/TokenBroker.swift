import Foundation
import MSAL

public typealias TokenAcquiredHandler = (_ result: AuthResult?, _ error: AuthError?) -> Void

@objc(TokenBroker)
public final class TokenBroker: NSObject {
    enum Constants {
        // Source: https://docs.microsoft.com/en-us/azure/active-directory/develop/id-tokens
        static let MicrosoftAccountTenant = "9188040d-6c67-4c5b-b112-36a304b66dad"
        static let RedirectURI = "msauth.\(Bundle.main.bundleIdentifier ?? "")://auth"
    }

    @objc(sharedBroker)
    public static let shared = TokenBroker()

    @objc
    public var currentAccount: Account?

    private let condition = NSCondition()
    private let dispatchQueue = DispatchQueue(label: "com.microsoft.ReactTestApp-MSAL.TokenBroker")

    private lazy var config = Config.load()

    private var _publicClientApplication: MSALPublicClientApplication?

    private var publicClientApplication: MSALPublicClientApplication? {
        if _publicClientApplication == nil {
            do {
                _publicClientApplication = try MSALPublicClientApplication(
                    configuration: MSALPublicClientApplicationConfig(
                        clientId: config.clientId,
                        redirectUri: Constants.RedirectURI,
                        authority: nil
                    )
                )
            } catch {
                NSLog("Failed to instantiate MSALPublicClientApplication: \(error.localizedDescription)")
            }
        }

        return _publicClientApplication
    }

    @objc
    public func acquireToken(
        scopes: [String],
        sender: RTAViewController,
        onTokenAcquired: @escaping TokenAcquiredHandler
    ) {
        guard let currentAccount = currentAccount else {
            let error = AuthError(
                type: .preconditionViolated,
                correlationID: "00000000-0000-0000-0000-000000000000",
                message: "No current account"
            )
            onTokenAcquired(nil, error)
            return
        }

        acquireToken(
            scopes: scopes,
            userPrincipalName: currentAccount.userPrincipalName,
            accountType: currentAccount.accountType,
            sender: sender,
            onTokenAcquired: onTokenAcquired
        )
    }

    @objc
    public func acquireToken(
        scopes: [String],
        userPrincipalName: String?,
        accountType: AccountType,
        sender: RTAViewController,
        onTokenAcquired: @escaping TokenAcquiredHandler
    ) {
        dispatchQueue.async {
            self.acquireTokenSilent(
                scopes: scopes,
                userPrincipalName: userPrincipalName,
                accountType: accountType,
                sender: sender,
                onTokenAcquired: onTokenAcquired
            )
            self.condition.wait()
        }
    }

    @objc
    public func allAccounts() -> [Account] {
        var allAccounts: [Account] = []
        if let accounts = try? publicClientApplication?.allAccounts() {
            accounts.forEach {
                guard let username = $0.username,
                      let issuer = $0.accountClaims?["iss"] as? String
                else {
                    return
                }

                let accountType = AccountType.from(issuer: issuer)
                let account = Account(userPrincipalName: username, accountType: accountType)
                allAccounts.append(account)
            }
        }
        return allAccounts
    }

    @objc
    public func removeAllAccounts(sender: RTAViewController) {
        defer {
            currentAccount = nil
        }

        guard let application = publicClientApplication,
              let accounts = try? application.allAccounts()
        else {
            return
        }

        let completion = { (_: Bool, _: Error?) in }
        accounts.forEach {
            signOut(account: $0, sender: sender, completion: completion)
        }
    }

    @objc
    public func signOut(
        sender: RTAViewController,
        completion: @escaping (_ success: Bool, _ error: Error?) -> Void
    ) {
        defer {
            currentAccount = nil
        }

        guard let username = currentAccount?.userPrincipalName,
              let account = try? publicClientApplication?.account(forUsername: username)
        else {
            completion(true, nil)
            return
        }

        signOut(account: account, sender: sender, completion: completion)
    }

    private func signOut(
        account: MSALAccount,
        sender: RTAViewController,
        completion: @escaping (_ success: Bool, _ error: Error?) -> Void
    ) {
        guard let application = publicClientApplication else {
            completion(true, nil)
            return
        }

        let webviewParameters = MSALWebviewParameters(authPresentationViewController: sender)
        let signoutParameters = MSALSignoutParameters(webviewParameters: webviewParameters)
        signoutParameters.wipeAccount = true

        application.signout(with: account, signoutParameters: signoutParameters) { success, error in
            if success {
                try? application.remove(account)
            }
            completion(success, error)
        }
    }

    private func acquireTokenInteractive(
        scopes: [String],
        userPrincipalName _: String?,
        accountType: AccountType,
        sender: RTAViewController,
        onTokenAcquired: @escaping TokenAcquiredHandler
    ) {
        guard let application = publicClientApplication else {
            return
        }

        let parameters = MSALInteractiveTokenParameters(
            scopes: scopes,
            webviewParameters: MSALWebviewParameters(authPresentationViewController: sender)
        )
        parameters.authority = try? MSALAuthority(url: accountType.authority)
        parameters.promptType = .selectAccount

        DispatchQueue.main.async {
            application.acquireToken(with: parameters) { result, error in
                self.condition.signal()

                guard let result = result else {
                    let nsError = error as NSError?
                    let errorCode = nsError?.code ?? 0
                    let message: String? = nsError?.userInfo["MSALErrorDescriptionKey"] as? String
                    let authError = AuthError(
                        type: AuthErrorType(MSALError(rawValue: errorCode) ?? .internal),
                        correlationID: "00000000-0000-0000-0000-000000000000",
                        message: message ?? nsError?.localizedDescription
                    )
                    onTokenAcquired(nil, authError)
                    return
                }

                let authResult = AuthResult(
                    accessToken: result.accessToken,
                    username: result.account.username ?? "",
                    expirationTime: Int(result.expiresOn?.timeIntervalSince1970 ?? 0),
                    redirectURI: Constants.RedirectURI
                )
                onTokenAcquired(authResult, nil)
            }
        }
    }

    private func acquireTokenSilent(
        scopes: [String],
        userPrincipalName: String?,
        accountType: AccountType,
        sender: RTAViewController,
        onTokenAcquired: @escaping TokenAcquiredHandler
    ) {
        guard let application = publicClientApplication else {
            return
        }

        guard let userPrincipalName = userPrincipalName,
              let cachedAccount = try? application.account(forUsername: userPrincipalName)
        else {
            acquireTokenInteractive(
                scopes: scopes,
                userPrincipalName: nil,
                accountType: accountType,
                sender: sender,
                onTokenAcquired: onTokenAcquired
            )
            return
        }

        let parameters = MSALSilentTokenParameters(scopes: scopes, account: cachedAccount)
        parameters.authority = try? MSALAuthority(url: accountType.authority)

        DispatchQueue.main.async {
            application.acquireTokenSilent(with: parameters) { result, error in
                if let error = error as NSError? {
                    if error.domain == MSALErrorDomain, error.code == MSALError.interactionRequired.rawValue {
                        self.acquireTokenInteractive(
                            scopes: scopes,
                            userPrincipalName: userPrincipalName,
                            accountType: accountType,
                            sender: sender,
                            onTokenAcquired: onTokenAcquired
                        )
                    } else {
                        self.condition.signal()

                        // Handle "Cannot start ASWebAuthenticationSession
                        // without providing presentation context. Set
                        // presentationContextProvider before calling
                        // -start." This can occur while the test app is
                        // navigating to the initial component.
                        if error.isMissingPresentationContextError() {
                            self.acquireToken(
                                scopes: scopes,
                                userPrincipalName: userPrincipalName,
                                accountType: accountType,
                                sender: sender,
                                onTokenAcquired: onTokenAcquired
                            )
                            return
                        }

                        let authError = AuthError(
                            type: AuthErrorType(MSALError(rawValue: error.code) ?? .internal),
                            correlationID: "00000000-0000-0000-0000-000000000000",
                            message: error.localizedDescription
                        )
                        onTokenAcquired(nil, authError)
                    }
                    return
                }

                self.condition.signal()

                let authResult = AuthResult(
                    accessToken: result?.accessToken ?? "",
                    username: result?.account.username ?? "",
                    expirationTime: Int(result?.expiresOn?.timeIntervalSince1970 ?? 0),
                    redirectURI: Constants.RedirectURI
                )
                onTokenAcquired(authResult, nil)
            }
        }
    }
}

extension NSError {
    func isMissingPresentationContextError() -> Bool {
        let domain = "com.apple.AuthenticationServices.WebAuthenticationSession"
        return self.domain == domain && code == 2
    }
}
