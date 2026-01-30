import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public struct JetBrainsQuotaInfo: Sendable, Equatable {
    public let type: String?
    public let used: Double
    public let maximum: Double
    public let available: Double
    public let until: Date?

    public init(type: String?, used: Double, maximum: Double, available: Double?, until: Date?) {
        self.type = type
        self.used = used
        self.maximum = maximum
        // Use available if provided, otherwise calculate from maximum - used
        self.available = available ?? max(0, maximum - used)
        self.until = until
    }

    /// Percentage of quota that has been used (0-100)
    public var usedPercent: Double {
        guard self.maximum > 0 else { return 0 }
        return min(100, max(0, (self.used / self.maximum) * 100))
    }

    /// Percentage of quota remaining (0-100), based on available value
    public var remainingPercent: Double {
        guard self.maximum > 0 else { return 100 }
        return min(100, max(0, (self.available / self.maximum) * 100))
    }
}

public struct JetBrainsRefillInfo: Sendable, Equatable {
    public let type: String?
    public let next: Date?
    public let amount: Double?
    public let duration: String?

    public init(type: String?, next: Date?, amount: Double?, duration: String?) {
        self.type = type
        self.next = next
        self.amount = amount
        self.duration = duration
    }
}

public struct JetBrainsStatusSnapshot: Sendable {
    public let quotaInfo: JetBrainsQuotaInfo
    public let refillInfo: JetBrainsRefillInfo?
    public let detectedIDE: JetBrainsIDEInfo?

    public init(quotaInfo: JetBrainsQuotaInfo, refillInfo: JetBrainsRefillInfo?, detectedIDE: JetBrainsIDEInfo?) {
        self.quotaInfo = quotaInfo
        self.refillInfo = refillInfo
        self.detectedIDE = detectedIDE
    }

    public func toUsageSnapshot() throws -> UsageSnapshot {
        // Primary shows monthly credits usage with next refill date
        // IDE displays: "今月のクレジット残り X / Y" with "Z月D日に更新されます"
        let refillDate = self.refillInfo?.next
        let primary = RateWindow(
            usedPercent: self.quotaInfo.usedPercent,
            windowMinutes: nil,
            resetsAt: refillDate,
            resetDescription: Self.formatResetDescription(refillDate))

        let identity = ProviderIdentitySnapshot(
            providerID: .jetbrains,
            accountEmail: nil,
            accountOrganization: self.detectedIDE?.displayName,
            loginMethod: self.quotaInfo.type)

        return UsageSnapshot(
            primary: primary,
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(),
            identity: identity)
    }

    private static func formatResetDescription(_ date: Date?) -> String? {
        guard let date else { return nil }
        let now = Date()
        let interval = date.timeIntervalSince(now)
        guard interval > 0 else { return "Expired" }

        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "Resets in \(days)d \(remainingHours)h"
        } else if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(minutes)m"
        }
    }
}

public enum JetBrainsStatusProbeError: LocalizedError, Sendable, Equatable {
    case noIDEDetected
    case quotaFileNotFound(String)
    case parseError(String)
    case noQuotaInfo

    public var errorDescription: String? {
        switch self {
        case .noIDEDetected:
            "No JetBrains IDE with AI Assistant detected. Install a JetBrains IDE and enable AI Assistant."
        case let .quotaFileNotFound(path):
            "JetBrains AI quota file not found at \(path). Enable AI Assistant in your IDE."
        case let .parseError(message):
            "Could not parse JetBrains AI quota: \(message)"
        case .noQuotaInfo:
            "No quota information found in the JetBrains AI configuration."
        }
    }
}

public struct JetBrainsStatusProbe: Sendable {
    private let settings: ProviderSettingsSnapshot?

    public init(settings: ProviderSettingsSnapshot? = nil) {
        self.settings = settings
    }

    public func fetch() async throws -> JetBrainsStatusSnapshot {
        let (quotaFilePath, detectedIDE) = try self.resolveQuotaFilePath()
        return try Self.parseQuotaFile(at: quotaFilePath, detectedIDE: detectedIDE)
    }

    private func resolveQuotaFilePath() throws -> (String, JetBrainsIDEInfo?) {
        if let customPath = self.settings?.jetbrainsIDEBasePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !customPath.isEmpty
        {
            let expandedBasePath = (customPath as NSString).expandingTildeInPath
            let quotaPath = JetBrainsIDEDetector.quotaFilePath(for: expandedBasePath)
            return (quotaPath, nil)
        }

        guard let detectedIDE = JetBrainsIDEDetector.detectLatestIDE() else {
            throw JetBrainsStatusProbeError.noIDEDetected
        }
        return (detectedIDE.quotaFilePath, detectedIDE)
    }

    public static func parseQuotaFile(
        at path: String,
        detectedIDE: JetBrainsIDEInfo?) throws -> JetBrainsStatusSnapshot
    {
        guard FileManager.default.fileExists(atPath: path) else {
            throw JetBrainsStatusProbeError.quotaFileNotFound(path)
        }

        let xmlData: Data
        do {
            xmlData = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw JetBrainsStatusProbeError.parseError("Failed to read file: \(error.localizedDescription)")
        }

        return try Self.parseXMLData(xmlData, detectedIDE: detectedIDE)
    }

    public static func parseXMLData(_ data: Data, detectedIDE: JetBrainsIDEInfo?) throws -> JetBrainsStatusSnapshot {
        