import Foundation

public struct KeychainPromptContext: Sendable {
    public enum Kind: Sendable {
        case claudeOAuth
        case codexCookie
        case claudeCookie
        case cursorCookie
        case opencodeCookie
        case factoryCookie
        case zaiToken
        case syntheticToken
        case copilotToken
        case kimiToken
        case kimiK2Token
        case minimaxCookie
        case minimaxToken
        case augmentCookie
        case ampCookie
    }

    public let kind: Kind
    public let service: String
    public let account: String?

    public init(kind: Kind, service: String, account: String?) {
        self.kind = kind
        self.service = service
        self.account = account
    }
}

public enum KeychainPromptHandler {
    public nonisolated(unsafe) static var handler: ((KeychainPromptContext) -> Void)?
}

/// Preflight check for credential access.
///
/// TODO: Implement Windows Credential Manager preflight using CredRead
public enum KeychainAccessPreflight {
    public enum Outcome: Sendable {
        case allowed
        case interactionRequired
        case notFound
        case failure(Int)
    }

    private static let log = CodexBarLog.logger(LogCategories.keychainPreflight)

    public static func checkGenericPassword(service: String, account: String?) -> Outcome {
        // TODO: Implement Windows Credential Manager check
        // For now, return notFound as placeholder
        guard !KeychainAccessGate.isDisabled else { return .notFound }
        return .notFound
    }
}
