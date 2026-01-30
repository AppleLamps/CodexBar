import CodexBarMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum MiniMaxProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .minimax,
            metadata: ProviderMetadata(
                id: .minimax,
                displayName: "MiniMax",
                sessionLabel: "Prompts",
                weeklyLabel: "Window",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show MiniMax usage",
                cliName: "minimax",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                browserCookieOrder: ProviderBrowserCookieDefaults.defaultImportOrder,
                dashboardURL: "https://platform.minimax.io/user-center/payment/coding-plan?cycle_type=3",
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .minimax,
                iconResourceName: "ProviderIcon-minimax",
                color: ProviderColor(red: 254 / 255, green: 96 / 255, blue: 60 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "MiniMax cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .api],
                pipeline: ProviderFetchPipeline(resolveStrategies: self.resolveStrategies)),
            cli: ProviderCLIConfig(
                name: "minimax",
                aliases: ["mini-max"],
                versionDetector: nil))
    }

    private static func resolveStrategies(context: ProviderFetchContext) async -> [any ProviderFetchStrategy] {
        switch context.sourceMode {
        case .api:
            return [MiniMaxAPIFetchStrategy()]
        case .web, .cli, .oauth:
            return []
        case .auto:
            break
        }
        let apiToken = ProviderTokenResolver.minimaxToken(environment: context.env)
        if apiToken != nil {
            return [MiniMaxAPIFetchStrategy()]
        }
        return []
    }
}

struct MiniMaxAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "minimax.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        let authMode = MiniMaxAuthMode.resolve(
            apiToken: ProviderTokenResolver.minimaxToken(environment: context.env),
            cookieHeader: ProviderTokenResolver.minimaxCookie(environment: context.env))
        if let kind = MiniMaxAPISettingsReader.apiKeyKind(environment: context.env),
           kind == .standard
        {
            return false
        }
        return authMode.usesAPIToken
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let apiToken = ProviderTokenResolver.minimaxToken(environment: context.env) else {
            throw MiniMaxAPISettingsError.missingToken
        }
        let usage = try await MiniMaxUsageFetcher.fetchUsage(apiToken: apiToken)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: "api")
    }

    func shouldFallback(on error: Error, context _: ProviderFetchContext) -> Bool {
        guard let minimaxError = error as? MiniMaxUsageError else { return false }
        switch minimaxError {
        case .invalidCredentials:
            return true
        case let .apiError(message):
            return message.contains("HTTP 404")
        case .networkError, .parseFailed:
            return false
        }
    }
}
