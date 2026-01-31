import Foundation

/// Browser presence + profile heuristics.
///
/// TODO: Implement Windows browser detection using registry and Windows paths:
/// - Chrome: %LOCALAPPDATA%\Google\Chrome\User Data\Default\Network\Cookies
/// - Firefox: %APPDATA%\Mozilla\Firefox\Profiles\*\cookies.sqlite
/// - Edge: %LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Network\Cookies
public struct BrowserDetection: Sendable {
    public static let defaultCacheTTL: TimeInterval = 60 * 10

    private let homeDirectory: String
    private let cacheTTL: TimeInterval

    public init(
        homeDirectory: String = "",
        cacheTTL: TimeInterval = BrowserDetection.defaultCacheTTL,
        now: @escaping @Sendable () -> Date = Date.init,
        fileExists: @escaping @Sendable (String) -> Bool = { _ in false },
        directoryContents: @escaping @Sendable (String) -> [String]? = { _ in nil })
    {
        self.homeDirectory = homeDirectory
        self.cacheTTL = cacheTTL
        _ = now
        _ = fileExists
        _ = directoryContents
    }

    public func isAppInstalled(_ browser: Browser) -> Bool {
        // TODO: Implement Windows browser detection via registry
        false
    }

    public func isCookieSourceAvailable(_ browser: Browser) -> Bool {
        // TODO: Implement Windows cookie source detection
        false
    }

    public func hasUsableProfileData(_ browser: Browser) -> Bool {
        // TODO: Implement Windows profile detection
        false
    }

    public func clearCache() {}
}
