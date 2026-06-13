import Foundation

enum F1WidgetStatus: String, Codable, Sendable {
    case nextRace
    case raceWeekend
    case live
    case postRace
    case offseason
    case unavailable

    var label: String {
        switch self {
        case .nextRace: "Next Race"
        case .raceWeekend: "Race Weekend"
        case .live: "Live"
        case .postRace: "Last Result"
        case .offseason: "Offseason"
        case .unavailable: "Unavailable"
        }
    }
}

struct F1WidgetSnapshot: Codable, Equatable, Sendable {
    var status: F1WidgetStatus
    var raceName: String
    var circuitName: String
    var location: String
    var countryCode: String?
    var nextSession: F1SessionSummary?
    var weekendSchedule: [F1SessionSummary]
    var lastResult: F1SessionResultSummary?
    var updatedAt: Date
    var attribution: String
    var errorMessage: String?

    static let placeholder = F1WidgetSnapshot(
        status: .raceWeekend,
        raceName: "Canadian GP",
        circuitName: "Circuit Gilles Villeneuve",
        location: "Montreal, Canada",
        countryCode: "CAN",
        nextSession: F1SessionSummary(
            name: "Qualifying",
            shortName: "Quali",
            startsAt: Date(timeIntervalSinceReferenceDate: 803_080_800),
            endsAt: Date(timeIntervalSinceReferenceDate: 803_084_400),
            gmtOffset: "-04:00"
        ),
        weekendSchedule: [
            F1SessionSummary(name: "Practice 1", shortName: "FP1", startsAt: Date(timeIntervalSinceReferenceDate: 803_012_400), endsAt: Date(timeIntervalSinceReferenceDate: 803_016_000), gmtOffset: "-04:00"),
            F1SessionSummary(name: "Practice 2", shortName: "FP2", startsAt: Date(timeIntervalSinceReferenceDate: 803_026_800), endsAt: Date(timeIntervalSinceReferenceDate: 803_030_400), gmtOffset: "-04:00"),
            F1SessionSummary(name: "Qualifying", shortName: "Quali", startsAt: Date(timeIntervalSinceReferenceDate: 803_080_800), endsAt: Date(timeIntervalSinceReferenceDate: 803_084_400), gmtOffset: "-04:00"),
            F1SessionSummary(name: "Race", shortName: "Race", startsAt: Date(timeIntervalSinceReferenceDate: 803_170_800), endsAt: Date(timeIntervalSinceReferenceDate: 803_181_600), gmtOffset: "-04:00")
        ],
        lastResult: F1SessionResultSummary(
            sessionName: "Practice 2",
            sessionShortName: "FP2",
            topThree: [
                F1DriverResult(position: 1, driverCode: "NOR", displayValue: "1:12.847"),
                F1DriverResult(position: 2, driverCode: "PIA", displayValue: "+0.102"),
                F1DriverResult(position: 3, driverCode: "VER", displayValue: "+0.214")
            ]
        ),
        updatedAt: Date(timeIntervalSinceReferenceDate: 803_031_000),
        attribution: "OpenF1",
        errorMessage: nil
    )

    static func unavailable(_ message: String) -> F1WidgetSnapshot {
        F1WidgetSnapshot(
            status: .unavailable,
            raceName: "Formula 1 Update",
            circuitName: "OpenF1",
            location: "Data unavailable",
            countryCode: nil,
            nextSession: nil,
            weekendSchedule: [],
            lastResult: nil,
            updatedAt: Date(),
            attribution: "OpenF1",
            errorMessage: message
        )
    }
}

struct F1SessionSummary: Codable, Equatable, Identifiable, Sendable {
    var id: String { "\(shortName)-\(startsAt.timeIntervalSince1970)" }
    var name: String
    var shortName: String
    var startsAt: Date
    var endsAt: Date?
    var gmtOffset: String?
}

struct F1SessionResultSummary: Codable, Equatable, Sendable {
    var sessionName: String
    var sessionShortName: String
    var topThree: [F1DriverResult]
}

struct F1DriverResult: Codable, Equatable, Identifiable, Sendable {
    var id: Int { position }
    var position: Int
    var driverCode: String
    var displayValue: String
}

enum F1Formatters {
    static let raceDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        formatter.locale = Locale.current
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.locale = Locale.current
        return formatter
    }()

    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    static func countdown(to date: Date, from now: Date = Date()) -> String {
        let interval = max(0, Int(date.timeIntervalSince(now)))
        let days = interval / 86_400
        let hours = interval % 86_400 / 3_600
        let minutes = interval % 3_600 / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        }

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(max(1, minutes))m"
    }

    static func updatedText(_ date: Date, now: Date = Date()) -> String {
        "Updated \(relative.localizedString(for: date, relativeTo: now))"
    }
}
