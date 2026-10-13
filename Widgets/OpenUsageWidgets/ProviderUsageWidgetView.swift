import OpenUsageWidgetSupport
import SwiftUI
import WidgetKit

struct ProviderUsageWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ProviderUsageEntry

    var body: some View {
        Group {
            switch entry.selection {
            case .provider(let provider):
                if !provider.isEnabled {
                    WidgetMessageView(
                        title: "Provider Disabled",
                        message: "Enable \(provider.displayName) in OpenUsage to show its metrics.",
                        symbol: "slider.horizontal.3"
                    )
                } else if provider.health == .noData || selectedMetrics(for: provider).isEmpty {
                    WidgetMessageView(
                        title: "No Data",
                        message: "Open OpenUsage to refresh \(provider.displayName).",
                        symbol: "chart.bar.xaxis"
                    )
                } else {
                    ProviderContentView(
                        provider: provider,
                        metrics: selectedMetrics(for: provider),
                        isStale: entry.isStale,
                        family: family
                    )
                }
            case .missingData:
                WidgetMessageView(
                    title: "Open OpenUsage",
                    message: "Launch the app once to make usage available.",
                    symbol: "arrow.up.forward.app"
                )
            case .corruptData:
                WidgetMessageView(
                    title: "Unable to Read Data",
                    message: "Open OpenUsage to refresh the widget.",
                    symbol: "exclamationmark.triangle"
                )
            case .unsupportedData:
                WidgetMessageView(
                    title: "Update Required",
                    message: "Update OpenUsage to refresh this widget.",
                    symbol: "arrow.triangle.2.circlepath"
                )
            case .missingProvider:
                WidgetMessageView(
                    title: "Provider Unavailable",
                    message: "Choose another provider or open OpenUsage.",
                    symbol: "questionmark.app"
                )
            }
        }
        .widgetURL(WidgetHostURL.provider(entry.selection.providerID))
    }

    private func selectedMetrics(for provider: WidgetProviderRecord) -> [WidgetMetricRecord] {
        let primary = provider.primaryMetrics.filter(\.hasData)
        let secondary = provider.secondaryMetrics.filter(\.hasData)

        switch family {
        case .systemSmall:
            return Array((primary.isEmpty ? secondary : primary).prefix(2))
        case .systemMedium:
            return Array((primary.isEmpty ? secondary : primary).prefix(4))
        case .systemLarge:
            if primary.isEmpty { return Array(secondary.prefix(8)) }
            let selectedPrimary = Array(primary.prefix(6))
            return selectedPrimary + secondary.prefix(8 - selectedPrimary.count)
        default:
            return Array((primary.isEmpty ? secondary : primary).prefix(2))
        }
    }
}

private struct ProviderContentView: View {
    let provider: WidgetProviderRecord
    let metrics: [WidgetMetricRecord]
    let isStale: Bool
    let family: WidgetFamily

    private var columns: [GridItem] {
        family == .systemSmall
            ? [GridItem(.flexible(), spacing: 8)]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 14 : 10) {
            ProviderWidgetHeader(
                provider: provider,
                isStale: isStale,
                compact: family != .systemLarge
            )

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(metrics) { metric in
                    WidgetMetricView(metric: metric, compact: family != .systemLarge)
                }
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct ProviderWidgetHeader: View {
    let provider: WidgetProviderRecord
    let isStale: Bool
    let compact: Bool

    var body: some View {
        HStack(spacing: 8) {
            ProviderIconView(iconID: provider.iconID ?? provider.id)
                .frame(width: 19, height: 19)

            if compact {
                providerTitle
                Spacer(minLength: 0)
                compactStatus
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    providerTitle

                    detailedStatus
                        .font(.caption2)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var providerTitle: some View {
        HStack(spacing: 5) {
            Text(provider.displayName)
                .font(.headline)
                .lineLimit(1)
            if let plan = provider.plan, !plan.isEmpty {
                Text(plan)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var status: (title: LocalizedStringKey, symbol: String, color: Color)? {
        switch (provider.health, isStale) {
        case (.failed, _): ("Refresh Failed", "exclamationmark.circle.fill", .red)
        case (.warning, _): ("Warning", "exclamationmark.triangle.fill", .orange)
        case (_, true): ("Outdated", "clock.badge.exclamationmark", .orange)
        default: nil
        }
    }

    @ViewBuilder
    private var compactStatus: some View {
        if let status {
            Image(systemName: status.symbol)
                .foregroundStyle(status.color)
                .accessibilityLabel(Text(status.title))
        }
    }

    @ViewBuilder
    private var detailedStatus: some View {
        if let status {
            Label(status.title, systemImage: status.symbol)
                .foregroundStyle(status.color)
        } else if let refreshedAt = provider.refreshedAt {
            HStack(spacing: 2) {
                Text("Updated")
                Text(refreshedAt, style: .relative)
            }
            .foregroundStyle(.secondary)
        }
    }
}

private struct WidgetMetricView: View {
    let metric: WidgetMetricRecord
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            Text(metric.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if compact {
                HStack(spacing: 4) {
                    headline
                    Spacer(minLength: 2)
                    if let resetAt = metric.resetAt {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                            Text(resetAt, style: .relative)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                }
            } else {
                headline
            }

            if metric.kind == .progress, let progress = metric.progressFraction {
                ProgressView(value: min(max(progress, 0), 1))
                    .tint(severityColor)
            }

            if !compact, let detail = metric.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if !compact, let resetAt = metric.resetAt {
                HStack(spacing: 2) {
                    Text("Resets")
                    Text(resetAt, style: .relative)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var headline: some View {
        Text(metric.headline)
            .font(compact ? .subheadline : .headline)
            .fontWeight(.semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }

    private var severityColor: Color {
        switch metric.severity {
        case .critical: .red
        case .warning: .orange
        case .normal: .accentColor
        case .neutral: .secondary
        }
    }
}

private struct WidgetMessageView: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Spacer(minLength: 0)
            Text("Open OpenUsage")
                .font(.caption)
                .foregroundStyle(.tint)
        }
    }
}

enum WidgetHostURL {
    static func provider(_ providerID: String?) -> URL? {
        guard
            let scheme = Bundle.main.object(
                forInfoDictionaryKey: "OpenUsageURLScheme"
            ) as? String,
            !scheme.isEmpty
        else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.host = "provider"
        if let providerID { components.path = "/\(providerID)" }
        return components.url
    }
}

#Preview("Small", as: .systemSmall) {
    ProviderUsageWidget()
} timeline: {
    ProviderUsageEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    ProviderUsageWidget()
} timeline: {
    ProviderUsageEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    ProviderUsageWidget()
} timeline: {
    ProviderUsageEntry.placeholder
}
