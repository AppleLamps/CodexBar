import Foundation

/// Browser type for cookie import operations.
///
/// This is a cross-platform stub replacing the macOS-only SweetCookieKit Browser type.
/// TODO: Implement Windows browser cookie access using DPAPI and Windows paths.
public struct Browser: Sendable, Hashable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var displayName: String {
        switch rawValue {
        case "chrome": return "Chrome"
        case "firefox": return "Firefox"
        case "edge": return "Edge"
        case "safari": return "Safari"
        case "brave": return "Brave"
        case "arc": return "Arc"
        case "vivaldi": return "Vivaldi"
        default: return rawValue.capitalized
        }
    }

    public var appBundleName: String? {
        switch rawValue {
        case "chrome": return "Google Chrome"
        case "firefox": return "Firefox"
        case "edge": return "Microsoft Edge"
        case "safari": return "Safari"
        case "brave": return "Brave Browser"
        default: return nil
        }
    }

    public var chromiumProfileRelativePath: String? {
        switch rawValue {
        case "chrome": return "Google/Chrome"
        case "edge": return "Microsoft/Edge"
        case "brave": return "BraveSoftware/Brave-Browser"
        case "vivaldi": return "Vivaldi"
        case "arc": return "Arc/User Data"
        default: return nil
        }
    }

    public var geckoProfilesFolder: String? {
        switch rawValue {
        case "firefox": return "Firefox"
        case "zen": return "zen"
        default: return nil
        }
    }

    public var usesGeckoProfileStore: Bool {
        geckoProfilesFolder != nil
    }

    public var usesChromiumProfileStore: Bool {
        chromiumProfileRelativePath != nil
    }

    public var usesKeychainForCookieDecryption: Bool {
        // On Windows, Chromium browsers use DPAPI instead of Keychain
        false
    }

    // Common browser instances
    public static let chrome = Browser(rawValue: "chrome")
    public static let firefox = Browser(rawValue: "firefox")
    public static let edge = Browser(rawValue: "edge")
    public static let safari = Browser(rawValue: "safari")
    public static let brave = Browser(rawValue: "brave")
    public static let arc = Browser(rawValue: "arc")
    public static let vivaldi = Browser(rawValue: "vivaldi")
    public static let zen = Browser(rawValue: "zen")

    /// Default browser import order for Windows
    public static let defaultImportOrder: [Browser] = [
        .chrome,
        .edge,
        .firefox,
        .brave,
        .vivaldi,
    ]

    /// Safe storage labels for Chromium Keychain access (macOS only - stub for Windows)
    public static let safeStorageLabels: [(service: String, account: String)] = []
}

/// Error type for browser cookie operations
public struct BrowserCookieError: Error {
    public enum Kind {
        case accessDenied
        case notFound
        case parseError
        case unknown
    }

    public let kind: Kind
    public let browser: Browser
    public let message: String?

    public init(kind: Kind, browser: Browser, message: String? = nil) {
        self.kind = kind
        self.browser = browser
        self.message = message
    }

    public static func accessDenied(browser: Browser) -> BrowserCookieError {
        BrowserCookieError(kind: .accessDenied, browser: browser)
    }
}
