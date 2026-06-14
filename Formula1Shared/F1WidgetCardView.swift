import SwiftUI

struct F1WidgetCardView: View {
    let snapshot: F1WidgetSnapshot
    let family: F1WidgetFamily

    var body: some View {
        ZStack(alignment: .topLeading) {
            F1Background()

            switch family {
            case .small:
                SmallF1Card(snapshot: snapshot)
            case .medium:
                MediumF1Card(snapshot: snapshot)
            case .large:
                LargeF1Card(snapshot: snapshot)
            }
        }
        .containerShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

enum F1WidgetFamily {
    case small
    case medium
    case large
}

private struct SmallF1Card: View {
    let snapshot: F1WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                StatusBadge(status: snapshot.status, compact: true)
                Spacer(minLength: 0)
                Text(snapshot.countryCode ?? "F1")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(F1Theme.muted)
            }

            Spacer(minLength: 0)

            Text(snapshot.raceName)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(F1Theme.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            if snapshot.status == .unavailable {
                Text(snapshot.errorMessage ?? "Check connection")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(F1Theme.secondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            } else if let nextSession = snapshot.nextSession {
                Text(F1Formatters.countdown(to: nextSession.startsAt))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(F1Theme.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(nextSession.shortName) \(F1Formatters.raceDate.string(from: nextSession.startsAt))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(F1Theme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else if let result = snapshot.lastResult, let winner = result.topThree.first {
                Text("\(winner.driverCode) P1")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(F1Theme.primary)
                Text(result.sessionShortName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(F1Theme.secondary)
            } else {
                Text("Schedule TBA")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(F1Theme.primary)
            }
        }
        .padding(15)
    }
}

private struct MediumF1Card: View {
    let snapshot: F1WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                StatusBadge(status: snapshot.status)
                Spacer(minLength: 8)
                Text(snapshot.countryCode ?? "F1")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(F1Theme.secondary)
            }

            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(snapshot.raceName)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(F1Theme.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(snapshot.location)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(F1Theme.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    if snapshot.status == .unavailable {
                        Text(snapshot.errorMessage ?? "Check connection")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(F1Theme.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                            .padding(.top, 2)
                    } else if let nextSession = snapshot.nextSession {
                        Text("\(nextSession.shortName) \(F1Formatters.raceDate.string(from: nextSession.startsAt))")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(F1Theme.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.top, 4)

                        Text("\(F1Formatters.countdown(to: nextSession.startsAt)) remaining")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(F1Theme.accent)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ResultPanel(result: snapshot.lastResult, compact: true)
                    .frame(width: 138, alignment: .topLeading)
            }
        }
        .padding(15)
    }
}

private struct LargeF1Card: View {
    let snapshot: F1WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    StatusBadge(status: snapshot.status)
                    Text(snapshot.raceName)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(F1Theme.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(snapshot.location)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(F1Theme.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                Text(snapshot.countryCode ?? "F1")
                    .font(.caption.weight(.black))
                    .foregroundStyle(F1Theme.secondary)
            }

            if snapshot.status == .unavailable {
                Text(snapshot.errorMessage ?? "Check connection")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(F1Theme.secondary)
                    .lineLimit(4)
                    .minimumScaleFactor(0.75)
            } else if let nextSession = snapshot.nextSession {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next \(nextSession.shortName)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(F1Theme.secondary)
                        Text(F1Formatters.raceDate.string(from: nextSession.startsAt))
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(F1Theme.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    Spacer()
                    Text(F1Formatters.countdown(to: nextSession.startsAt))
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(F1Theme.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(F1Theme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack(alignment: .top, spacing: 10) {
                if !snapshot.weekendSchedule.isEmpty {
                    ScheduleList(sessions: Array(snapshot.weekendSchedule.prefix(5)), nextSession: snapshot.nextSession, compact: true)
                        .frame(width: 156, alignment: .topLeading)
                }

                ResultPanel(result: snapshot.lastResult, compact: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            Spacer(minLength: 0)
            Text(F1Formatters.updatedText(snapshot.updatedAt))
                .font(.caption2.weight(.medium))
                .foregroundStyle(F1Theme.muted)
        }
        .padding(15)
    }
}

private struct ResultPanel: View {
    let result: F1SessionResultSummary?
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            Text(result.map { "Last \($0.sessionShortName)" } ?? "Last Session")
                .font(.system(size: compact ? 11 : 12, weight: .black))
                .foregroundStyle(F1Theme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if let result, !result.topThree.isEmpty {
                ForEach(result.topThree) { driver in
                    HStack(spacing: compact ? 5 : 8) {
                        Text("\(driver.position)")
                            .font(.system(size: compact ? 12 : 13, weight: .black, design: .rounded))
                            .foregroundStyle(F1Theme.accent)
                            .frame(width: compact ? 13 : 16, alignment: .leading)
                        Text(driver.driverCode)
                            .font(.system(size: compact ? 13 : 14, weight: .black, design: .rounded))
                            .foregroundStyle(F1Theme.primary)
                            .frame(width: compact ? 31 : 36, alignment: .leading)
                        Text(driver.displayValue)
                            .font(.system(size: compact ? 10 : 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(F1Theme.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.vertical, compact ? 1 : 2)
                }
            } else {
                Text("Results pending")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(F1Theme.secondary)
            }
        }
        .padding(compact ? 10 : 12)
        .background(F1Theme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ScheduleList: View {
    let sessions: [F1SessionSummary]
    let nextSession: F1SessionSummary?
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 3 : 5) {
            ForEach(sessions) { session in
                HStack(spacing: compact ? 6 : 8) {
                    Text(session.shortName)
                        .font(.system(size: compact ? 12 : 13, weight: .bold))
                        .foregroundStyle(F1Theme.primary)
                        .frame(width: compact ? 36 : 42, alignment: .leading)
                    Text(F1Formatters.raceDate.string(from: session.startsAt))
                        .font(.system(size: compact ? 11 : 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(F1Theme.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Spacer()
                    if session.id == nextSession?.id {
                        Text("Next")
                            .font(.system(size: compact ? 10 : 11, weight: .bold))
                            .foregroundStyle(F1Theme.accent)
                    }
                }
                .padding(.vertical, compact ? 0 : 1)
            }
        }
        .padding(compact ? 10 : 12)
        .background(F1Theme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StatusBadge: View {
    let status: F1WidgetStatus
    var compact = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status == .live ? F1Theme.accent : F1Theme.secondary)
                .frame(width: 6, height: 6)
            Text(status.label.uppercased())
                .font(.system(size: compact ? 9 : 10, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(F1Theme.primary)
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 4 : 5)
        .background(F1Theme.badge, in: Capsule())
    }
}

private enum F1Theme {
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.74)
    static let muted = Color.white.opacity(0.48)
    static let accent = Color(red: 1.0, green: 0.16, blue: 0.12)
    static let badge = Color.white.opacity(0.14)
    static let panel = Color.white.opacity(0.09)
}

private struct F1Background: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.10, blue: 0.11),
                    Color(red: 0.04, green: 0.05, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(F1Theme.accent)
                .frame(width: 6)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("F1")
                .font(.system(size: 78, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.035))
                .padding(.trailing, 8)
                .padding(.top, -2)
        }
    }
}
