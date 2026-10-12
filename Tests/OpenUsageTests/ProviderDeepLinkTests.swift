import XCTest
@testable import OpenUsage

final class ProviderDeepLinkTests: XCTestCase {
    private let knownProviderIDs: Set<String> = ["claude", "codex", "codex@active", "openrouter"]

    func testParsesReleaseAndDevelopmentProviderLinks() throws {
        XCTAssertEqual(
            ProviderDeepLink.parse(
                try XCTUnwrap(URL(string: "openusage://provider/claude")),
                expectedScheme: "openusage",
                knownProviderIDs: knownProviderIDs
            ),
            .provider("claude")
        )
        XCTAssertEqual(
            ProviderDeepLink.parse(
                try XCTUnwrap(URL(string: "openusage-dev://provider/openrouter")),
                expectedScheme: "openusage-dev",
                knownProviderIDs: knownProviderIDs
            ),
            .provider("openrouter")
        )
    }

    func testRoutesMissingAndRemovedProvidersToRecovery() throws {
        for scheme in ["openusage", "openusage-dev"] {
            for path in ["", "/", "/unknown", "/codex@removed"] {
                XCTAssertEqual(
                    ProviderDeepLink.parse(
                        try XCTUnwrap(URL(string: "\(scheme)://provider\(path)")),
                        expectedScheme: scheme,
                        knownProviderIDs: knownProviderIDs
                    ),
                    .recovery,
                    "Expected dashboard recovery for \(scheme)://provider\(path)"
                )
            }
            XCTAssertEqual(
                ProviderDeepLink.parse(
                    try XCTUnwrap(URL(string: "\(scheme)://provider/codex@active")),
                    expectedScheme: scheme,
                    knownProviderIDs: knownProviderIDs
                ),
                .provider("codex@active"),
                "An account still in the registry must retain its provider destination"
            )
        }
    }

    func testRejectsUnsupportedURLShapes() throws {
        let invalidURLs = [
            "https://provider/claude",
            "openusage://other/claude",
            "openusage://provider/claude/extra",
            "openusage://provider/unknown/extra",
            "openusage://provider/claude?source=widget",
            "openusage://provider/claude#fragment",
            "openusage://user@provider/claude",
            "openusage://user:password@provider/claude",
            "openusage://provider:123/claude",
            "openusage://provider?source=widget",
            "openusage://provider#fragment",
        ]

        for string in invalidURLs {
            let url = try XCTUnwrap(URL(string: string))
            XCTAssertNil(
                ProviderDeepLink.parse(
                    url,
                    expectedScheme: "openusage",
                    knownProviderIDs: knownProviderIDs
                ),
                "Expected rejection for \(string)"
            )
        }
    }

    func testRejectsOtherBuildScheme() throws {
        XCTAssertNil(
            ProviderDeepLink.parse(
                try XCTUnwrap(URL(string: "openusage-dev://provider/claude")),
                expectedScheme: "openusage",
                knownProviderIDs: knownProviderIDs
            )
        )
        XCTAssertNil(
            ProviderDeepLink.parse(
                try XCTUnwrap(URL(string: "openusage://provider/claude")),
                expectedScheme: "openusage-dev",
                knownProviderIDs: knownProviderIDs
            )
        )
    }

    func testRejectsUnexpectedConfiguredScheme() throws {
        XCTAssertNil(
            ProviderDeepLink.parse(
                try XCTUnwrap(URL(string: "https://provider/claude")),
                expectedScheme: "https",
                knownProviderIDs: knownProviderIDs
            ),
            "Only the two declared OpenUsage scheme values are valid"
        )
    }

    func testDestinationRequiresEnablementAndVisibleMetricsForDashboard() {
        XCTAssertEqual(
            ProviderDeepLinkDestination.resolve(isEnabled: true, hasVisibleMetrics: true),
            .dashboard
        )
        XCTAssertEqual(
            ProviderDeepLinkDestination.resolve(isEnabled: false, hasVisibleMetrics: true),
            .customize
        )
        XCTAssertEqual(
            ProviderDeepLinkDestination.resolve(isEnabled: true, hasVisibleMetrics: false),
            .customize
        )
        XCTAssertEqual(
            ProviderDeepLinkDestination.resolve(isEnabled: false, hasVisibleMetrics: false),
            .customize
        )
    }

    @MainActor
    func testDashboardFocusRequestValidatesAndRepeatsKnownProvider() {
        let suite = "OpenUsageTests.ProviderDeepLink.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LayoutStore(
            registry: .mock,
            defaults: defaults,
            storageKey: "layout",
            defaultMetricIDs: []
        )

        XCTAssertFalse(store.requestDashboardProviderFocus("unknown"))
        XCTAssertNil(store.dashboardFocusProviderID)
        XCTAssertEqual(store.dashboardFocusRequestID, 0)

        XCTAssertTrue(store.requestDashboardProviderFocus("claude"))
        XCTAssertEqual(store.dashboardFocusProviderID, "claude")
        XCTAssertEqual(store.dashboardFocusRequestID, 1)

        XCTAssertTrue(store.requestDashboardProviderFocus("claude"))
        XCTAssertEqual(store.dashboardFocusRequestID, 2, "same-provider links must retrigger scrolling")
    }

    @MainActor
    func testDashboardFocusAcknowledgementOnlyClearsMatchingRequest() {
        let suite = "OpenUsageTests.ProviderDeepLink.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LayoutStore(
            registry: .mock,
            defaults: defaults,
            storageKey: "layout",
            defaultMetricIDs: []
        )

        XCTAssertTrue(store.requestDashboardProviderFocus("claude"))
        let firstRequestID = store.dashboardFocusRequestID
        XCTAssertTrue(store.requestDashboardProviderFocus("codex"))

        store.acknowledgeDashboardProviderFocus(requestID: firstRequestID)
        XCTAssertEqual(store.dashboardFocusProviderID, "codex", "an older callback must preserve a newer request")

        store.acknowledgeDashboardProviderFocus(requestID: store.dashboardFocusRequestID)
        XCTAssertNil(store.dashboardFocusProviderID, "a handled request must not replay when the dashboard remounts")
    }
}
