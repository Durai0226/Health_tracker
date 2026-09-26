import AppIntents
import SwiftUI
import WidgetKit

/// App Group shared with Runner. Both targets carry the entitlement, and
/// `HomeWidget.setAppGroupId` on the Dart side writes into the same suite.
private let appGroupId = "group.com.implementation.tabletremainder.tabletRemainder"

private func sharedDefaults() -> UserDefaults? {
    UserDefaults(suiteName: appGroupId)
}

// MARK: - Timeline

struct HydrationEntry: TimelineEntry {
    let date: Date
    let intakeMl: Int
    let goalMl: Int
    let restricted: Bool

    var progress: Double {
        guard goalMl > 0 else { return 0 }
        return min(1.0, max(0.0, Double(intakeMl) / Double(goalMl)))
    }
}

struct HydrationProvider: TimelineProvider {
    /// Shown in the widget gallery, so it must look plausible rather than empty.
    func placeholder(in context: Context) -> HydrationEntry {
        HydrationEntry(date: Date(), intakeMl: 1250, goalMl: 2960, restricted: false)
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (HydrationEntry) -> Void) {
        completion(read())
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<HydrationEntry>) -> Void) {
        // A single entry refreshed on write: the Dart side calls
        // `HomeWidget.updateWidget` whenever a drink is logged, which reloads
        // the timeline. The hourly policy is only a backstop for the case where
        // the app has not been opened.
        let entry = read()
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: entry.date)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func read() -> HydrationEntry {
        let d = sharedDefaults()
        return HydrationEntry(
            date: Date(),
            intakeMl: d?.integer(forKey: "waterMl") ?? 0,
            goalMl: d?.integer(forKey: "waterGoalMl") ?? 0,
            restricted: d?.bool(forKey: "waterRestricted") ?? false
        )
    }
}

// MARK: - Quick-add intent

/// Logs a glass without opening the app.
///
/// Interactive widgets are iOS 17+ and must go through App Intents. Like the
/// Android widget button and the notification action, this cannot reach the
/// app's database from an extension — it appends to a shared queue that the app
/// drains on next launch, so all three entry points converge on one code path
/// with one confirmation and one Undo.
@available(iOS 17.0, *)
struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log water"
    static var description = IntentDescription("Log a 250 ml glass of water.")

    /// Keep the widget in place rather than foregrounding the app — the entire
    /// point is logging without a context switch.
    static var openAppWhenRun: Bool = false

    /// Key the app drains on next launch.
    ///
    /// Deliberately NOT `flutter.pending_water_actions`. That is
    /// `shared_preferences`' key, and on iOS shared_preferences reads
    /// `UserDefaults.standard` — not this App Group suite — so writing there
    /// from an extension would land somewhere the app never looks. Instead this
    /// uses its own key in the shared suite, which `home_widget` can read, and
    /// the Dart side moves it into `WaterActionQueue`.
    static let queueKey = "widgetWaterQueue"

    func perform() async throws -> some IntentResult {
        if let d = sharedDefaults() {
            // Newline-separated "ml@iso8601" records. A plain string because
            // home_widget's bridge carries String/int/double/bool, not arrays.
            let iso = ISO8601DateFormatter().string(from: Date())
            let existing = d.string(forKey: Self.queueKey) ?? ""
            let entry = "250@\(iso)"
            d.set(existing.isEmpty ? entry : existing + "\n" + entry,
                  forKey: Self.queueKey)

            // Optimistic local bump so the widget reflects the tap immediately;
            // the app's next push overwrites it with the real total.
            d.set(d.integer(forKey: "waterMl") + 250, forKey: "waterMl")
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "WaterWidget")
        return .result()
    }
}

// MARK: - View

struct WaterWidgetView: View {
    var entry: HydrationEntry

    private var label: String {
        if entry.goalMl <= 0 { return "\(entry.intakeMl) ml" }
        return entry.restricted
            ? "\(entry.intakeMl) of \(entry.goalMl) ml limit"
            : "\(entry.intakeMl) / \(entry.goalMl) ml"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("💧")
                Text(entry.restricted ? "Fluid limit" : "Water")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(label)
                .font(.headline)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            ProgressView(value: entry.progress)
                .tint(entry.restricted ? .orange : .blue)

            // No quick-add under a prescribed fluid ceiling: offering one-tap
            // "+250 ml" to someone told to limit their intake is exactly the
            // harm the restriction mode exists to prevent.
            if #available(iOS 17.0, *), !entry.restricted {
                Button(intent: LogWaterIntent()) {
                    Text("+250 ml").font(.caption).bold()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
    }
}

// MARK: - Widget

struct WaterWidget: Widget {
    let kind = "WaterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HydrationProvider()) { entry in
            if #available(iOS 17.0, *) {
                WaterWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                WaterWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Water")
        .description("Today's hydration, with one-tap logging.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct WaterWidgetBundle: WidgetBundle {
    var body: some Widget {
        WaterWidget()
    }
}
