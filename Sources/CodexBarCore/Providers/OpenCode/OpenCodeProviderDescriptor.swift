import CodexBarMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum OpenCodeProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .opencode,
            metadata: ProviderMetadata(
                id: .opencode,
                displayName: "OpenCode",
                sessionLabel: "5-hour",
                weeklyLabel: "Weekly",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show OpenCode usage",
                cliName: "opencode",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                browserCookieOrder: ProviderBrowserCookieDefaults.defaultImportOrder,
                dashboardURL: "https://opencode.ai",
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .opencode,
                iconResourceName: "ProviderIcon-opencode",
                color: ProviderColor(red: 59 / 255, green: 130 / 255, blue: 246 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "OpenCode cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .web],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [OpenCodeUsageFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "opencode",
                versionDetector: nil))
    }
}

struct OpenCodeUsageFetchStrategy: ProviderFetchStrategy {
    let id: String = "opencode.web"
    let kind: ProviderFetchKind = .web

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        guard context.settings?.opencode?.cookieSource != .off else { return false }
        // Check if manual cookie is configured
        if context.settings?.opencode?.cookieSource == .manual {
            return context.settings?.opencode?.manualCookieHeader != nil
        }
        return false
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        let workspaceOverride = context.settings?.opencode?.workspaceID
            ?? context.env["CODEXBAR_OPENCODE_WORKSPACE_ID"]
        let cookieHeader = try Self.resolveCookieHeader(context: context)
        let snapshot = try await OpenCodeUsageFetcher.fetchUsage(
            cookieHeader: cookieHeader,
            timeout: context.webTimeout,
            workspaceIDOverride: workspaceOverride)
        return self.makeResult(
            usage: snapshot.toUsageSnapshot(),
            sourceLabel: "web")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveCookieHeader(context: ProviderFetchContext) throws -> String {
        if let settings = context.settings?.opencode, settings.cookieSource == .manual {
            if let header = CookieHeaderNormalizer.normalize(settings.manualCookieHeader) {
                let pairs = CookieHeaderNormalizer.pairs(from: header)
                let hasAuthCookie = pairs.contains { pair in
                    pair.name == "auth" || pair.name == "__Host-auth"
                }
                if hasAuthCookie {
                    return header
                }
            }
            throw OpenCodeSettingsError.invalidCookie
        }

        // TODO: Implement Windows browser cookie import
        throw OpenCodeSettingsError.missingCookie
    }
}

enum OpenCodeSettingsError: LocalizedError {
    case missingCookie
    case invalidCookie

    var errorDescription: String? {
        switch self {
        case .missingCookie:
            "No OpenCode session cookies found. Configure manual cookie in settings."
        case .invalidCookie:
            "OpenCode cookie header is invalid."
        }
    }
}
