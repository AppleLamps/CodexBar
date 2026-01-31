import CodexBarMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum AugmentProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        let browserOrder: BrowserCookieImportOrder? = Browser.defaultImportOrder

        return ProviderDescriptor(
            id: .augment,
            metadata: ProviderMetadata(
                id: .augment,
                displayName: "Augment",
                sessionLabel: "Credits",
                weeklyLabel: "Usage",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: true,
                creditsHint: "Augment Code credits for AI-powered coding assistance.",
                toggleTitle: "Show Augment usage",
                cliName: "augment",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                browserCookieOrder: browserOrder,
                dashboardURL: "https://app.augmentcode.com/account/subscription",
                statusPageURL: nil,
                statusLinkURL: nil),
            branding: ProviderBranding(
                iconStyle: .augment,
                iconResourceName: "ProviderIcon-augment",
                color: ProviderColor(red: 99 / 255, green: 102 / 255, blue: 241 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Augment cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in
                    // TODO: Implement Windows fetch strategies
                    []
                })),
            cli: ProviderCLIConfig(
                name: "augment",
                versionDetector: nil))
    }
}
