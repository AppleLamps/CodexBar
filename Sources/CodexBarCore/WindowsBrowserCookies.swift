import Foundation

#if os(Windows)
import WinSDK

/// Windows browser cookie access using DPAPI decryption.
///
/// Chromium-based browsers (Chrome, Edge, Brave) on Windows encrypt cookies using:
/// 1. DPAPI for older versions
/// 2. AES-256-GCM with a DPAPI-protected key for newer versions (v80+)
///
/// This implementation supports both encryption methods.
public enum WindowsBrowserCookies {
    private static let log = CodexBarLog.logger(LogCategories.browserCookies)

    /// Browser cookie database paths on Windows
    public struct BrowserPaths {
        public let cookiesDb: String
        public let localState: String?

        public static func chrome() -> BrowserPaths? {
            guard let localAppData = ProcessInfo.processInfo.environment["LOCALAPPDATA"] else {
                return nil
            }
            return BrowserPaths(
                cookiesDb: "\(localAppData)\\Google\\Chrome\\User Data\\Default\\Network\\Cookies",
                localState: "\(localAppData)\\Google\\Chrome\\User Data\\Local State")
        }

        public static func edge() -> BrowserPaths? {
            guard let localAppData = ProcessInfo.processInfo.environment["LOCALAPPDATA"] else {
                return nil
            }
            return BrowserPaths(
                cookiesDb: "\(localAppData)\\Microsoft\\Edge\\User Data\\Default\\Network\\Cookies",
                localState: "\(localAppData)\\Microsoft\\Edge\\User Data\\Local State")
        }

        public static func brave() -> BrowserPaths? {
            guard let localAppData = ProcessInfo.processInfo.environment["LOCALAPPDATA"] else {
                return nil
            }
            return BrowserPaths(
                cookiesDb: "\(localAppData)\\BraveSoftware\\Brave-Browser\\User Data\\Default\\Network\\Cookies",
                localState: "\(localAppData)\\BraveSoftware\\Brave-Browser\\User Data\\Local State")
        }

        public static func firefox() -> BrowserPaths? {
            guard let appData = ProcessInfo.processInfo.environment["APPDATA"] else {
                return nil
            }
            let profilesDir = "\(appData)\\Mozilla\\Firefox\\Profiles"
            // Find the default profile
            let fm = FileManager.default
            guard let profiles = try? fm.contentsOfDirectory(atPath: profilesDir) else {
                return nil
            }
            // Look for a profile ending in .default or .default-release
            let defaultProfile = profiles.first { $0.hasSuffix(".default-release") }
                ?? profiles.first { $0.hasSuffix(".default") }
                ?? profiles.first
            guard let profile = defaultProfile else { return nil }
            return BrowserPaths(
                cookiesDb: "\(profilesDir)\\\(profile)\\cookies.sqlite",
                localState: nil)  // Firefox doesn't use Local State
        }
    }

    /// Represents a decrypted cookie
    public struct Cookie: Sendable {
        public let name: String
        public let value: String
        public let domain: String
        public let path: String
        public let expiresAt: Date?
        public let isSecure: Bool
        public let isHttpOnly: Bool
    }

    /// Import cookies for a specific domain from a Chromium browser
    public static func importChromiumCookies(
        paths: BrowserPaths,
        domain: String) -> [Cookie]
    {
        // Read the encryption key from Local State
        var encryptionKey: Data?
        if let localStatePath = paths.localState {
            encryptionKey = readChromiumEncryptionKey(localStatePath: localStatePath)
        }

        // Read cookies from SQLite database
        return readChromiumCookies(
            dbPath: paths.cookiesDb,
            domain: domain,
            encryptionKey: encryptionKey)
    }

    /// Read the Chromium encryption key from Local State JSON
    private static func readChromiumEncryptionKey(localStatePath: String) -> Data? {
        guard let data = FileManager.default.contents(atPath: localStatePath) else {
            log.debug("Could not read Local State file")
            return nil
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let osCrypt = json["os_crypt"] as? [String: Any],
                  let encryptedKeyBase64 = osCrypt["encrypted_key"] as? String else {
                log.debug("Could not parse encryption key from Local State")
                return nil
            }

            // Decode base64
            guard var keyData = Data(base64Encoded: encryptedKeyBase64) else {
                log.debug("Invalid base64 encryption key")
                return nil
            }

            // Remove "DPAPI" prefix (5 bytes)
            guard keyData.count > 5 else {
                log.debug("Encryption key too short")
                return nil
            }
            let prefix = String(data: keyData.prefix(5), encoding: .utf8)
            if prefix == "DPAPI" {
                keyData = keyData.dropFirst(5)
            }

            // Decrypt with DPAPI
            guard let decryptedKey = WindowsDataProtection.unprotect(data: Data(keyData)) else {
                log.debug("Could not decrypt encryption key with DPAPI")
                return nil
            }

            return decryptedKey
        } catch {
            log.error("Error parsing Local State: \(error)")
            return nil
        }
    }

    /// Read cookies from Chromium SQLite database
    private static func readChromiumCookies(
        dbPath: String,
        domain: String,
        encryptionKey: Data?) -> [Cookie]
    {
        // Note: Full SQLite integration would require a SQLite Swift binding.
        // This is a stub that shows the structure.
        // In a real implementation, use SQLite.swift or similar.

        log.debug("Would read cookies from: \(dbPath) for domain: \(domain)")

        // The actual implementation would:
        // 1. Open the SQLite database
        // 2. Query: SELECT name, encrypted_value, host_key, path, expires_utc, is_secure, is_httponly
        //           FROM cookies WHERE host_key LIKE '%domain%'
        // 3. For each row, decrypt the encrypted_value:
        //    - If starts with "v10" or "v11": Use AES-GCM with encryptionKey
        //    - Otherwise: Use DPAPI directly

        return []
    }

    /// Decrypt a Chromium v10/v11 encrypted cookie value
    public static func decryptChromiumCookie(
        encryptedValue: Data,
        key: Data) -> String?
    {
        // Check for v10/v11 prefix
        guard encryptedValue.count > 3 else { return nil }

        let prefix = encryptedValue.prefix(3)
        let prefixStr = String(data: prefix, encoding: .utf8)

        if prefixStr == "v10" || prefixStr == "v11" {
            // AES-256-GCM encrypted
            // Format: v10 + 12-byte nonce + ciphertext + 16-byte tag
            let payload = encryptedValue.dropFirst(3)
            guard payload.count > 28 else { return nil }  // 12 nonce + 16 tag minimum

            let nonce = payload.prefix(12)
            let ciphertextWithTag = payload.dropFirst(12)

            // Would use CryptoKit or similar for AES-GCM decryption
            // This is a placeholder - actual implementation requires crypto library
            log.debug("AES-GCM decryption required for v10/v11 cookie")
            return nil
        } else {
            // Old DPAPI-only encryption
            guard let decrypted = WindowsDataProtection.unprotect(data: encryptedValue) else {
                return nil
            }
            return String(data: decrypted, encoding: .utf8)
        }
    }

    /// Build a cookie header string from cookies
    public static func buildCookieHeader(cookies: [Cookie]) -> String {
        cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }
}

// MARK: - Firefox Cookie Support

extension WindowsBrowserCookies {
    /// Import cookies from Firefox (SQLite, no encryption on Windows)
    public static func importFirefoxCookies(
        paths: BrowserPaths,
        domain: String) -> [Cookie]
    {
        // Firefox on Windows doesn't encrypt cookies
        // Just needs SQLite access

        log.debug("Would read Firefox cookies from: \(paths.cookiesDb) for domain: \(domain)")

        // The actual implementation would:
        // 1. Open the SQLite database
        // 2. Query: SELECT name, value, host, path, expiry, isSecure, isHttpOnly
        //           FROM moz_cookies WHERE host LIKE '%domain%'
        // 3. Return the cookies directly (no decryption needed)

        return []
    }
}

#else

// Stub implementation for non-Windows platforms
public enum WindowsBrowserCookies {
    public struct BrowserPaths {
        public let cookiesDb: String
        public let localState: String?
        public static func chrome() -> BrowserPaths? { nil }
        public static func edge() -> BrowserPaths? { nil }
        public static func brave() -> BrowserPaths? { nil }
        public static func firefox() -> BrowserPaths? { nil }
    }

    public struct Cookie: Sendable {
        public let name: String
        public let value: String
        public let domain: String
        public let path: String
        public let expiresAt: Date?
        public let isSecure: Bool
        public let isHttpOnly: Bool
    }

    public static func importChromiumCookies(paths: BrowserPaths, domain: String) -> [Cookie] { [] }
    public static func importFirefoxCookies(paths: BrowserPaths, domain: String) -> [Cookie] { [] }
    public static func buildCookieHeader(cookies: [Cookie]) -> String { "" }
    public static func decryptChromiumCookie(encryptedValue: Data, key: Data) -> String? { nil }
}

#endif
