import CryptoKit
import Foundation

actor OpenF1Service {
    private let session: URLSession
    private let responseCache = OpenF1ResponseCache()
    private let baseURL = URL(string: "https://api.openf1.org/v1")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadSnapshot(now: Date = Date()) async -> F1WidgetSnapshot {
        do {
            let calendar = Calendar(identifier: .gregorian)
            let year = calendar.component(.year, from: now)
            let lookbackDate = calendar.date(byAdding: .day, value: -3, to: now, wrappingComponents: false)!
            var meetings = try await loadMeetings(years: [year])
                .filter { !$0.isCancelled }
            if !meetings.contains(where: { $0.isRaceMeeting && $0.dateStartDate >= lookbackDate }) {
                let nextYearMeetings = try await loadMeetings(years: [year + 1])
                    .filter { !$0.isCancelled }
                meetings += nextYearMeetings
            }

            guard let meeting = meetings
                .filter(\.isRaceMeeting)
                .filter({ $0.dateStartDate >= lookbackDate })
                .sorted(by: { $0.dateStartDate < $1.dateStartDate })
                .first ?? meetings.filter(\.isRaceMeeting).sorted(by: { $0.dateStartDate > $1.dateStartDate }).first ?? meetings.sorted(by: { $0.dateStartDate > $1.dateStartDate }).first else {
                return .unavailable("No Formula 1 meetings were returned by OpenF1.")
            }

            let sessions = try await loadSessions(meetingKey: meeting.meetingKey)
                .filter { !$0.isCancelled }
                .sorted(by: { $0.dateStartDate < $1.dateStartDate })
            let nextSession = sessions.first { ($0.dateEndDate ?? $0.dateStartDate) >= now }
            let lastSession = sessions.last { $0.isComplete(at: now) }
            let lastResult = await latestResultSummary(from: sessions, now: now)
            let nextRace = sessions.first { $0.normalizedShortName == "Race" && ($0.dateEndDate ?? $0.dateStartDate) >= now }
            let summary = nextSession?.summary ?? nextRace?.summary
            let status = status(now: now, meeting: meeting, sessions: sessions, nextSession: nextSession, lastSession: lastSession)

            return F1WidgetSnapshot(
                status: status,
                raceName: meeting.shortDisplayName,
                circuitName: meeting.circuitShortName ?? meeting.circuitKey.map(String.init) ?? "Circuit TBA",
                location: meeting.locationText,
                countryCode: meeting.countryCode,
                nextSession: summary,
                weekendSchedule: sessions.map(\.summary),
                lastResult: lastResult,
                updatedAt: now,
                attribution: "OpenF1",
                errorMessage: nil
            )
        } catch {
            return .unavailable(Self.describe(error))
        }
    }

    private func loadMeetings(years: [Int]) async throws -> [OpenF1Meeting] {
        var allMeetings: [OpenF1Meeting] = []
        for year in years {
            do {
                let meetings: [OpenF1Meeting] = try await get("meetings", queryItems: [URLQueryItem(name: "year", value: String(year))])
                allMeetings += meetings
            } catch let error as OpenF1Error where error.isNoResults {
                continue
            }
        }

        if allMeetings.isEmpty {
            throw OpenF1Error.noData("No meetings found for \(years.map(String.init).joined(separator: ", ")).")
        }

        return allMeetings
    }

    private func loadSessions(meetingKey: Int) async throws -> [OpenF1Session] {
        try await get("sessions", queryItems: [URLQueryItem(name: "meeting_key", value: String(meetingKey))])
    }

    private func latestResultSummary(from sessions: [OpenF1Session], now: Date) async -> F1SessionResultSummary? {
        let completedSessions = sessions
            .filter { $0.isComplete(at: now) }
            .sorted(by: { $0.dateStartDate > $1.dateStartDate })

        guard let latestCompletedSession = completedSessions.first else {
            return nil
        }

        return (try? await lastResultSummary(for: latestCompletedSession)) ?? F1SessionResultSummary(
            sessionName: latestCompletedSession.sessionName,
            sessionShortName: latestCompletedSession.normalizedShortName,
            topThree: []
        )
    }

    private func lastResultSummary(for session: OpenF1Session?) async throws -> F1SessionResultSummary? {
        guard let session else { return nil }
        async let results: [OpenF1SessionResult] = get("session_result", queryItems: [URLQueryItem(name: "session_key", value: String(session.sessionKey))])
        async let drivers: [OpenF1Driver] = get("drivers", queryItems: [URLQueryItem(name: "session_key", value: String(session.sessionKey))])

        let driverCodes = try await Dictionary(uniqueKeysWithValues: drivers.map { ($0.driverNumber, $0.nameAcronym ?? String($0.driverNumber)) })
        let topThree = try await results
            .filter { $0.position != nil }
            .sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) }
            .prefix(3)
            .map { result in
                F1DriverResult(
                    position: result.position ?? 0,
                    driverCode: driverCodes[result.driverNumber] ?? String(result.driverNumber),
                    displayValue: result.displayValue
                )
            }

        guard !topThree.isEmpty else { return nil }
        return F1SessionResultSummary(
            sessionName: session.sessionName,
            sessionShortName: session.normalizedShortName,
            topThree: topThree
        )
    }

    private func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem]) async throws -> T {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        if let cachedData = await responseCache.data(for: url, maxAge: cacheMaxAge(for: path)) {
            return try Self.decode(T.self, from: cachedData)
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if let staleData = await responseCache.staleData(for: url, maxAge: staleCacheMaxAge(for: path)) {
                return try Self.decode(T.self, from: staleData)
            }
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            if let staleData = await responseCache.staleData(for: url, maxAge: staleCacheMaxAge(for: path)) {
                return try Self.decode(T.self, from: staleData)
            }
            throw OpenF1Error.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            if let staleData = await responseCache.staleData(for: url, maxAge: staleCacheMaxAge(for: path)) {
                return try Self.decode(T.self, from: staleData)
            }
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw OpenF1Error.httpStatus(httpResponse.statusCode, body)
        }

        await responseCache.store(data, for: url)
        return try Self.decode(T.self, from: data)
    }

    private func cacheMaxAge(for path: String) -> TimeInterval {
        switch path {
        case "meetings":
            return 12 * 3_600
        case "sessions":
            return 10 * 60
        case "session_result", "drivers":
            return 5 * 60
        default:
            return 5 * 60
        }
    }

    private func staleCacheMaxAge(for path: String) -> TimeInterval {
        switch path {
        case "meetings":
            return 14 * 24 * 3_600
        case "sessions":
            return 24 * 3_600
        case "session_result", "drivers":
            return 6 * 3_600
        default:
            return 24 * 3_600
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(Self.decodeDate)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let body = String(data: data.prefix(700), encoding: .utf8) ?? "Unreadable response body"
            throw OpenF1Error.decoding(error, body)
        }
    }

    private static func describe(_ error: Error) -> String {
        if let openF1Error = error as? OpenF1Error {
            return openF1Error.message
        }

        if let urlError = error as? URLError {
            return urlError.localizedDescription
        }

        return String(describing: error)
    }

    private static func decodeDate(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if let date = DateParsers.iso8601WithFractionalSeconds.date(from: value)
            ?? DateParsers.iso8601.date(from: value)
            ?? DateParsers.openF1Fallback.date(from: value) {
            return date
        }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
    }

    private func status(now: Date, meeting: OpenF1Meeting, sessions: [OpenF1Session], nextSession: OpenF1Session?, lastSession: OpenF1Session?) -> F1WidgetStatus {
        if let active = sessions.first(where: { $0.dateStartDate <= now && ($0.dateEndDate ?? $0.dateStartDate) >= now }) {
            return active.sessionName.localizedCaseInsensitiveContains("race") ? .live : .raceWeekend
        }

        guard let nextSession else {
            return lastSession == nil ? .offseason : .postRace
        }

        let hoursUntilNext = nextSession.dateStartDate.timeIntervalSince(now) / 3_600
        return hoursUntilNext <= 72 ? .raceWeekend : .nextRace
    }
}

private actor OpenF1ResponseCache {
    private let directory: URL
    private let fileManager = FileManager.default

    init() {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        directory = (cachesDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("OpenF1ResponseCache", isDirectory: true)
    }

    func data(for url: URL, maxAge: TimeInterval, now: Date = Date()) -> Data? {
        cachedData(for: url, maxAge: maxAge, now: now)
    }

    func staleData(for url: URL, maxAge: TimeInterval, now: Date = Date()) -> Data? {
        cachedData(for: url, maxAge: maxAge, now: now)
    }

    func store(_ data: Data, for url: URL) {
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL(for: url), options: [.atomic])
        } catch {
            // Cache failures should never block live data.
        }
    }

    private func cachedData(for url: URL, maxAge: TimeInterval, now: Date) -> Data? {
        let fileURL = fileURL(for: url)

        guard
            let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
            let modifiedAt = attributes[.modificationDate] as? Date,
            now.timeIntervalSince(modifiedAt) <= maxAge
        else {
            return nil
        }

        return try? Data(contentsOf: fileURL)
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let filename = digest.map { String(format: "%02x", $0) }.joined() + ".json"
        return directory.appendingPathComponent(filename, isDirectory: false)
    }
}

private enum OpenF1Error: Error {
    case invalidResponse
    case httpStatus(Int, String)
    case decoding(Error, String)
    case noData(String)

    var isNoResults: Bool {
        switch self {
        case .httpStatus(404, let body):
            return body.localizedCaseInsensitiveContains("No results found")
        default:
            return false
        }
    }

    var message: String {
        switch self {
        case .invalidResponse:
            return "OpenF1 returned an invalid response."
        case .httpStatus(let status, let body):
            return "OpenF1 HTTP \(status): \(body)"
        case .decoding(let error, let body):
            return "OpenF1 decode failed: \(error). Body: \(body)"
        case .noData(let message):
            return message
        }
    }
}

private enum DateParsers {
    static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let openF1Fallback: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}

private struct OpenF1Meeting: Decodable {
    let meetingKey: Int
    let meetingName: String
    let meetingOfficialName: String?
    let location: String?
    let countryName: String?
    let countryCode: String?
    let circuitShortName: String?
    let circuitKey: Int?
    let dateStartDate: Date
    let isCancelled: Bool

    enum CodingKeys: String, CodingKey {
        case meetingKey = "meeting_key"
        case meetingName = "meeting_name"
        case meetingOfficialName = "meeting_official_name"
        case location
        case countryName = "country_name"
        case countryCode = "country_code"
        case circuitShortName = "circuit_short_name"
        case circuitKey = "circuit_key"
        case dateStartDate = "date_start"
        case isCancelled = "is_cancelled"
    }

    var shortDisplayName: String {
        meetingName
            .replacingOccurrences(of: "Grand Prix", with: "GP")
            .replacingOccurrences(of: "Formula 1", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var locationText: String {
        [location, countryName]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: ", ")
    }

    var isRaceMeeting: Bool {
        !meetingName.localizedCaseInsensitiveContains("testing")
    }
}

private struct OpenF1Session: Decodable {
    let sessionKey: Int
    let sessionName: String
    let dateStartDate: Date
    let dateEndDate: Date?
    let gmtOffset: String?
    let isCancelled: Bool

    enum CodingKeys: String, CodingKey {
        case sessionKey = "session_key"
        case sessionName = "session_name"
        case dateStartDate = "date_start"
        case dateEndDate = "date_end"
        case gmtOffset = "gmt_offset"
        case isCancelled = "is_cancelled"
    }

    var normalizedShortName: String {
        let lower = sessionName.lowercased()
        if lower.contains("practice 1") { return "FP1" }
        if lower.contains("practice 2") { return "FP2" }
        if lower.contains("practice 3") { return "FP3" }
        if lower.contains("sprint shootout") { return "SQ" }
        if lower.contains("sprint qualifying") { return "SQ" }
        if lower.contains("sprint") { return "Sprint" }
        if lower.contains("qualifying") { return "Quali" }
        if lower.contains("race") { return "Race" }
        return sessionName
    }

    var summary: F1SessionSummary {
        F1SessionSummary(
            name: sessionName,
            shortName: normalizedShortName,
            startsAt: dateStartDate,
            endsAt: dateEndDate,
            gmtOffset: gmtOffset
        )
    }

    func isComplete(at date: Date) -> Bool {
        (dateEndDate ?? dateStartDate) < date
    }
}

private struct OpenF1SessionResult: Decodable {
    let driverNumber: Int
    let position: Int?
    let duration: OpenF1NumericValue?
    let gapToLeader: OpenF1NumericValue?
    let numberOfLaps: Int?
    let dnf: Bool?
    let dns: Bool?
    let dsq: Bool?

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case position
        case duration
        case gapToLeader = "gap_to_leader"
        case numberOfLaps = "number_of_laps"
        case dnf
        case dns
        case dsq
    }

    var displayValue: String {
        if dnf == true { return "DNF" }
        if dns == true { return "DNS" }
        if dsq == true { return "DSQ" }
        if let duration = duration?.bestValue {
            return formatDuration(duration)
        }
        if let gapToLeader = gapToLeader?.bestValue, gapToLeader > 0 {
            return String(format: "+%.3f", gapToLeader)
        }
        if let numberOfLaps {
            return "\(numberOfLaps) laps"
        }
        return "--"
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remaining = seconds - Double(minutes * 60)
        if minutes > 0 {
            return String(format: "%d:%06.3f", minutes, remaining)
        }
        return String(format: "%.3f", seconds)
    }
}

private struct OpenF1NumericValue: Decodable {
    let bestValue: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            bestValue = nil
            return
        }

        if let value = try? container.decode(Double.self) {
            bestValue = value
            return
        }

        if let values = try? container.decode([Double?].self) {
            bestValue = values.compactMap(\.self).last
            return
        }

        if let value = try? container.decode(String.self) {
            bestValue = Double(value)
            return
        }

        bestValue = nil
    }
}

private struct OpenF1Driver: Decodable {
    let driverNumber: Int
    let nameAcronym: String?

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case nameAcronym = "name_acronym"
    }
}
