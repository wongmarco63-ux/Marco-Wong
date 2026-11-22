import Foundation
import SwiftUI
import AVFoundation
import UserNotifications
import WidgetKit

// MARK: - Core Enums
enum RaceSeries: String, CaseIterable, Identifiable, Codable {
    case f1 = "F1"
    case motogp = "MotoGP"
    case tcr = "TCR"

    var id: String { rawValue }

    var fullTitle: String {
        switch self {
        case .f1: return "Formula 1"
        case .motogp: return "MotoGP"
        case .tcr: return "FIA TCR World Tour"
        }
    }

    var symbol: String {
        switch self {
        case .f1: return "flag.checkered"
        case .motogp: return "motorcycle.fill"
        case .tcr: return "car.side.fill"
        }
    }

    var badgeColor: Color {
        switch self {
        case .f1: return Color(red: 0.92, green: 0.15, blue: 0.18)
        case .motogp: return Color(red: 0.96, green: 0.34, blue: 0.18)
        case .tcr: return Color(red: 0.16, green: 0.64, blue: 0.98)
        }
    }
}

enum TeamTheme: String, CaseIterable, Identifiable {
    case ferrari = "ferrari"
    case mercedes = "mercedes"
    case mclaren = "mclaren"
    case redbull = "redbull"
    case ducati = "ducati"
    case hyundai = "hyundai"
    case oled = "oled"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ferrari: return "Scuderia Red（法拉利紅）"
        case .mercedes: return "Petronas Teal（平治青綠）"
        case .mclaren: return "Papaya Orange（木瓜橙）"
        case .redbull: return "Racing Navy（紅牛深藍）"
        case .ducati: return "Ducati Corse（電單車紅）"
        case .hyundai: return "TCR Sky Blue（房車天藍）"
        case .oled: return "Pure OLED（極致純黑）"
        }
    }

    var accent: Color {
        switch self {
        case .ferrari: return Color(red: 0.96, green: 0.18, blue: 0.20)
        case .mercedes: return Color(red: 0.00, green: 0.82, blue: 0.74)
        case .mclaren: return Color(red: 1.00, green: 0.52, blue: 0.08)
        case .redbull: return Color(red: 0.30, green: 0.56, blue: 1.00)
        case .ducati: return Color(red: 0.88, green: 0.08, blue: 0.14)
        case .hyundai: return Color(red: 0.42, green: 0.78, blue: 1.00)
        case .oled: return Color(red: 0.78, green: 0.86, blue: 1.00)
        }
    }

    var bgColors: [Color] {
        switch self {
        case .ferrari: return [Color(red: 0.14, green: 0.03, blue: 0.05), Color(red: 0.06, green: 0.02, blue: 0.04), Color(red: 0.02, green: 0.02, blue: 0.03)]
        case .mercedes: return [Color(red: 0.02, green: 0.12, blue: 0.12), Color(red: 0.02, green: 0.06, blue: 0.08), Color(red: 0.01, green: 0.02, blue: 0.03)]
        case .mclaren: return [Color(red: 0.14, green: 0.07, blue: 0.02), Color(red: 0.07, green: 0.04, blue: 0.02), Color(red: 0.02, green: 0.02, blue: 0.03)]
        case .redbull: return [Color(red: 0.04, green: 0.08, blue: 0.18), Color(red: 0.03, green: 0.04, blue: 0.11), Color(red: 0.01, green: 0.02, blue: 0.05)]
        case .ducati: return [Color(red: 0.16, green: 0.02, blue: 0.03), Color(red: 0.07, green: 0.02, blue: 0.03), Color(red: 0.02, green: 0.01, blue: 0.02)]
        case .hyundai: return [Color(red: 0.04, green: 0.11, blue: 0.18), Color(red: 0.02, green: 0.06, blue: 0.11), Color(red: 0.01, green: 0.02, blue: 0.04)]
        case .oled: return [Color.black, Color(white: 0.02), Color.black]
        }
    }
}

// MARK: - Domain Models
struct DriverStanding: Identifiable, Hashable {
    let id: String
    let series: RaceSeries
    let position: Int
    let name: String
    let shortCode: String
    let number: String
    let team: String
    let points: Double
    let wins: Int
    let colorHex: String
}

struct TeamStanding: Identifiable, Hashable {
    let id: String
    let series: RaceSeries
    let position: Int
    let name: String
    let points: Double
    let wins: Int
    let colorHex: String
}

struct RaceEvent: Identifiable, Hashable {
    let id: String
    let series: RaceSeries
    let round: Int
    let name: String
    let circuit: String
    let location: String
    let raceDate: Date
    let qualiDate: Date?
    let sprintDate: Date?
}

struct RaceResultRow: Identifiable, Hashable {
    let id: String
    let position: Int
    let driverName: String
    let teamName: String
    let timeOrStatus: String
    let points: Double
}

struct LatestRaceSummary {
    let series: RaceSeries
    let raceName: String
    let dateText: String
    let results: [RaceResultRow]
}

// MARK: - F1 v2.0 Telemetry Models (OpenF1)
struct F1TireStint: Identifiable, Hashable {
    let id = UUID()
    let stintNumber: Int
    let lapStart: Int
    let lapEnd: Int
    let compound: String

    var lapCount: Int { max(1, lapEnd - lapStart + 1) }

    var compoundColor: Color {
        switch compound.uppercased() {
        case "SOFT": return Color(red: 0.94, green: 0.20, blue: 0.22)
        case "MEDIUM": return Color(red: 0.98, green: 0.82, blue: 0.16)
        case "HARD": return Color(white: 0.92)
        case "INTERMEDIATE": return Color(red: 0.20, green: 0.80, blue: 0.36)
        case "WET": return Color(red: 0.16, green: 0.56, blue: 0.98)
        default: return Color.gray
        }
    }

    var shortLetter: String {
        switch compound.uppercased() {
        case "SOFT": return "S"
        case "MEDIUM": return "M"
        case "HARD": return "H"
        case "INTERMEDIATE": return "I"
        case "WET": return "W"
        default: return "?"
        }
    }
}

struct F1DriverStrategy: Identifiable {
    let id: Int
    let driverNumber: Int
    let acronym: String
    let fullName: String
    let teamColorHex: String
    let stints: [F1TireStint]
    var totalLaps: Int { stints.map(\.lapEnd).max() ?? 1 }
}

struct F1TeamRadioClip: Identifiable, Hashable {
    let id: String
    let driverNumber: Int
    let acronym: String
    let fullName: String
    let teamColorHex: String
    let date: Date
    let recordingURL: String
}

struct F1RaceControlMsg: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let category: String
    let flag: String
    let message: String
    let lapNumber: Int?

    var isCritical: Bool {
        let lower = "\(flag) \(message)".lowercased()
        return lower.contains("red") || lower.contains("penalty") || lower.contains("safety car") || lower.contains("investigation") || lower.contains("black")
    }
}

// MARK: - News Model
struct NewsArticle: Identifiable, Hashable {
    let id: String
    let series: RaceSeries
    let title: String
    let link: String
    let pubDate: Date
    let source: String
    let alertTag: String?
    let isBreaking: Bool
}

// MARK: - Color Hex Helper & Date Formatters
extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let r, g, b: Double
        if clean.count == 6 {
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        } else {
            r = 0.55; g = 0.72; b = 0.98
        }
        self.init(red: r, green: g, blue: b)
    }
}

enum RaceDateFmt {
    static let macauTZ = TimeZone(identifier: "Asia/Macau") ?? .current

    static let fullMacau: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = macauTZ
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()

    static let hmMacau: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = macauTZ
        f.dateFormat = "HH:mm"
        return f
    }()

    static let ymd: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = macauTZ
        f.dateFormat = "yyyy.MM.dd"
        return f
    }()

    static func parseISO(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFrac.date(from: raw) { return d }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: raw) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return f.date(from: raw)
    }

    static func countdownParts(to date: Date) -> (days: Int, hours: Int, mins: Int) {
        let diff = max(0, Int(date.timeIntervalSinceNow))
        return (diff / 86400, (diff % 86400) / 3600, (diff % 3600) / 60)
    }

    static func relativeText(_ date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 3600 { return "\(max(1, diff / 60))分鐘前" }
        if diff < 86400 { return "\(diff / 3600)小時前" }
        return "\(diff / 86400)日前"
    }
}

// MARK: - RSS Feed XML Parser (Non-isolated, Safe Background Parsing)
final class MotorsportRSSParser: NSObject, XMLParserDelegate {
    private var articles: [NewsArticle] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentDateStr = ""
    private var inItem = false
    private let series: RaceSeries
    private let sourceName: String

    init(series: RaceSeries, sourceName: String) {
        self.series = series
        self.sourceName = sourceName
    }

    func parse(data: Data) -> [NewsArticle] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return articles
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName.lowercased()
        if currentElement == "item" || currentElement == "entry" {
            inItem = true
            currentTitle = ""
            currentLink = ""
            currentDateStr = ""
        } else if inItem && currentElement == "link", let href = attributeDict["href"], !href.isEmpty {
            currentLink = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch currentElement {
        case "title": currentTitle += string
        case "link": currentLink += string
        case "pubdate", "published", "updated": currentDateStr += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let tag = elementName.lowercased()
        if tag == "item" || tag == "entry" {
            inItem = false
            let cleanTitle = decodeEntities(currentTitle).trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanLink = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanTitle.isEmpty, !cleanLink.isEmpty else { return }
            let date = parseRSSDate(currentDateStr.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Date()
            let (badge, breaking) = classifyTitle(cleanTitle)
            articles.append(NewsArticle(
                id: cleanLink,
                series: series,
                title: cleanTitle,
                link: cleanLink,
                pubDate: date,
                source: sourceName,
                alertTag: badge,
                isBreaking: breaking
            ))
        }
    }

    private func decodeEntities(_ str: String) -> String {
        str.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&#8217;", with: "'")
            .replacingOccurrences(of: "&#8216;", with: "'")
            .replacingOccurrences(of: "&#8211;", with: "–")
            .replacingOccurrences(of: "&apos;", with: "'")
    }

    private func parseRSSDate(_ str: String) -> Date? {
        let fmts = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssZ"
        ]
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in fmts {
            f.dateFormat = fmt
            if let d = f.date(from: str) { return d }
        }
        return nil
    }

    private func classifyTitle(_ title: String) -> (String?, Bool) {
        let l = title.lowercased()
        if l.contains("penalty") || l.contains("penalis") || l.contains("disqualif") || l.contains("dsq") || l.contains("grid drop") || l.contains("overpower") || l.contains("steward") {
            return ("判罰", true)
        }
        if l.contains("red flag") || l.contains("crash") || l.contains("collision") || l.contains("injury") || l.contains("withdraw") {
            return ("紅旗 / 意外", true)
        }
        if l.contains("macau") || l.contains("guia") {
            return ("澳門站", true)
        }
        if l.contains("signs") || l.contains("contract") || l.contains("joins") || l.contains("official") || l.contains("confirmed") || l.contains("champion") || l.contains("title") {
            return ("重磅焦點", true)
        }
        return (nil, false)
    }
}

// MARK: - Team Radio Audio Player (AVPlayer)
@MainActor
final class RadioAudioPlayer: ObservableObject {
    @Published var currentURL: String?
    @Published var isPlaying = false
    @Published var isLoading = false

    private var player: AVPlayer?
    private var endObserver: Any?

    func toggle(urlString: String) {
        if currentURL == urlString && isPlaying {
            stop()
            return
        }
        stop()
        guard let url = URL(string: urlString) else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}

        isLoading = true
        currentURL = urlString
        let item = AVPlayerItem(url: url)
        let av = AVPlayer(playerItem: item)
        self.player = av

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.currentURL = nil
            }
        }

        av.play()
        isPlaying = true
        isLoading = false
    }

    func stop() {
        player?.pause()
        player = nil
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
        isPlaying = false
        currentURL = nil
    }
}

// MARK: - Main Data Store (Jolpica F1 + OpenF1 + MotoGP PulseLive + TCR + RSS)
@MainActor
final class MotorsportStore: ObservableObject {
    private let ud = UserDefaults.standard

    @Published var isLoading = false
    @Published var lastUpdated: Date?
    @Published var statusNote = ""

    // Standings & Schedules by Series
    @Published var driverStandings: [RaceSeries: [DriverStanding]] = [:]
    @Published var teamStandings: [RaceSeries: [TeamStanding]] = [:]
    @Published var schedules: [RaceSeries: [RaceEvent]] = [:]
    @Published var latestResults: [RaceSeries: LatestRaceSummary] = [:]

    // F1 v2.0 Telemetry (OpenF1)
    @Published var openF1SessionName = ""
    @Published var f1Strategies: [F1DriverStrategy] = []
    @Published var f1RadioClips: [F1TeamRadioClip] = []
    @Published var f1RaceControl: [F1RaceControlMsg] = []
    @Published var isLoadingTelemetry = false

    // News
    @Published var articles: [NewsArticle] = []

    // User Settings
    @Published var spoilerFree: Bool { didSet { ud.set(spoilerFree, forKey: "ag_spoiler_free") } }
    @Published var theme: TeamTheme { didSet { ud.set(theme.rawValue, forKey: "ag_theme") } }
    @Published var enableHaptics: Bool { didSet { ud.set(enableHaptics, forKey: "ag_haptics") } }
    @Published var onlyBreakingNews: Bool { didSet { ud.set(onlyBreakingNews, forKey: "ag_breaking_only") } }

    init() {
        spoilerFree = ud.object(forKey: "ag_spoiler_free") as? Bool ?? false
        theme = TeamTheme(rawValue: ud.string(forKey: "ag_theme") ?? "") ?? .ferrari
        enableHaptics = ud.object(forKey: "ag_haptics") as? Bool ?? true
        onlyBreakingNews = ud.object(forKey: "ag_breaking_only") as? Bool ?? false
        seedTCRFallback()
        seedMotoGPFallback()
    }

    func haptic() {
        guard enableHaptics else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func refreshAll() async {
        isLoading = true
        defer {
            isLoading = false
            lastUpdated = Date()
            WidgetCenter.shared.reloadAllTimelines()
        }

        async let f1Task: Void = fetchF1Jolpica()
        async let motoTask: Void = fetchMotoGPPulseLive()
        async let newsTask: Void = fetchAllNews()
        async let openF1Task: Void = fetchOpenF1Telemetry()

        _ = await (f1Task, motoTask, newsTask, openF1Task)
    }

    // MARK: - Next Event Helpers
    func nextEvent(for series: RaceSeries) -> RaceEvent? {
        let now = Date()
        return (schedules[series] ?? []).first { $0.raceDate > now }
            ?? (schedules[series] ?? []).last
    }

    func nextGlobalEvent() -> RaceEvent? {
        let now = Date()
        let upcoming = RaceSeries.allCases.compactMap { s in
            (schedules[s] ?? []).first { $0.raceDate > now }
        }
        return upcoming.sorted { $0.raceDate < $1.raceDate }.first
    }

    func scheduleReminder(for event: RaceEvent) async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return false }
            let triggerDate = event.raceDate.addingTimeInterval(-15 * 60)
            guard triggerDate > Date() else { return false }

            let content = UNMutableNotificationContent()
            content.title = "🏁 \(event.series.rawValue) 仲有 15 分鐘開波！"
            content.body = "\(event.name)（\(event.circuit)）將於澳門時間 \(RaceDateFmt.hmMacau.string(from: event.raceDate)) 燈滅起跑。"
            content.sound = .default

            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let req = UNNotificationRequest(identifier: "race_\(event.id)", content: content, trigger: trigger)
            try await center.add(req)
            return true
        } catch {
            return false
        }
    }

    // MARK: - 1. F1 via Jolpica-F1 API
    private func fetchF1Jolpica() async {
        // Driver Standings
        if let url = URL(string: "https://api.jolpi.ca/ergast/f1/current/driverStandings.json"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let root = try? JSONDecoder().decode(JolpicaDriverRoot.self, from: data),
           let list = root.MRData?.StandingsTable?.StandingsLists?.first?.DriverStandings,
           !list.isEmpty {
            driverStandings[.f1] = list.map { row in
                let team = row.Constructors?.first?.name ?? "F1"
                let code = row.Driver?.code ?? String((row.Driver?.familyName ?? "DRV").prefix(3)).uppercased()
                return DriverStanding(
                    id: "f1_\(row.Driver?.driverId ?? code)",
                    series: .f1,
                    position: Int(row.position ?? "0") ?? 0,
                    name: "\(row.Driver?.givenName ?? "") \(row.Driver?.familyName ?? "")",
                    shortCode: code,
                    number: row.Driver?.permanentNumber ?? "",
                    team: team,
                    points: Double(row.points ?? "0") ?? 0,
                    wins: Int(row.wins ?? "0") ?? 0,
                    colorHex: Self.f1TeamColor(team)
                )
            }
        }

        // Constructor Standings
        if let url = URL(string: "https://api.jolpi.ca/ergast/f1/current/constructorStandings.json"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let root = try? JSONDecoder().decode(JolpicaConstructorRoot.self, from: data),
           let list = root.MRData?.StandingsTable?.StandingsLists?.first?.ConstructorStandings,
           !list.isEmpty {
            teamStandings[.f1] = list.map { row in
                let name = row.Constructor?.name ?? "Team"
                return TeamStanding(
                    id: "f1_team_\(row.Constructor?.constructorId ?? name)",
                    series: .f1,
                    position: Int(row.position ?? "0") ?? 0,
                    name: name,
                    points: Double(row.points ?? "0") ?? 0,
                    wins: Int(row.wins ?? "0") ?? 0,
                    colorHex: Self.f1TeamColor(name)
                )
            }
        }

        // Full Season Schedule
        if let url = URL(string: "https://api.jolpi.ca/ergast/f1/current.json"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let root = try? JSONDecoder().decode(JolpicaScheduleRoot.self, from: data),
           let races = root.MRData?.RaceTable?.Races, !races.isEmpty {
            schedules[.f1] = races.compactMap { r in
                guard let raceD = RaceDateFmt.parseISO("\(r.date)T\(r.time ?? "12:00:00Z")") else { return nil }
                let qDate = r.Qualifying.flatMap { RaceDateFmt.parseISO("\($0.date)T\($0.time ?? "12:00:00Z")") }
                let sDate = r.Sprint.flatMap { RaceDateFmt.parseISO("\($0.date)T\($0.time ?? "12:00:00Z")") }
                return RaceEvent(
                    id: "f1_r\(r.round)",
                    series: .f1,
                    round: Int(r.round) ?? 0,
                    name: r.raceName,
                    circuit: r.Circuit?.circuitName ?? "",
                    location: "\(r.Circuit?.Location?.locality ?? ""), \(r.Circuit?.Location?.country ?? "")",
                    raceDate: raceD,
                    qualiDate: qDate,
                    sprintDate: sDate
                )
            }
        }

        // Latest Race Results
        if let url = URL(string: "https://api.jolpi.ca/ergast/f1/current/last/results.json"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let root = try? JSONDecoder().decode(JolpicaResultsRoot.self, from: data),
           let race = root.MRData?.RaceTable?.Races?.first,
           let res = race.Results, !res.isEmpty {
            let rows = res.map { r in
                RaceResultRow(
                    id: "f1_res_\(r.position ?? "0")_\(r.Driver?.familyName ?? "")",
                    position: Int(r.position ?? "0") ?? 0,
                    driverName: "\(r.Driver?.givenName ?? "") \(r.Driver?.familyName ?? "")",
                    teamName: r.Constructor?.name ?? "",
                    timeOrStatus: r.Time?.time ?? (r.status ?? ""),
                    points: Double(r.points ?? "0") ?? 0
                )
            }
            latestResults[.f1] = LatestRaceSummary(series: .f1, raceName: race.raceName, dateText: race.date, results: rows)
        }
    }

    // MARK: - 2. F1 v2.0 Telemetry via OpenF1 API (Tire Stints + Team Radio + Race Control)
    func fetchOpenF1Telemetry() async {
        isLoadingTelemetry = true
        defer { isLoadingTelemetry = false }

        let currentYear = Calendar.current.component(.year, from: Date())
        var chosenSession: OpenF1Session?

        for yr in [currentYear, currentYear - 1] {
            if let url = URL(string: "https://api.openf1.org/v1/sessions?session_name=Race&year=\(yr)"),
               let (data, resp) = try? await URLSession.shared.data(from: url),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let list = try? JSONDecoder().decode([OpenF1Session].self, from: data) {
                let now = Date()
                if let past = list.last(where: { (RaceDateFmt.parseISO($0.date_start) ?? .distantFuture) < now }) {
                    chosenSession = past
                    break
                } else if let last = list.last {
                    chosenSession = last
                    break
                }
            }
        }

        guard let session = chosenSession else { return }
        openF1SessionName = "\(session.country_name ?? "F1") GP · \(session.location ?? "") (\(session.year ?? currentYear))"
        let sk = session.session_key

        // Drivers Map
        var driverMap: [Int: OpenF1Driver] = [:]
        if let url = URL(string: "https://api.openf1.org/v1/drivers?session_key=\(sk)"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let list = try? JSONDecoder().decode([OpenF1Driver].self, from: data) {
            for d in list { driverMap[d.driver_number] = d }
        }

        // Tire Stints
        if let url = URL(string: "https://api.openf1.org/v1/stints?session_key=\(sk)"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let list = try? JSONDecoder().decode([OpenF1StintDTO].self, from: data) {
            let grouped = Dictionary(grouping: list, by: \.driver_number)
            let built: [F1DriverStrategy] = grouped.compactMap { num, rawStints in
                let stints = rawStints.sorted { $0.stint_number < $1.stint_number }.map {
                    F1TireStint(
                        stintNumber: $0.stint_number,
                        lapStart: $0.lap_start ?? 1,
                        lapEnd: $0.lap_end ?? ($0.lap_start ?? 1),
                        compound: $0.compound ?? "UNKNOWN"
                    )
                }
                guard !stints.isEmpty else { return nil }
                let info = driverMap[num]
                return F1DriverStrategy(
                    id: num,
                    driverNumber: num,
                    acronym: info?.name_acronym ?? "#\(num)",
                    fullName: info?.full_name ?? "Driver #\(num)",
                    teamColorHex: info?.team_colour ?? "88AADD",
                    stints: stints
                )
            }
            .sorted { $0.totalLaps > $1.totalLaps || ($0.totalLaps == $1.totalLaps && $0.driverNumber < $1.driverNumber) }
            if !built.isEmpty { f1Strategies = built }
        }

        // Team Radio Clips (Latest 35)
        if let url = URL(string: "https://api.openf1.org/v1/team_radio?session_key=\(sk)"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let list = try? JSONDecoder().decode([OpenF1RadioDTO].self, from: data) {
            let clips: [F1TeamRadioClip] = list.compactMap { r in
                guard let rec = r.recording_url, !rec.isEmpty else { return nil }
                let info = driverMap[r.driver_number]
                let dt = RaceDateFmt.parseISO(r.date) ?? Date()
                return F1TeamRadioClip(
                    id: rec,
                    driverNumber: r.driver_number,
                    acronym: info?.name_acronym ?? "#\(r.driver_number)",
                    fullName: info?.full_name ?? "Driver #\(r.driver_number)",
                    teamColorHex: info?.team_colour ?? "E82028",
                    date: dt,
                    recordingURL: rec
                )
            }
            .sorted { $0.date > $1.date }
            f1RadioClips = Array(clips.prefix(40))
        }

        // Race Control Messages (Latest 30)
        if let url = URL(string: "https://api.openf1.org/v1/race_control?session_key=\(sk)"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let list = try? JSONDecoder().decode([OpenF1RaceControlDTO].self, from: data) {
            let msgs = list.compactMap { m -> F1RaceControlMsg? in
                guard let txt = m.message, !txt.isEmpty else { return nil }
                return F1RaceControlMsg(
                    date: RaceDateFmt.parseISO(m.date) ?? Date(),
                    category: m.category ?? "INFO",
                    flag: m.flag ?? "",
                    message: txt,
                    lapNumber: m.lap_number
                )
            }
            .sorted { $0.date > $1.date }
            f1RaceControl = Array(msgs.prefix(35))
        }
    }

    // MARK: - 3. MotoGP via PulseLive Public API
    private func fetchMotoGPPulseLive() async {
        guard let seasonURL = URL(string: "https://api.motogp.pulselive.com/motogp/v1/results/seasons"),
              let (sData, _) = try? await URLSession.shared.data(from: seasonURL),
              let seasons = try? JSONDecoder().decode([PulseSeasonDTO].self, from: sData) else { return }

        let targetSeason = seasons.first(where: { $0.current == true }) ?? seasons.sorted(by: { $0.year > $1.year }).first
        guard let season = targetSeason else { return }

        guard let catURL = URL(string: "https://api.motogp.pulselive.com/motogp/v1/results/categories?seasonUuid=\(season.id)"),
              let (cData, _) = try? await URLSession.shared.data(from: catURL),
              let cats = try? JSONDecoder().decode([PulseCategoryDTO].self, from: cData),
              let motoGP = cats.first(where: { $0.name.lowercased().contains("motogp") }) ?? cats.first else { return }

        if let stURL = URL(string: "https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=\(season.id)&categoryUuid=\(motoGP.id)"),
           let (stData, _) = try? await URLSession.shared.data(from: stURL),
           let resp = try? JSONDecoder().decode(PulseStandingsRoot.self, from: stData),
           let rows = resp.classification, !rows.isEmpty {
            let mapped = rows.enumerated().map { idx, row in
                let fullName = row.rider?.full_name ?? "Rider"
                let parts = fullName.split(separator: " ")
                let code = String((parts.last ?? Substring(fullName)).prefix(3)).uppercased()
                let team = row.team?.name ?? row.constructor?.name ?? "MotoGP"
                return DriverStanding(
                    id: "mgp_\(row.rider?.id ?? "\(idx)")",
                    series: .motogp,
                    position: row.position ?? (idx + 1),
                    name: fullName,
                    shortCode: code,
                    number: row.rider?.number.map { "\($0)" } ?? "",
                    team: team,
                    points: row.points ?? 0,
                    wins: 0,
                    colorHex: Self.motoTeamColor(team)
                )
            }
            driverStandings[.motogp] = mapped
        }

        // MotoGP Events
        if let evURL = URL(string: "https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=\(season.id)&isFinished=false"),
           let (evData, _) = try? await URLSession.shared.data(from: evURL),
           let events = try? JSONDecoder().decode([PulseEventDTO].self, from: evData), !events.isEmpty {
            let mapped: [RaceEvent] = events.enumerated().compactMap { idx, e in
                guard let dt = RaceDateFmt.parseISO(e.date_end ?? e.date_start) else { return nil }
                return RaceEvent(
                    id: "mgp_ev_\(e.id)",
                    series: .motogp,
                    round: idx + 1,
                    name: e.name ?? e.short_name ?? "MotoGP GP",
                    circuit: e.circuit?.name ?? "Circuit",
                    location: e.country?.name ?? "",
                    raceDate: dt,
                    qualiDate: nil,
                    sprintDate: nil
                )
            }
            if !mapped.isEmpty { schedules[.motogp] = mapped }
        }
    }

    // MARK: - 4. Multi-Series Breaking News RSS Aggregator
    private func fetchAllNews() async {
        let feeds: [(series: RaceSeries, name: String, url: String)] = [
            (.f1, "Motorsport F1", "https://www.motorsport.com/rss/f1/news/"),
            (.motogp, "Motorsport MotoGP", "https://www.motorsport.com/rss/motogp/news/"),
            (.tcr, "TouringCarTimes", "https://www.touringcartimes.com/feed/"),
            (.tcr, "Motorsport Touring", "https://www.motorsport.com/rss/wtcr/news/")
        ]

        var collected: [NewsArticle] = []
        await withTaskGroup(of: [NewsArticle].self) { group in
            for feed in feeds {
                group.addTask {
                    guard let url = URL(string: feed.url) else { return [] }
                    var req = URLRequest(url: url)
                    req.timeoutInterval = 10
                    req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
                    guard let (data, resp) = try? await URLSession.shared.data(for: req),
                          let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return [] }
                    let parser = MotorsportRSSParser(series: feed.series, sourceName: feed.name)
                    return Array(parser.parse(data: data).prefix(15))
                }
            }
            for await batch in group {
                collected.append(contentsOf: batch)
            }
        }

        // Deduplicate & sort newest first
        var seen = Set<String>()
        let unique = collected.filter { seen.insert($0.id).inserted }
            .sorted { $0.pubDate > $1.pubDate }
        if !unique.isEmpty {
            articles = unique
        }
    }

    // MARK: - Fallback Snapshots (TCR + MotoGP Offline Safety)
    private func seedTCRFallback() {
        driverStandings[.tcr] = [
            DriverStanding(id: "tcr_1", series: .tcr, position: 1, name: "Norbert Michelisz", shortCode: "MIC", number: "105", team: "BRC Hyundai N", points: 323, wins: 3, colorHex: "40B8FF"),
            DriverStanding(id: "tcr_2", series: .tcr, position: 2, name: "Thed Björk", shortCode: "BJO", number: "111", team: "Cyan Racing Lynk & Co", points: 312, wins: 3, colorHex: "00A8E8"),
            DriverStanding(id: "tcr_3", series: .tcr, position: 3, name: "Mikel Azcona", shortCode: "AZC", number: "196", team: "BRC Hyundai N", points: 295, wins: 2, colorHex: "40B8FF"),
            DriverStanding(id: "tcr_4", series: .tcr, position: 4, name: "Esteban Guerrieri", shortCode: "GUE", number: "186", team: "GOAT Racing Honda", points: 291, wins: 2, colorHex: "E62020"),
            DriverStanding(id: "tcr_5", series: .tcr, position: 5, name: "Yann Ehrlacher", shortCode: "EHR", number: "168", team: "Cyan Racing Lynk & Co", points: 287, wins: 2, colorHex: "00A8E8"),
            DriverStanding(id: "tcr_6", series: .tcr, position: 6, name: "Ma Qing Hua", shortCode: "MAQ", number: "155", team: "Cyan Racing Lynk & Co", points: 234, wins: 1, colorHex: "00A8E8")
        ]
        teamStandings[.tcr] = [
            TeamStanding(id: "tcr_t1", series: .tcr, position: 1, name: "Cyan Racing Lynk & Co", points: 735, wins: 6, colorHex: "00A8E8"),
            TeamStanding(id: "tcr_t2", series: .tcr, position: 2, name: "BRC Hyundai N Squadra Corse", points: 678, wins: 5, colorHex: "40B8FF"),
            TeamStanding(id: "tcr_t3", series: .tcr, position: 3, name: "GOAT Racing Honda", points: 482, wins: 2, colorHex: "E62020")
        ]
        schedules[.tcr] = [
            RaceEvent(id: "tcr_macau", series: .tcr, round: 7, name: "澳門格蘭披治 · 東望洋大賽 (TCR 煞科戰)", circuit: "東望洋跑道 Guia Circuit", location: "Macau", raceDate: Date().addingTimeInterval(86400 * 355), qualiDate: nil, sprintDate: nil)
        ]
    }

    private func seedMotoGPFallback() {
        driverStandings[.motogp] = [
            DriverStanding(id: "mgp_f1", series: .motogp, position: 1, name: "Marc Márquez", shortCode: "MAR", number: "93", team: "Ducati Lenovo Team", points: 420, wins: 9, colorHex: "E01018"),
            DriverStanding(id: "mgp_f2", series: .motogp, position: 2, name: "Francesco Bagnaia", shortCode: "BAG", number: "63", team: "Ducati Lenovo Team", points: 398, wins: 7, colorHex: "E01018"),
            DriverStanding(id: "mgp_f3", series: .motogp, position: 3, name: "Jorge Martín", shortCode: "MRT", number: "89", team: "Aprilia Racing", points: 345, wins: 3, colorHex: "22C55E"),
            DriverStanding(id: "mgp_f4", series: .motogp, position: 4, name: "Pedro Acosta", shortCode: "ACO", number: "37", team: "Red Bull KTM Factory", points: 290, wins: 2, colorHex: "FF6B00")
        ]
    }

    static func f1TeamColor(_ name: String) -> String {
        let l = name.lowercased()
        if l.contains("ferrari") { return "E8002D" }
        if l.contains("mercedes") { return "00D2BE" }
        if l.contains("mclaren") { return "FF8000" }
        if l.contains("red bull") { return "3671C6" }
        if l.contains("aston") { return "229971" }
        if l.contains("alpine") { return "0093CC" }
        if l.contains("williams") { return "64C4FF" }
        if l.contains("haas") { return "B6BABD" }
        if l.contains("sauber") || l.contains("audi") { return "52E252" }
        if l.contains("rb") || l.contains("racing bulls") { return "6692FF" }
        if l.contains("cadillac") { return "E5C158" }
        return "99AACC"
    }

    static func motoTeamColor(_ name: String) -> String {
        let l = name.lowercased()
        if l.contains("ducati") { return "E01018" }
        if l.contains("aprilia") { return "22C55E" }
        if l.contains("ktm") { return "FF6B00" }
        if l.contains("yamaha") { return "1D4ED8" }
        if l.contains("honda") { return "F97316" }
        return "A855F7"
    }
}

// MARK: - Private API DTOs
private struct JolpicaDriverRoot: Codable {
    let MRData: MR?
    struct MR: Codable { let StandingsTable: ST? }
    struct ST: Codable { let StandingsLists: [SL]? }
    struct SL: Codable { let DriverStandings: [DS]? }
    struct DS: Codable {
        let position: String?; let points: String?; let wins: String?
        let Driver: Drv?; let Constructors: [Con]?
    }
    struct Drv: Codable { let driverId: String?; let permanentNumber: String?; let code: String?; let givenName: String?; let familyName: String? }
    struct Con: Codable { let constructorId: String?; let name: String? }
}

private struct JolpicaConstructorRoot: Codable {
    let MRData: MR?
    struct MR: Codable { let StandingsTable: ST? }
    struct ST: Codable { let StandingsLists: [SL]? }
    struct SL: Codable { let ConstructorStandings: [CS]? }
    struct CS: Codable { let position: String?; let points: String?; let wins: String?; let Constructor: Con? }
    struct Con: Codable { let constructorId: String?; let name: String? }
}

private struct JolpicaScheduleRoot: Codable {
    let MRData: MR?
    struct MR: Codable { let RaceTable: RT? }
    struct RT: Codable { let Races: [R]? }
    struct R: Codable {
        let round: String; let raceName: String; let date: String; let time: String?
        let Circuit: Circ?; let Qualifying: Sess?; let Sprint: Sess?
    }
    struct Circ: Codable { let circuitName: String?; let Location: Loc? }
    struct Loc: Codable { let locality: String?; let country: String? }
    struct Sess: Codable { let date: String; let time: String? }
}

private struct JolpicaResultsRoot: Codable {
    let MRData: MR?
    struct MR: Codable { let RaceTable: RT? }
    struct RT: Codable { let Races: [R]? }
    struct R: Codable { let raceName: String; let date: String; let Results: [Res]? }
    struct Res: Codable {
        let position: String?; let points: String?; let status: String?
        let Driver: Drv?; let Constructor: Con?; let Time: Tm?
    }
    struct Drv: Codable { let givenName: String?; let familyName: String? }
    struct Con: Codable { let name: String? }
    struct Tm: Codable { let time: String? }
}

private struct OpenF1Session: Codable {
    let session_key: Int; let country_name: String?; let location: String?; let date_start: String?; let year: Int?
}
private struct OpenF1Driver: Codable {
    let driver_number: Int; let name_acronym: String?; let full_name: String?; let team_colour: String?
}
private struct OpenF1StintDTO: Codable {
    let driver_number: Int; let stint_number: Int; let lap_start: Int?; let lap_end: Int?; let compound: String?
}
private struct OpenF1RadioDTO: Codable {
    let driver_number: Int; let date: String?; let recording_url: String?
}
private struct OpenF1RaceControlDTO: Codable {
    let date: String?; let category: String?; let flag: String?; let message: String?; let lap_number: Int?
}

private struct PulseSeasonDTO: Codable { let id: String; let year: Int; let current: Bool? }
private struct PulseCategoryDTO: Codable { let id: String; let name: String }
private struct PulseStandingsRoot: Codable { let classification: [Row]?
    struct Row: Codable { let position: Int?; let points: Double?; let rider: Rider?; let team: Named?; let constructor: Named? }
    struct Rider: Codable { let id: String?; let full_name: String?; let number: Int? }
    struct Named: Codable { let name: String? }
}
private struct PulseEventDTO: Codable {
    let id: String; let name: String?; let short_name: String?; let date_start: String?; let date_end: String?
    let circuit: Named?; let country: Named?
    struct Named: Codable { let name: String? }
}
