import Foundation

/// Credential cache store.
///
/// TODO: Implement Windows Credential Manager integration using:
/// - CredWrite / CredRead / CredDelete from wincred.h
/// - DPAPI for encryption (CryptProtectData / CryptUnprotectData)
///
/// Current implementation uses file-based storage as a placeholder.
public enum KeychainCacheStore {
    public struct Key: Hashable, Sendable {
        public let category: String
        public let identifier: String

        public init(category: String, identifier: String) {
            self.category = category
            self.identifier = identifier
        }

        var account: String {
            "\(self.category).\(self.identifier)"
        }
    }

    public enum LoadResult<Entry> {
        case found(Entry)
        case missing
        case invalid
    }

    private static let log = CodexBarLog.logger(LogCategories.keychainCache)
    private static let cacheService = "com.steipete.codexbar.cache"
    private static let cacheLabel = "CodexBar Cache"
    private nonisolated(unsafe) static var serviceOverride: String?
    private static let testStoreLock = NSLock()
    private nonisolated(unsafe) static var testStore: [Key: Data]?
    private nonisolated(unsafe) static var testStoreRefCount = 0

    public static func load<Entry: Codable>(
        key: Key,
        as type: Entry.Type = Entry.self) -> LoadResult<Entry>
    {
        if let testResult = loadFromTestStore(key: key, as: type) {
            return testResult
        }

        // File-based storage for Windows (placeholder)
        guard let cacheDir = getCacheDirectory() else { return .missing }
        let filePath = cacheDir.appendingPathComponent("\(key.account).json")

        guard FileManager.default.fileExists(atPath: filePath.path) else {
            return .missing
        }

        do {
            let data = try Data(contentsOf: filePath)
            let decoder = Self.makeDecoder()
            let decoded = try decoder.decode(Entry.self, from: data)
            return .found(decoded)
        } catch {
            self.log.error("Failed to load cache (\(key.account)): \(error)")
            return .invalid
        }
    }

    public static func store(key: Key, entry: some Codable) {
        if self.storeInTestStore(key: key, entry: entry) {
            return
        }

        // File-based storage for Windows (placeholder)
        guard let cacheDir = getCacheDirectory() else { return }
        let filePath = cacheDir.appendingPathComponent("\(key.account).json")

        do {
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            let encoder = Self.makeEncoder()
            let data = try encoder.encode(entry)
            try data.write(to: filePath)
        } catch {
            self.log.error("Failed to store cache (\(key.account)): \(error)")
        }
    }

    public static func clear(key: Key) {
        if self.clearTestStore(key: key) {
            return
        }

        // File-based storage for Windows (placeholder)
        guard let cacheDir = getCacheDirectory() else { return }
        let filePath = cacheDir.appendingPathComponent("\(key.account).json")

        try? FileManager.default.removeItem(at: filePath)
    }

    private static func getCacheDirectory() -> URL? {
        // Use AppData on Windows, or a .codexbar directory
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".codexbar").appendingPathComponent("cache")
    }

    static func setServiceOverrideForTesting(_ service: String?) {
        self.serviceOverride = service
    }

    static func setTestStoreForTesting(_ enabled: Bool) {
        self.testStoreLock.lock()
        defer { self.testStoreLock.unlock() }
        if enabled {
            self.testStoreRefCount += 1
            if self.testStoreRefCount == 1 {
                self.testStore = [:]
            }
        } else {
            self.testStoreRefCount = max(0, self.testStoreRefCount - 1)
            if self.testStoreRefCount == 0 {
                self.testStore = nil
            }
        }
    }

    private static var serviceName: String {
        self.serviceOverride ?? self.cacheService
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func loadFromTestStore<Entry: Codable>(
        key: Key,
        as type: Entry.Type) -> LoadResult<Entry>?
    {
        self.testStoreLock.lock()
        defer { self.testStoreLock.unlock() }
        guard let store = self.testStore else { return nil }
        guard let data = store[key] else { return .missing }
        let decoder = Self.makeDecoder()
        guard let decoded = try? decoder.decode(Entry.self, from: data) else {
            return .invalid
        }
        return .found(decoded)
    }

    private static func storeInTestStore(key: Key, entry: some Codable) -> Bool {
        self.testStoreLock.lock()
        defer { self.testStoreLock.unlock() }
        guard var store = self.testStore else { return false }
        let encoder = Self.makeEncoder()
        guard let data = try? encoder.encode(entry) else { return true }
        store[key] = data
        self.testStore = store
        return true
    }

    private static func clearTestStore(key: Key) -> Bool {
        self.testStoreLock.lock()
        defer { self.testStoreLock.unlock() }
        guard var store = self.testStore else { return false }
        store.removeValue(forKey: key)
        self.testStore = store
        return true
    }
}

extension KeychainCacheStore.Key {
    public static func cookie(provider: UsageProvider) -> Self {
        Self(category: "cookie", identifier: provider.rawValue)
    }

    public static func oauth(provider: UsageProvider) -> Self {
        Self(category: "oauth", identifier: provider.rawValue)
    }
}
