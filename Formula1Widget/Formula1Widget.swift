import SwiftUI
import WidgetKit

struct Formula1TimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: F1WidgetSnapshot
}

struct Formula1TimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> Formula1TimelineEntry {
        Formula1TimelineEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (Formula1TimelineEntry) -> Void) {
        completion(Formula1TimelineEntry(date: Date(), snapshot: .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Formula1TimelineEntry>) -> Void) {
        Task {
            let service = OpenF1Service()
            let snapshot = await service.loadSnapshot()
            let nextRefresh = refreshDate(for: snapshot)
            let entry = Formula1TimelineEntry(date: Date(), snapshot: snapshot)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private func refreshDate(for snapshot: F1WidgetSnapshot) -> Date {
        let now = Date()

        if snapshot.status == .live || snapshot.status == .raceWeekend {
            return now.addingTimeInterval(15 * 60)
        }

        if let nextSession = snapshot.nextSession {
            let secondsUntilStart = nextSession.startsAt.timeIntervalSince(now)
            if secondsUntilStart < 6 * 3_600 {
                return now.addingTimeInterval(30 * 60)
            }
            return now.addingTimeInterval(3 * 3_600)
        }

        return now.addingTimeInterval(6 * 3_600)
    }
}

struct Formula1WidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: Formula1TimelineEntry

    var body: some View {
        F1WidgetCardView(snapshot: entry.snapshot, family: cardFamily)
            .containerBackground(.clear, for: .widget)
            .widgetURL(URL(string: "formula1update://race"))
    }

    private var cardFamily: F1WidgetFamily {
        switch widgetFamily {
        case .systemSmall:
            return .small
        case .systemLarge, .systemExtraLarge:
            return .large
        default:
            return .medium
        }
    }
}

@main
struct Formula1Widget: Widget {
    let kind = "Formula1Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Formula1TimelineProvider()) { entry in
            Formula1WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Formula 1 Update")
        .description("Next race timing and the latest Formula 1 session result.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
