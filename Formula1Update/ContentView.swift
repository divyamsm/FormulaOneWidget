import SwiftUI
import WidgetKit

struct ContentView: View {
    @StateObject private var store = F1SnapshotStore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Medium Widget", subtitle: "Best default layout")
                        F1WidgetCardView(snapshot: store.snapshot, family: .medium)
                            .frame(height: 176)
                    }

                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Small", subtitle: "Glanceable")
                            F1WidgetCardView(snapshot: store.snapshot, family: .small)
                                .frame(width: 158, height: 158)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Data", subtitle: store.snapshot.attribution)
                            dataPanel
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Large Widget", subtitle: "Race weekend dashboard")
                        F1WidgetCardView(snapshot: store.snapshot, family: .large)
                            .frame(height: 344)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Formula 1 Update")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await store.refresh()
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    } label: {
                        if store.isLoading {
                            ProgressView()
                        } else {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(store.isLoading)
                }
            }
            .task {
                await store.refresh()
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.snapshot.status.label.uppercased())
                .font(.caption.weight(.black))
                .foregroundStyle(.red)
            Text(store.snapshot.raceName)
                .font(.largeTitle.weight(.black))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            Text(store.snapshot.location)
                .font(.headline.weight(.medium))
                .foregroundStyle(.secondary)
            if let nextSession = store.snapshot.nextSession {
                Text("\(nextSession.name) starts \(F1Formatters.raceDate.string(from: nextSession.startsAt))")
                    .font(.subheadline.weight(.semibold))
            } else if let error = store.snapshot.errorMessage {
                Text(error)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dataPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            InfoRow(label: "Circuit", value: store.snapshot.circuitName)
            if let nextSession = store.snapshot.nextSession {
                InfoRow(label: "Next", value: nextSession.shortName)
                InfoRow(label: "Starts", value: F1Formatters.raceDate.string(from: nextSession.startsAt))
            }
            if let result = store.snapshot.lastResult, let winner = result.topThree.first {
                InfoRow(label: "Last", value: "\(result.sessionShortName) \(winner.driverCode)")
            }
            if let error = store.snapshot.errorMessage {
                InfoRow(label: "Error", value: error)
            }
            InfoRow(label: "Updated", value: F1Formatters.shortDate.string(from: store.snapshot.updatedAt))
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 158, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline.weight(.bold))
            Spacer()
            Text(subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}
