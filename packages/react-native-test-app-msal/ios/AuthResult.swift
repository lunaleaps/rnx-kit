import MSAL

@objc
public enum AuthErrorType: Int {
    case unknown
    case badRefreshToken
    case conditionalAccessBlocked
    case interactionRequired
    case noResponse
    case preconditionViolated
    case serverDeclinedScopes
    case serverProtectionPoliciesRequired
    case timeout
    case userCanceled
    case workplaceJoinRequired

    public init(_ errorCode: MSALError) {
        switch errorCode {
        case .internal:
            self = .unknown
        case .interactionRequired:
            self = .interactionRequired
        case .serverDeclinedScopes:
            self = .serverDeclinedScopes
        case .serverProtectionPoliciesRequired:
            self = .serverProtectionPoliciesRequired
        case .userCanceled:
            self = .userCanceled
        case .workplaceJoinRequired:
            self = .workplaceJoinRequired
        default:
            self = .unknown
        }
    }
}

@objcMembers
public final class AuthError: NSObject {
    public let type: AuthErrorType
    public let correlationID: String
    public let message: String?

    public init(type: AuthErrorType, correlationID: String, message: String? = nil) {
        self.type = type
        self.correlationID = correlationID
        self.message = message
    }
}

@objcMembers
public final class AuthResult: NSObject {
    public let accessToken: String
    public let username: String
    public let expirationTime: Int
    public let redirectURI: String?

    public init(accessToken: String, username: String, expirationTime: Int, redirectURI: String? = nil) {
        self.accessToken = accessToken
        self.username = username
        self.expirationTime = expirationTime
        self.redirectURI = redirectURI
    }
}
