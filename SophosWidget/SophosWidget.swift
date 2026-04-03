import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct SophosEntry: TimelineEntry {
    let date: Date
    let alertCount: Int
    let highAlerts: Int
    let healthScore: Int
    let healthStatus: String
    let deviceCount: Int
    let unhealthyDevices: Int
}

// MARK: - Timeline Provider

struct SophosProvider: TimelineProvider {
    func placeholder(in context: Context) -> SophosEntry {
        SophosEntry(date: .now, alertCount: 5, highAlerts: 2, healthScore: 88,
                    healthStatus: "Healthy", deviceCount: 10, unhealthyDevices: 1)
    }

    func getSnapshot(in context: Context, completion: @escaping (SophosEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SophosEntry>) -> Void) {
        // Read cached data from shared UserDefaults (app group)
        let defaults = UserDefaults(suiteName: "group.com.sophos.central.mobile") ?? .standard
        let entry = SophosEntry(
            date: .now,
            alertCount: defaults.integer(forKey: "widget_alert_count"),
            highAlerts: defaults.integer(forKey: "widget_high_alerts"),
            healthScore: defaults.integer(forKey: "widget_health_score"),
            healthStatus: defaults.string(forKey: "widget_health_status") ?? "Unknown",
            deviceCount: defaults.integer(forKey: "widget_device_count"),
            unhealthyDevices: defaults.integer(forKey: "widget_unhealthy_devices")
        )

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Small Widget

struct SophosWidgetSmallView: View {
    let entry: SophosEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundStyle(.blue)
                    .font(.system(size: 14))
                Text("SOPHOS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Health score
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: Double(entry.healthScore) / 100.0)
                        .stroke(scoreColor(entry.healthScore), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    Text("\(entry.healthScore)")
                        .font(.system(size: 14, weight: .bold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.healthStatus)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(scoreColor(entry.healthScore))
                    Text("\(entry.deviceCount) devices")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Alert summary
            HStack {
                if entry.highAlerts > 0 {
                    HStack(spacing: 3) {
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text("\(entry.highAlerts)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.red)
                    }
                }
                Text("\(entry.alertCount) alerts")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func scoreColor(_ score: Int) -> Color {
        score >= 80 ? .green : score >= 50 ? .orange : .red
    }
}

// MARK: - Medium Widget

struct SophosWidgetMediumView: View {
    let entry: SophosEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: Health score
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 5)
                        .frame(width: 60, height: 60)
                    Circle()
                        .trim(from: 0, to: Double(entry.healthScore) / 100.0)
                        .stroke(scoreColor(entry.healthScore), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    Text("\(entry.healthScore)")
                        .font(.system(size: 20, weight: .bold))
                }
                Text(entry.healthStatus)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(scoreColor(entry.healthScore))
            }

            // Right: Stats
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundStyle(.blue)
                    Text("SOPHOS CENTRAL")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                statRow(icon: "bell.badge", color: .red, label: "High Alerts", value: "\(entry.highAlerts)")
                statRow(icon: "bell", color: .orange, label: "Total Alerts", value: "\(entry.alertCount)")
                statRow(icon: "laptopcomputer", color: .blue, label: "Devices", value: "\(entry.deviceCount)")
                if entry.unhealthyDevices > 0 {
                    statRow(icon: "exclamationmark.triangle", color: .orange, label: "Issues", value: "\(entry.unhealthyDevices)")
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func statRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 11))
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold))
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        score >= 80 ? .green : score >= 50 ? .orange : .red
    }
}

// MARK: - Widget Configuration

struct SophosWidget: Widget {
    let kind: String = "SophosWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SophosProvider()) { entry in
            if #available(iOS 17.0, *) {
                SophosWidgetEntryView(entry: entry)
            } else {
                SophosWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Sophos Central")
        .description("Monitor your security health score and alert status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SophosWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SophosEntry

    var body: some View {
        switch family {
        case .systemMedium:
            SophosWidgetMediumView(entry: entry)
        default:
            SophosWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct SophosWidgetBundle: WidgetBundle {
    var body: some Widget {
        SophosWidget()
    }
}
