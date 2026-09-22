import Foundation

/// A provider as the widget picker and timeline see it. Both the bridge record and the extension's
/// presentation model conform, so the selection rules below are shared and unit-tested here.
public protocol WidgetSelectableProvider {
    var id: String { get }
    var displayName: String { get }
    var isEnabled: Bool { get }
}

extension WidgetProviderRecord: WidgetSelectableProvider {}

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
