import XCTest
import OpenUsageWidgetSupport

final class WidgetProviderSelectionTests: XCTestCase {
    private let providers = [
        makeProvider("claude", "Claude", enabled: false),
        makeProvider("codex", "Codex", enabled: true),
        makeProvider("codex-2", "Codex (Personal)", enabled: true),
    ]

    func testResolvesExportedIDsInRequestedOrder() {
        XCTAssertEqual(
            WidgetProviderSelection.resolve(["codex-2", "claude"], in: providers),
            [.init(id: "codex-2", name: "Codex (Personal)"), .init(id: "claude", name: "Claude")]
        )
    }

    func testKeepsAnIDTheHostNoLongerExports() {
        // A removed account card must stay selected so the widget reports it missing instead of
        // silently falling back to another provider.
        XCTAssertEqual(
            WidgetProviderSelection.resolve(["claude-work"], in: providers),
            [.init(id: "claude-work", name: "claude-work")]
        )
        XCTAssertEqual(
            WidgetProviderSelection.resolve(["claude"], in: [WidgetProviderRecord]()),
            [.init(id: "claude", name: "claude")]
        )
    }

    func testSuggestsEnabledProvidersAndFallsBackToAll() {
        XCTAssertEqual(WidgetProviderSelection.suggested(in: providers).map(\.id), ["codex", "codex-2"])

        let allDisabled = [makeProvider("claude", "Claude", enabled: false), makeProvider("zai", "Z.ai", enabled: false)]
        XCTAssertEqual(WidgetProviderSelection.suggested(in: allDisabled).map(\.id), ["claude", "zai"])
    }

    func testDefaultsToFirstEnabledThenFirstExported() {
        XCTAssertEqual(WidgetProviderSelection.defaultProviderID(in: providers), "codex")
        XCTAssertEqual(
            WidgetProviderSelection.defaultProviderID(in: [makeProvider("claude", "Claude", enabled: false)]),
            "claude"
        )
        XCTAssertNil(WidgetProviderSelection.defaultProviderID(in: [WidgetProviderRecord]()))
    }
}

private func makeProvider(_ id: String, _ name: String, enabled: Bool) -> WidgetProviderRecord {
    WidgetProviderRecord(
        id: id, displayName: name, iconID: nil, isEnabled: enabled, plan: nil, refreshedAt: nil,
        health: .noData, primaryMetrics: [], secondaryMetrics: []
    )
}
