import Foundation

/// A provider as the widget picker and timeline see it. Both the bridge record and the extension's
/// presentation model conform, so the selection rules below are shared and unit-tested here.
public protocol WidgetSelectableProvider {
    var id: String { get }
    var displayName: String { get }
    var isEnabled: Bool { get }
}

extension WidgetProviderRecord: WidgetSelectableProvider {}

public enum WidgetBridgeReadStatus: Sendable {
    case loaded
    case missing
    case corrupt
    case unsupported
}

/// Which providers a widget offers and shows. The list is whatever the host exported, so new providers
/// and extra account cards need no extension changes.
public enum WidgetProviderSelection {
    public struct Option: Hashable, Sendable {
        public let id: String
        public let name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    public enum Entry<Provider: WidgetSelectableProvider> {
        case provider(Provider)
        case missingData(String?)
        case corruptData(String?)
        case unsupportedData(String?)
        case missingProvider(String)

        public var providerID: String? {
            switch self {
            case .provider(let provider): provider.id
            case .missingData(let id), .corruptData(let id), .unsupportedData(let id): id
            case .missingProvider(let id): id
            }
        }
    }

    /// Bridge errors take precedence even before a widget has a saved provider. Only a loaded bridge
    /// can choose the default provider or report that the saved provider is no longer exported.
    public static func entry<P: WidgetSelectableProvider>(
        configuredID: String?,
        bridgeStatus: WidgetBridgeReadStatus,
        in providers: [P]
    ) -> Entry<P> {
        switch bridgeStatus {
        case .missing:
            return .missingData(configuredID)
        case .corrupt:
            return .corruptData(configuredID)
        case .unsupported:
            return .unsupportedData(configuredID)
        case .loaded:
            guard let selectedID = configuredID ?? defaultProviderID(in: providers) else {
                return .missingData(nil)
            }
            guard let provider = providers.first(where: { $0.id == selectedID }) else {
                return .missingProvider(selectedID)
            }
            return .provider(provider)
        }
    }

    /// Resolves saved picker ids. An id the host no longer exports (a removed account card, or no bridge
    /// file yet) keeps a placeholder named by its id, so the widget reports it missing instead of
    /// silently switching to another provider.
    public static func resolve(
        _ ids: [String],
        in providers: [some WidgetSelectableProvider]
    ) -> [Option] {
        ids.map { id in
            Option(id: id, name: providers.first { $0.id == id }?.displayName ?? id)
        }
    }

    /// Enabled providers first; every exported provider when none is enabled.
    public static func suggested<P: WidgetSelectableProvider>(in providers: [P]) -> [P] {
        let enabled = providers.filter(\.isEnabled)
        return enabled.isEmpty ? providers : enabled
    }

    /// The provider an unconfigured widget shows.
    public static func defaultProviderID(in providers: [some WidgetSelectableProvider]) -> String? {
        suggested(in: providers).first?.id
    }
}

extension WidgetProviderSelection.Entry: Equatable where Provider: Equatable {}
extension WidgetProviderSelection.Entry: Sendable where Provider: Sendable {}
