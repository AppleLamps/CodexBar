import Foundation

public typealias BrowserCookieImportOrder = [Browser]

extension [Browser] {
    /// Filters a browser list to sources worth attempting for cookie imports.
    ///
    /// This is intentionally stricter than "app installed": it aims to avoid unnecessary credential prompts.
    public func cookieImportCandidates(using detection: BrowserDetection) -> [Browser] {
        guard !KeychainAccessGate.isDisabled else { return [] }
        let candidates = self.filter { detection.isCookieSourceAvailable($0) }
        return candidates.filter { BrowserCookieAccessGate.shouldAttempt($0) }
    }

    /// Filters a browser list to sources with usable profile data on disk.
    public func browsersWithProfileData(using detection: BrowserDetection) -> [Browser] {
        self.filter { detection.hasUsableProfileData($0) }
    }
}
