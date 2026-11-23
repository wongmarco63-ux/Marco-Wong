import SwiftUI
import Foundation
import AVFoundation
import SafariServices
import PhotosUI
import UserNotifications
import WidgetKit
import UIKit

@main
struct ApexGridApp: App {
    @StateObject private var store = RaceStore()
    @StateObject private var radio = RadioPlayer()

    var body: some Scene {
        WindowGroup {
            RootTabsView()
                .environmentObject(store)
                .environmentObject(radio)
                .preferredColorScheme(.dark)
                .task { await store.refreshAll() }
        }
    }
}

// MARK: - Enums & Models
enum RaceSeries: String, CaseIterable, Identifiable, Hashable, Sendable {
    case f1 = "F1", motogp = "MotoGP", tcr = "TCR"
    var id: String { rawValue }
    var fullTitle: String {
        switch self {
        case .f1: return "一級方程式 Formula 1"
        case .motogp: return "世界電單車 MotoGP"
        case .tcr: return "FIA TCR 世界房車巡迴賽"
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
    case ferrari, mercedes, mclaren, redbull, ducati, hyundai, oled
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ferrari: return "法拉利紅"
        case .mercedes: return "平治青綠"
        case .mclaren: return "麥拿倫木瓜橙"
        case .redbull: return "紅牛深藍"
        case .ducati: return "Ducati 紅"
        case .hyundai: return "TCR 天藍"
        case .oled: return "純黑 OLED"
        }
    }
    var accent: Color {
        switch self {
        case .ferrari: return Color(red: 0.98, green: 0.22, blue: 0.24)
        case .mercedes: return Color(red: 0.00, green: 0.84, blue: 0.76)
        case .mclaren: return Color(red: 1.00, green: 0.54, blue: 0.10)
        case .redbull: return Color(red: 0.36, green: 0.62, blue: 1.00)
        case .ducati: return Color(red: 0.90, green: 0.10, blue: 0.16)
        case .hyundai: return Color(red: 0.42, green: 0.78, blue: 1.00)
        case .oled: return Color(red: 0.76, green: 0.86, blue: 1.00)
        }
    }
    var bgColors: [Color] {
        switch self {
        case .ferrari: return [Color(red: 0.13, green: 0.03, blue: 0.06), Color(red: 0.05, green: 0.02, blue: 0.05), Color(red: 0.015, green: 0.015, blue: 0.03)]
        case .mercedes: return [Color(red: 0.02, green: 0.11, blue: 0.12), Color(red: 0.02, green: 0.05, blue: 0.08), Color(red: 0.01, green: 0.02, blue: 0.03)]
        case .mclaren: return [Color(red: 0.14, green: 0.07, blue: 0.02), Color(red: 0.06, green: 0.035, blue: 0.02), Color(red: 0.02, green: 0.015, blue: 0.025)]
        case .redbull: return [Color(red: 0.04, green: 0.08, blue: 0.18), Color(red: 0.03, green: 0.04, blue: 0.11), Color(red: 0.01, green: 0.02, blue: 0.05)]
        case .ducati: return [Color(red: 0.16, green: 0.02, blue: 0.03), Color(red: 0.07, green: 0.02, blue: 0.03), Color(red: 0.02, green: 0.01, blue: 0.02)]
        case .hyundai: return [Color(red: 0.04, green: 0.11, blue: 0.18), Color(red: 0.02, green: 0.06, blue: 0.11), Color(red: 0.01, green: 0.02, blue: 0.04)]
        case .oled: return [Color.black, Color(white: 0.02), Color.black]
        }
    }
}

struct DriverStanding: Identifiable, Hashable {
    let id: String, series: RaceSeries, position: Int, name: String, shortCode: String, team: String, points: Double, wins: Int, colorHex: String
}
struct TeamStanding: Identifiable, Hashable {
    let id: String, position: Int, name: String, points: Double, colorHex: String
}
struct RaceEvent: Identifiable, Hashable {
    let id: String, series: RaceSeries, round: Int, name: String, circuit: String, raceDate: Date
}
struct RaceResultRow: Identifiable, Hashable {
    let id: String, position: Int, driverName: String, teamName: String, status: String
}
struct LatestSummary {
    let raceName: String, results: [RaceResultRow]
}
struct F1Stint: Identifiable {
    let id = UUID(), lapStart: Int, lapEnd: Int, compound: String
    var laps: Int { max(1, lapEnd - lapStart + 1) }
    var color: Color {
        switch compound.uppercased() {
        case "SOFT": return Color(red: 0.94, green: 0.20, blue: 0.22)
        case "MEDIUM": return Color(red: 0.98, green: 0.82, blue: 0.16)
        case "HARD": return Color(white: 0.92)
        case "INTERMEDIATE": return Color(red: 0.20, green: 0.80, blue: 0.36)
        case "WET": return Color(red: 0.16, green: 0.56, blue: 0.98)
        default: return Color.gray
        }
    }
    var letter: String { String(compound.prefix(1)).uppercased() }
}
struct F1Strategy: Identifiable {
    let id: Int, acronym: String, colorHex: String, stints: [F1Stint]
    var totalLaps: Int { stints.map(\.lapEnd).max() ?? 1 }
}
struct F1Radio: Identifiable {
    let id: String, acronym: String, fullName: String, colorHex: String, date: Date, url: String
}
struct F1ControlMsg: Identifiable {
    let id = UUID(), date: Date, flag: String, message: String, lap: Int?
    var isCritical: Bool {
        let l = "\(flag) \(message)".lowercased()
        return l.contains("red") || l.contains("penalty") || l.contains("safety") || l.contains("investigation")
    }
}
struct F1Weather { let airTemp: Double, trackTemp: Double, humidity: Double, isRaining: Bool }
struct F1SpeedRow: Identifiable { let id: Int, acronym: String, fullName: String, colorHex: String, kmh: Int }
struct F1PitRow: Identifiable { let id = UUID(), acronym: String, colorHex: String, lap: Int, sec: Double }
struct NewsItem: Identifiable, Sendable { let id: String, series: RaceSeries, title: String, link: String, date: Date, source: String, badge: String?, isBreaking: Bool }
struct IdentifiableURL: Identifiable { let id = UUID(), url: URL }

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&v)
        if clean.count == 6 {
            self.init(red: Double((v >> 16) & 0xFF) / 255.0, green: Double((v >> 8) & 0xFF) / 255.0, blue: Double(v & 0xFF) / 255.0)
        } else {
            self.init(red: 0.55, green: 0.72, blue: 0.98)
        }
    }
}

enum RaceFmt {
    static let tz = TimeZone(identifier: "Asia/Macau") ?? .current
    static let full: DateFormatter = { let f = DateFormatter(); f.timeZone = tz; f.dateFormat = "M月d日 HH:mm"; return f }()
    static let md: DateFormatter = { let f = DateFormatter(); f.timeZone = tz; f.dateFormat = "M.d"; return f }()
    static let hm: DateFormatter = { let f = DateFormatter(); f.timeZone = tz; f.dateFormat = "HH:mm"; return f }()
    static let ymd: DateFormatter = { let f = DateFormatter(); f.timeZone = tz; f.dateFormat = "yyyy.MM.dd"; return f }()

    static func parseISO(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let f1 = ISO8601DateFormatter(); f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: raw) { return d }
        if let d = ISO8601DateFormatter().date(from: raw) { return d }
        let f2 = DateFormatter(); f2.locale = Locale(identifier: "en_US_POSIX"); f2.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return f2.date(from: raw)
    }
    static func countdown(to date: Date) -> (d: Int, h: Int, m: Int) {
        let s = max(0, Int(date.timeIntervalSinceNow))
        return (s / 86400, (s % 86400) / 3600, (s % 3600) / 60)
    }
    static func relative(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 3600 { return "\(max(1, s / 60))分鐘前" }
        if s < 86400 { return "\(s / 3600)小時前" }
        return "\(s / 86400)日前"
    }
}

// MARK: - AI Translation & RSS Parser
enum AITranslator {
    static let glossary: [String: String] = [
        "Australian Grand Prix": "澳洲大獎賽", "Chinese Grand Prix": "中國大獎賽", "Japanese Grand Prix": "日本大獎賽",
        "Bahrain Grand Prix": "巴林大獎賽", "Saudi Arabian Grand Prix": "沙特阿拉伯大獎賽", "Miami Grand Prix": "邁阿密大獎賽",
        "Monaco Grand Prix": "摩納哥大獎賽", "Spanish Grand Prix": "西班牙大獎賽", "Canadian Grand Prix": "加拿大大獎賽",
        "Austrian Grand Prix": "奧地利大獎賽", "British Grand Prix": "英國大獎賽", "Belgian Grand Prix": "比利時大獎賽",
        "Hungarian Grand Prix": "匈牙利大獎賽", "Dutch Grand Prix": "荷蘭大獎賽", "Italian Grand Prix": "意大利大獎賽",
        "Azerbaijan Grand Prix": "阿塞拜疆大獎賽", "Singapore Grand Prix": "新加坡大獎賽", "United States Grand Prix": "美國大獎賽",
        "Mexico City Grand Prix": "墨西哥城大獎賽", "São Paulo Grand Prix": "聖保羅大獎賽", "Las Vegas Grand Prix": "拉斯維加斯大獎賽",
        "Qatar Grand Prix": "卡塔爾大獎賽", "Abu Dhabi Grand Prix": "阿布扎比大獎賽", "Madrid Grand Prix": "馬德里大獎賽",
        "Finished": "完賽", "Retired": "退賽", "Collision": "碰撞退賽", "Disqualified": "取消資格"
    ]

    static func translateFree(_ text: String) async -> String? {
        if let hit = glossary[text] { return hit }
        guard var c = URLComponents(string: "https://translate.googleapis.com/translate_a/single") else { return nil }
        c.queryItems = [
            URLQueryItem(name: "client", value: "gtx"), URLQueryItem(name: "sl", value: "en"),
            URLQueryItem(name: "tl", value: "zh-TW"), URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]
        guard let url = c.url else { return nil }
        var req = URLRequest(url: url); req.timeoutInterval = 8
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let root = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let segs = root.first as? [Any] else { return nil }
        let raw = segs.compactMap { ($0 as? [Any])?.first as? String }.joined()
        let out = raw.replacingOccurrences(of: "安全汽車", with: "安全車")
            .replacingOccurrences(of: "梅賽德斯", with: "平治")
            .replacingOccurrences(of: "邁凱倫", with: "麥拿倫")
            .replacingOccurrences(of: "維斯塔潘", with: "韋斯達賓")
            .replacingOccurrences(of: "漢密爾頓", with: "咸美頓")
            .replacingOccurrences(of: "勒克萊爾", with: "陸克萊")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return out.isEmpty ? nil : out
    }

    static func callGemini(prompt: String, apiKey: String) async -> String? {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(key)") else { return nil }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["contents": [["parts": [["text": prompt]]]]])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cand = (json["candidates"] as? [[String: Any]])?.first,
              let content = cand["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class RSSParser: NSObject, XMLParserDelegate {
    private var items: [NewsItem] = []
    private var el = "", t = "", l = "", d = "", inItem = false
    private let series: RaceSeries, source: String
    init(series: RaceSeries, source: String) { self.series = series; self.source = source }

    func parse(_ data: Data) -> [NewsItem] {
        let p = XMLParser(data: data); p.delegate = self; p.parse(); return items
    }
    func parser(_ p: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName q: String?, attributes attr: [String: String] = [:]) {
        el = name.lowercased()
        if el == "item" || el == "entry" { inItem = true; t = ""; l = ""; d = "" }
        else if inItem && el == "link", let href = attr["href"], !href.isEmpty { l = href }
    }
    func parser(_ p: XMLParser, foundCharacters str: String) {
        guard inItem else { return }
        if el == "title" { t += str } else if el == "link" { l += str } else if el == "pubdate" || el == "published" { d += str }
    }
    func parser(_ p: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName q: String?) {
        let tag = name.lowercased()
        guard tag == "item" || tag == "entry" else { return }
        inItem = false
        let title = t.replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&#8217;", with: "'").replacingOccurrences(of: "&quot;", with: "\"").trimmingCharacters(in: .whitespacesAndNewlines)
        let link = l.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !link.isEmpty else { return }
        let lower = title.lowercased()
        let badge: String? = (lower.contains("penalty") || lower.contains("dsq") || lower.contains("steward")) ? "判罰"
            : (lower.contains("red flag") || lower.contains("crash")) ? "紅旗 / 意外"
            : (lower.contains("macau") || lower.contains("guia")) ? "澳門站"
            : (lower.contains("champion") || lower.contains("signs") || lower.contains("official")) ? "焦點" : nil
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        let dt = f.date(from: d.trimmingCharacters(in: .whitespacesAndNewlines)) ?? RaceFmt.parseISO(d.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Date()
        items.append(NewsItem(id: link, series: series, title: title, link: link, date: dt, source: source, badge: badge, isBreaking: badge != nil))
    }
}

@MainActor
final class RadioPlayer: ObservableObject {
    @Published var currentURL: String?
    @Published var isPlaying = false
    private var player: AVPlayer?
    private var obs: Any?

    func toggle(_ urlStr: String) {
        if currentURL == urlStr && isPlaying { stop(); return }
        stop()
        guard let url = URL(string: urlStr) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        currentURL = urlStr
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        obs = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isPlaying = false; self?.currentURL = nil }
        }
        player?.play(); isPlaying = true
    }
    func stop() {
        player?.pause(); player = nil
        if let o = obs { NotificationCenter.default.removeObserver(o); obs = nil }
        isPlaying = false; currentURL = nil
    }
}

@MainActor
final class WallpaperRepo: ObservableObject {
    static let shared = WallpaperRepo()
    @Published var image: UIImage?
    private var url: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("apexgrid_wall.jpg") }
    init() { if let d = try? Data(contentsOf: url), let img = UIImage(data: d) { image = img } }
    func save(_ img: UIImage) {
        if let d = img.jpegData(compressionQuality: 0.85) { try? d.write(to: url, options: .atomic) }
        image = img
    }
    func remove() { try? FileManager.default.removeItem(at: url); image = nil }
}

// MARK: - Main Store
@MainActor
final class RaceStore: ObservableObject {
    private let ud = UserDefaults.standard
    private let transKey = "ag_trans_v4"

    @Published var isLoading = false
    @Published var isTranslating = false
    @Published var lastUpdated: Date?
    @Published var drivers: [RaceSeries: [DriverStanding]] = [:]
    @Published var teams: [RaceSeries: [TeamStanding]] = [:]
    @Published var schedules: [RaceSeries: [RaceEvent]] = [:]
    @Published var latestF1: LatestSummary?

    @Published var openF1Name = ""
    @Published var strategies: [F1Strategy] = []
    @Published var radios: [F1Radio] = []
    @Published var controls: [F1ControlMsg] = []
    @Published var weather: F1Weather?
    @Published var speeds: [F1SpeedRow] = []
    @Published var pits: [F1PitRow] = []
    @Published var fastestLap = "--"

    @Published var news: [NewsItem] = []
    @Published var transCache: [String: String] = [:]
    @Published var briefing = ""
    @Published var isBriefing = false

    @Published var spoilerFree: Bool { didSet { ud.set(spoilerFree, forKey: "ag_sp") } }
    @Published var theme: TeamTheme { didSet { ud.set(theme.rawValue, forKey: "ag_th") } }
    @Published var wallBlur: Double { didSet { ud.set(wallBlur, forKey: "ag_wb") } }
    @Published var wallDim: Double { didSet { ud.set(wallDim, forKey: "ag_wd") } }
    @Published var particles: Bool { didSet { ud.set(particles, forKey: "ag_pt") } }
    @Published var autoTranslate: Bool { didSet { ud.set(autoTranslate, forKey: "ag_at") } }
    @Published var showEnglish: Bool { didSet { ud.set(showEnglish, forKey: "ag_se") } }
    @Published var onlyBreaking: Bool { didSet { ud.set(onlyBreaking, forKey: "ag_ob") } }
    @Published var geminiKey: String { didSet { ud.set(geminiKey, forKey: "ag_gk") } }

    init() {
        let u = UserDefaults.standard
        spoilerFree = u.object(forKey: "ag_sp") as? Bool ?? false
        theme = TeamTheme(rawValue: u.string(forKey: "ag_th") ?? "") ?? .ferrari
        wallBlur = u.object(forKey: "ag_wb") as? Double ?? 8.0
        wallDim = u.object(forKey: "ag_wd") as? Double ?? 0.50
        particles = u.object(forKey: "ag_pt") as? Bool ?? true
        autoTranslate = u.object(forKey: "ag_at") as? Bool ?? true
        showEnglish = u.object(forKey: "ag_se") as? Bool ?? true
        onlyBreaking = u.object(forKey: "ag_ob") as? Bool ?? false
        geminiKey = u.string(forKey: "ag_gk") ?? ""
        transCache = u.dictionary(forKey: transKey) as? [String: String] ?? [:]
        seedFallbacks()
    }

    func haptic() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    func tr(_ s: String) -> String { autoTranslate ? (transCache[s] ?? AITranslator.glossary[s] ?? s) : s }
    func hasTr(_ s: String) -> Bool { transCache[s] != nil || AITranslator.glossary[s] != nil }

    func refreshAll() async {
        isLoading = true
        defer { isLoading = false; lastUpdated = Date(); WidgetCenter.shared.reloadAllTimelines() }
        async let a: Void = fetchF1()
        async let b: Void = fetchMotoGP()
        async let c: Void = fetchNews()
        async let d: Void = fetchOpenF1()
        _ = await (a, b, c, d)
        if autoTranslate { await translateAll() }
    }

    func translateAll() async {
        guard autoTranslate else { return }
        var targets = news.prefix(20).map(\.title).filter { transCache[$0] == nil && AITranslator.glossary[$0] == nil }
        targets += controls.prefix(12).map(\.message).filter { transCache[$0] == nil }
        guard !targets.isEmpty else { return }
        isTranslating = true
        defer { isTranslating = false }

        if !geminiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let numbered = targets.prefix(22).enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            let prompt = "你係港澳賽車編輯，請將以下英文賽車新聞或FIA判罰翻譯做自然繁體中文，嚴格保留原本編號每行一條輸出：\n\(numbered)"
            if let out = await AITranslator.callGemini(prompt: prompt, apiKey: geminiKey) {
                for line in out.components(separatedBy: .newlines) {
                    if let dot = line.firstIndex(of: "."), let idx = Int(line[..<dot].trimmingCharacters(in: .whitespaces)), idx >= 1, idx <= targets.count {
                        let zh = String(line[line.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
                        if !zh.isEmpty { transCache[targets[idx - 1]] = zh }
                    }
                }
                ud.set(transCache, forKey: transKey)
                return
            }
        }

        await withTaskGroup(of: (String, String?).self) { group in
            for t in targets.prefix(20) { group.addTask { (t, await AITranslator.translateFree(t)) } }
            for await (orig, zh) in group { if let zh { transCache[orig] = zh } }
        }
        ud.set(transCache, forKey: transKey)
    }

    func makeBriefing() async {
        isBriefing = true
        defer { isBriefing = false }
        var ctx = ""
        for s in RaceSeries.allCases {
            if let list = drivers[s], let p1 = list.first {
                let gap = list.count > 1 ? Int(p1.points - list[1].points) : 0
                ctx += "\(s.rawValue) P1: \(p1.name) (\(p1.team)) \(Int(p1.points))分 (+\(gap))\n"
            }
        }
        if let spd = speeds.first { ctx += "F1 尾速王: \(spd.acronym) \(spd.kmh) km/h\n" }
        if let pit = pits.first { ctx += "最快進站: \(pit.acronym) \(String(format: "%.2f", pit.sec))s\n" }
        ctx += news.prefix(4).map { "新聞: \(tr($0.title))" }.joined(separator: "\n")

        if let ai = await AITranslator.callGemini(prompt: "用自然流暢嘅廣東話（約180字、分3-4點）總結以下最新賽車戰況同新聞：\n\(ctx)", apiKey: geminiKey) {
            briefing = ai
        } else {
            briefing = "🏁 即時賽車重點速報\n\n" + ctx + "\n\n💡 喺「設定」貼入免費 Gemini API Key 即可解鎖 AI 廣東話深度賽評。"
        }
    }

    func nextEvent(_ s: RaceSeries) -> RaceEvent? { (schedules[s] ?? []).first { $0.raceDate > Date() } ?? (schedules[s] ?? []).last }
    func nextGlobal() -> RaceEvent? { RaceSeries.allCases.compactMap { s in (schedules[s] ?? []).first { $0.raceDate > Date() } }.sorted { $0.raceDate < $1.raceDate }.first }
    func f1Progress() -> (Int, Int) { let a = schedules[.f1] ?? []; return a.isEmpty ? (0, 24) : (a.filter { $0.raceDate < Date() }.count, a.count) }

    func remind(_ ev: RaceEvent) async -> Bool {
        let c = UNUserNotificationCenter.current()
        do {
            let granted = try await c.requestAuthorization(options: [.alert, .sound])
            guard granted else { return false }
            let dt = ev.raceDate.addingTimeInterval(-900)
            guard dt > Date() else { return false }
            let n = UNMutableNotificationContent()
            n.title = "🏁 \(ev.series.rawValue) 仲有 15 分鐘開波！"
            n.body = "\(tr(ev.name)) 澳門時間 \(RaceFmt.hm.string(from: ev.raceDate)) 起跑。"
            n.sound = .default
            let trig = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dt), repeats: false)
            try await c.add(UNNotificationRequest(identifier: "r_\(ev.id)", content: n, trigger: trig))
            return true
        } catch {
            return false
        }
    }

    private func fetchF1() async {
        if let u = URL(string: "https://api.jolpi.ca/ergast/f1/current/driverStandings.json"),
           let (d, _) = try? await URLSession.shared.data(from: u),
           let r = try? JSONDecoder().decode(JDriverRoot.self, from: d),
           let list = r.MRData?.StandingsTable?.StandingsLists?.first?.DriverStandings, !list.isEmpty {
            drivers[.f1] = list.map {
                let team = $0.Constructors?.first?.name ?? "F1"
                let code = $0.Driver?.code ?? String(($0.Driver?.familyName ?? "DRV").prefix(3)).uppercased()
                return DriverStanding(id: "f1_\($0.Driver?.driverId ?? code)", series: .f1, position: Int($0.position ?? "0") ?? 0, name: "\($0.Driver?.givenName ?? "") \($0.Driver?.familyName ?? "")", shortCode: code, team: team, points: Double($0.points ?? "0") ?? 0, wins: Int($0.wins ?? "0") ?? 0, colorHex: Self.f1Color(team))
            }
        }
        if let u = URL(string: "https://api.jolpi.ca/ergast/f1/current/constructorStandings.json"),
           let (d, _) = try? await URLSession.shared.data(from: u),
           let r = try? JSONDecoder().decode(JTeamRoot.self, from: d),
           let list = r.MRData?.StandingsTable?.StandingsLists?.first?.ConstructorStandings, !list.isEmpty {
            teams[.f1] = list.map {
                let n = $0.Constructor?.name ?? "Team"
                return TeamStanding(id: "f1t_\(n)", position: Int($0.position ?? "0") ?? 0, name: n, points: Double($0.points ?? "0") ?? 0, colorHex: Self.f1Color(n))
            }
        }
        if let u = URL(string: "https://api.jolpi.ca/ergast/f1/current.json"),
           let (d, _) = try? await URLSession.shared.data(from: u),
           let r = try? JSONDecoder().decode(JSchedRoot.self, from: d),
           let races = r.MRData?.RaceTable?.Races, !races.isEmpty {
            schedules[.f1] = races.compactMap {
                guard let dt = RaceFmt.parseISO("\($0.date)T\($0.time ?? "12:00:00Z")") else { return nil }
                return RaceEvent(id: "f1_\($0.round)", series: .f1, round: Int($0.round) ?? 0, name: $0.raceName, circuit: $0.Circuit?.circuitName ?? "", raceDate: dt)
            }
        }
        if let u = URL(string: "https://api.jolpi.ca/ergast/f1/current/last/results.json"),
           let (d, _) = try? await URLSession.shared.data(from: u),
           let r = try? JSONDecoder().decode(JResRoot.self, from: d),
           let race = r.MRData?.RaceTable?.Races?.first, let list = race.Results {
            latestF1 = LatestSummary(raceName: race.raceName, results: list.map {
                RaceResultRow(id: "res_\($0.position ?? "0")_\($0.Driver?.familyName ?? "")", position: Int($0.position ?? "0") ?? 0, driverName: "\($0.Driver?.givenName ?? "") \($0.Driver?.familyName ?? "")", teamName: $0.Constructor?.name ?? "", status: $0.Time?.time ?? ($0.status ?? ""))
            })
        }
    }

    func fetchOpenF1() async {
        let yr = Calendar.current.component(.year, from: Date())
        var chosen: OSession?
        for y in [yr, yr - 1] {
            if let u = URL(string: "https://api.openf1.org/v1/sessions?session_name=Race&year=\(y)"),
               let (d, resp) = try? await URLSession.shared.data(from: u), (resp as? HTTPURLResponse)?.statusCode == 200,
               let list = try? JSONDecoder().decode([OSession].self, from: d) {
                chosen = list.last(where: { (RaceFmt.parseISO($0.date_start) ?? .distantFuture) < Date() }) ?? list.last
                if chosen != nil { break }
            }
        }
        guard let s = chosen else { return }
        openF1Name = "\(s.country_name ?? "F1") GP · \(s.location ?? "")"
        let sk = s.session_key

        var dmap: [Int: ODriver] = [:]
        if let u = URL(string: "https://api.openf1.org/v1/drivers?session_key=\(sk)"),
           let (d, _) = try? await URLSession.shared.data(from: u),
           let list = try? JSONDecoder().decode([ODriver].self, from: d) {
            for x in list { dmap[x.driver_number] = x }
        }
        if let u = URL(string: "https://api.openf1.org/v1/stints?session_key=\(sk)"),
           let (d, _) = try? await URLSession.shared.data(from: u),
           let list = try? JSONDecoder().decode([OStint].self, from: d) {
            let grouped = Dictionary(grouping: list, by: \.driver_number)
            strategies = grouped.map { num, arr in
                let st = arr.sorted { $0.stint_number < $1.stint_number }.map { F1Stint(lapStart: $0.lap_start ?? 1, lapEnd: $0.lap_end ?? 1, compound: $0.compound ?? "?") }
                let i = dmap[num]
                return F1Strategy(id: num, acronym: i?.name_acronym ?? "#\(num)", colorHex: i?.team_colour ?? "88AADD", stints: st)
            }.sorted { $0.totalLaps > $1.totalLaps }
        }
        try? await Task.sleep(nanoseconds: 250_000_000)
        if let u = URL(string: "https://api.openf1.org/v1/weather?session_key=\(sk)"),
           let (d, _) = try? await URLSession.shared.data(from: u),
           let last = (try? JSONDecoder().decode([OWeather].self, from: d))?.last {
            weather = F1Weather(airTemp: last.air_temperature ?? 24, trackTemp: last.track_temperature ?? 34, humidity: last.humidity ?? 55, isRaining: (last.rainfall ?? 0) > 0)
        }
        if let u = URL(string: "https://api.openf1.org/v1/pit?session_key=\(sk)"),
           let (d, _) = try? await URLSession.shared.data(from: u),
           let list = try? JSONDecoder().decode([OPit].self, from: d) {
            pits = Array(list.compactMap { p -> F1PitRow? in
                guard let dur = p.pit_duration, dur > 1.5, dur < 60 else { return nil }
                let i = dmap[p.driver_number]
                return F1PitRow(acronym: i?.name_acronym ?? "#\(p.driver_number)", colorHex: i?.team_colour ?? "FFFFFF", lap: p.lap_number ?? 0, sec: dur)
            }.sorted { $0.sec < $1.sec }.prefix(8))
        }
        try? await Task.sleep(nanoseconds: 250_000_000)
        if let u = URL(string: "https://api.openf1.org/v1/laps?session_key=\(sk)"),
           let (d, _) = try? await URLSession.shared.data(from: u),
           let list = try? JSONDecoder().decode([OLap].self, from: d) {
            var sp: [Int: Int] = [:]; var best: (Int, Double)?
            for l in list {
                if let v = l.st_speed, v > 150, v < 400 { sp[l.driver_number] = max(sp[l.driver_number] ?? 0, v) }
                if let dur = l.lap_duration, dur > 50, dur < 200, (best == nil || dur < best!.1) { best = (l.driver_number, dur) }
            }
            speeds = sp.map { num, kmh in
                let i = dmap[num]
                return F1SpeedRow(id: num, acronym: i?.name_acronym ?? "#\(num)", fullName: i?.full_name ?? "#\(num)", colorHex: i?.team_colour ?? "88CCFF", kmh: kmh)
            }.sorted { $0.kmh > $1.kmh }
            if let b = best {
                fastestLap = String(format: "%@ %d:%06.3f", dmap[b.0]?.name_acronym ?? "#\(b.0)", Int(b.1) / 60, b.1 - Double((Int(b.1) / 60) * 60))
            }
        }
        try? await Task.sleep(nanoseconds: 250_000_000)
        if let u = URL(string: "https://api.openf1.org/v1/team_radio?session_key=\(sk)"),
           let (d, _) = try? await URLSession.shared.data(from: u),
           let list = try? JSONDecoder().decode([ORadio].self, from: d) {
            radios = Array(list.compactMap { r -> F1Radio? in
                guard let rec = r.recording_url, !rec.isEmpty else { return nil }
                let i = dmap[r.driver_number]
                return F1Radio(id: rec, acronym: i?.name_acronym ?? "#\(r.driver_number)", fullName: i?.full_name ?? "#\(r.driver_number)", colorHex: i?.team_colour ?? "E82028", date: RaceFmt.parseISO(r.date) ?? Date(), url: rec)
            }.sorted { $0.date > $1.date }.prefix(30))
        }
        if let u = URL(string: "https://api.openf1.org/v1/race_control?session_key=\(sk)"),
           let (d, _) = try? await URLSession.shared.data(from: u),
           let list = try? JSONDecoder().decode([OControl].self, from: d) {
            controls = Array(list.compactMap { m -> F1ControlMsg? in
                guard let txt = m.message, !txt.isEmpty else { return nil }
                return F1ControlMsg(date: RaceFmt.parseISO(m.date) ?? Date(), flag: m.flag ?? m.category ?? "INFO", message: txt, lap: m.lap_number)
            }.sorted { $0.date > $1.date }.prefix(25))
        }
    }

    private func fetchMotoGP() async {
        guard let u1 = URL(string: "https://api.motogp.pulselive.com/motogp/v1/results/seasons"),
              let (d1, _) = try? await URLSession.shared.data(from: u1),
              let seasons = try? JSONDecoder().decode([PSeason].self, from: d1),
              let cur = seasons.first(where: { $0.current == true }) ?? seasons.sorted(by: { $0.year > $1.year }).first,
              let u2 = URL(string: "https://api.motogp.pulselive.com/motogp/v1/results/categories?seasonUuid=\(cur.id)"),
              let (d2, _) = try? await URLSession.shared.data(from: u2),
              let cats = try? JSONDecoder().decode([PCat].self, from: d2),
              let gp = cats.first(where: { $0.name.lowercased().contains("motogp") }) ?? cats.first else { return }

        if let u3 = URL(string: "https://api.motogp.pulselive.com/motogp/v1/results/standings?seasonUuid=\(cur.id)&categoryUuid=\(gp.id)"),
           let (d3, _) = try? await URLSession.shared.data(from: u3),
           let rows = (try? JSONDecoder().decode(PStandRoot.self, from: d3))?.classification, !rows.isEmpty {
            drivers[.motogp] = rows.enumerated().map { idx, row in
                let fn = row.rider?.full_name ?? "Rider"
                let code = String((fn.split(separator: " ").last ?? Substring(fn)).prefix(3)).uppercased()
                let tm = row.team?.name ?? row.constructor?.name ?? "MotoGP"
                return DriverStanding(id: "m_\(idx)_\(code)", series: .motogp, position: row.position ?? (idx + 1), name: fn, shortCode: code, team: tm, points: row.points ?? 0, wins: 0, colorHex: Self.motoColor(tm))
            }
        }
        if let u4 = URL(string: "https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=\(cur.id)&isFinished=false"),
           let (d4, _) = try? await URLSession.shared.data(from: u4),
           let evs = try? JSONDecoder().decode([PEvent].self, from: d4), !evs.isEmpty {
            let mapped = evs.enumerated().compactMap { idx, e -> RaceEvent? in
                guard let dt = RaceFmt.parseISO(e.date_end ?? e.date_start) else { return nil }
                return RaceEvent(id: "me_\(e.id)", series: .motogp, round: idx + 1, name: e.name ?? "MotoGP", circuit: e.circuit?.name ?? "", raceDate: dt)
            }
            if !mapped.isEmpty { schedules[.motogp] = mapped }
        }
    }

    private func fetchNews() async {
        let feeds: [(RaceSeries, String, String)] = [
            (.f1, "Motorsport F1", "https://www.motorsport.com/rss/f1/news/"),
            (.motogp, "Motorsport MotoGP", "https://www.motorsport.com/rss/motogp/news/"),
            (.tcr, "TouringCarTimes", "https://www.touringcartimes.com/feed/")
        ]
        var all: [NewsItem] = []
        await withTaskGroup(of: [NewsItem].self) { g in
            for f in feeds {
                g.addTask {
                    guard let u = URL(string: f.2) else { return [] }
                    var req = URLRequest(url: u); req.timeoutInterval = 10; req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
                    guard let (d, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
                    return Array(RSSParser(series: f.0, source: f.1).parse(d).prefix(12))
                }
            }
            for await batch in g { all.append(contentsOf: batch) }
        }
        var seen = Set<String>()
        let unique = all.filter { seen.insert($0.id).inserted }.sorted { $0.date > $1.date }
        if !unique.isEmpty { news = unique }
    }

    private func seedFallbacks() {
        drivers[.tcr] = [
            DriverStanding(id: "t1", series: .tcr, position: 1, name: "Norbert Michelisz", shortCode: "MIC", team: "BRC Hyundai N", points: 323, wins: 3, colorHex: "40B8FF"),
            DriverStanding(id: "t2", series: .tcr, position: 2, name: "Thed Björk", shortCode: "BJO", team: "Cyan Racing Lynk & Co", points: 312, wins: 3, colorHex: "00A8E8"),
            DriverStanding(id: "t3", series: .tcr, position: 3, name: "Mikel Azcona", shortCode: "AZC", team: "BRC Hyundai N", points: 295, wins: 2, colorHex: "40B8FF"),
            DriverStanding(id: "t4", series: .tcr, position: 4, name: "Esteban Guerrieri", shortCode: "GUE", team: "GOAT Racing Honda", points: 291, wins: 2, colorHex: "E62020"),
            DriverStanding(id: "t5", series: .tcr, position: 5, name: "Ma Qing Hua", shortCode: "MAQ", team: "Cyan Racing Lynk & Co", points: 234, wins: 1, colorHex: "00A8E8")
        ]
        teams[.tcr] = [
            TeamStanding(id: "tt1", position: 1, name: "Cyan Racing Lynk & Co", points: 735, colorHex: "00A8E8"),
            TeamStanding(id: "tt2", position: 2, name: "BRC Hyundai N", points: 678, colorHex: "40B8FF"),
            TeamStanding(id: "tt3", position: 3, name: "GOAT Racing Honda", points: 482, colorHex: "E62020")
        ]
        schedules[.tcr] = [RaceEvent(id: "tcr_mo", series: .tcr, round: 7, name: "澳門格蘭披治 · 東望洋大賽", circuit: "東望洋跑道 Guia Circuit", raceDate: Date().addingTimeInterval(86400 * 355))]
        drivers[.motogp] = [
            DriverStanding(id: "m1", series: .motogp, position: 1, name: "Marc Márquez", shortCode: "MAR", team: "Ducati Lenovo Team", points: 439, wins: 9, colorHex: "E01018"),
            DriverStanding(id: "m2", series: .motogp, position: 2, name: "Jorge Martín", shortCode: "MRT", team: "Aprilia Racing", points: 396, wins: 5, colorHex: "22C55E"),
            DriverStanding(id: "m3", series: .motogp, position: 3, name: "Marco Bezzecchi", shortCode: "BEZ", team: "Aprilia Racing", points: 394, wins: 4, colorHex: "22C55E")
        ]
    }

    static func f1Color(_ n: String) -> String {
        let l = n.lowercased()
        if l.contains("ferrari") { return "E8002D" }; if l.contains("mercedes") { return "00D2BE" }
        if l.contains("mclaren") { return "FF8000" }; if l.contains("red bull") { return "3671C6" }
        if l.contains("aston") { return "229971" }; if l.contains("williams") { return "64C4FF" }
        return "99AACC"
    }
    static func motoColor(_ n: String) -> String {
        let l = n.lowercased()
        if l.contains("ducati") { return "E01018" }; if l.contains("aprilia") { return "22C55E" }
        if l.contains("ktm") { return "FF6B00" }; if l.contains("yamaha") { return "1D4ED8" }
        return "A855F7"
    }
}

// MARK: - DTOs
private struct JDriverRoot: Codable { let MRData: MR?; struct MR: Codable { let StandingsTable: ST? }; struct ST: Codable { let StandingsLists: [SL]? }; struct SL: Codable { let DriverStandings: [R]? }; struct R: Codable { let position: String?; let points: String?; let wins: String?; let Driver: D?; let Constructors: [C]? }; struct D: Codable { let driverId: String?; let code: String?; let givenName: String?; let familyName: String? }; struct C: Codable { let name: String? } }
private struct JTeamRoot: Codable { let MRData: MR?; struct MR: Codable { let StandingsTable: ST? }; struct ST: Codable { let StandingsLists: [SL]? }; struct SL: Codable { let ConstructorStandings: [R]? }; struct R: Codable { let position: String?; let points: String?; let Constructor: C? }; struct C: Codable { let name: String? } }
private struct JSchedRoot: Codable { let MRData: MR?; struct MR: Codable { let RaceTable: RT? }; struct RT: Codable { let Races: [R]? }; struct R: Codable { let round: String; let raceName: String; let date: String; let time: String?; let Circuit: C? }; struct C: Codable { let circuitName: String? } }
private struct JResRoot: Codable { let MRData: MR?; struct MR: Codable { let RaceTable: RT? }; struct RT: Codable { let Races: [R]? }; struct R: Codable { let raceName: String; let Results: [Row]? }; struct Row: Codable { let position: String?; let status: String?; let Driver: D?; let Constructor: C?; let Time: T? }; struct D: Codable { let givenName: String?; let familyName: String? }; struct C: Codable { let name: String? }; struct T: Codable { let time: String? } }
private struct OSession: Codable { let session_key: Int; let country_name: String?; let location: String?; let date_start: String? }
private struct ODriver: Codable { let driver_number: Int; let name_acronym: String?; let full_name: String?; let team_colour: String? }
private struct OStint: Codable { let driver_number: Int; let stint_number: Int; let lap_start: Int?; let lap_end: Int?; let compound: String? }
private struct OWeather: Codable { let air_temperature: Double?; let track_temperature: Double?; let humidity: Double?; let rainfall: Int? }
private struct OPit: Codable { let driver_number: Int; let lap_number: Int?; let pit_duration: Double? }
private struct OLap: Codable { let driver_number: Int; let lap_duration: Double?; let st_speed: Int? }
private struct ORadio: Codable { let driver_number: Int; let date: String?; let recording_url: String? }
private struct OControl: Codable { let date: String?; let category: String?; let flag: String?; let message: String?; let lap_number: Int? }
private struct PSeason: Codable { let id: String; let year: Int; let current: Bool? }
private struct PCat: Codable { let id: String; let name: String }
private struct PStandRoot: Codable { let classification: [R]?; struct R: Codable { let position: Int?; let points: Double?; let rider: Rd?; let team: Nm?; let constructor: Nm? }; struct Rd: Codable { let full_name: String? }; struct Nm: Codable { let name: String? } }
private struct PEvent: Codable { let id: String; let name: String?; let date_start: String?; let date_end: String?; let circuit: Nm?; struct Nm: Codable { let name: String? } }

// MARK: - Shared UI
struct RacingBG: View {
    @EnvironmentObject var store: RaceStore
    @ObservedObject private var wall = WallpaperRepo.shared
    var body: some View {
        ZStack {
            if let img = wall.image {
                GeometryReader { g in Image(uiImage: img).resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped().blur(radius: store.wallBlur).scaleEffect(1.06) }
                Color.black.opacity(store.wallDim)
            } else {
                LinearGradient(colors: store.theme.bgColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [store.theme.accent.opacity(0.26), Color.clear], center: .top, startRadius: 20, endRadius: 420)
            }
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    var radius: CGFloat = 24
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.ultraThinMaterial.opacity(0.62)))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(LinearGradient(colors: [Color.white.opacity(0.24), Color.white.opacity(0.06), Color.white.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.32), radius: 14, y: 8)
    }
}

struct StarRingView: View {
    let animate: Bool
    let tint: Color
    var body: some View {
        if animate { TimelineView(.animation) { tl in draw(tl.date.timeIntervalSinceReferenceDate) } }
        else { draw(14) }
    }
    private func draw(_ t: Double) -> some View {
        Canvas { ctx, sz in
            let c = CGPoint(x: sz.width / 2, y: sz.height / 2), base = min(sz.width, sz.height) * 0.37
            for i in 0..<220 {
                let s1 = rnd(i * 3 + 1), s2 = rnd(i * 3 + 2), s3 = rnd(i * 3 + 3)
                let ang = s1 * .pi * 2 + t * (0.04 + s3 * 0.08) * (i % 2 == 0 ? 1 : -1)
                let r = base + (s1 + s2 - 1) * (base * 0.42) + sin(t * (0.6 + s2) + Double(i)) * 4
                let dr = s3 > 0.85 ? 2.3 : (s3 > 0.55 ? 1.5 : 0.95)
                let op = (0.25 + 0.75 * abs(sin(t * (0.9 + s3 * 1.4) + Double(i) * 0.7))) * 0.88
                ctx.fill(Path(ellipseIn: CGRect(x: c.x + cos(ang) * r - dr, y: c.y + sin(ang) * r - dr, width: dr * 2, height: dr * 2)), with: .color((i % 4 == 0 ? tint : Color.white).opacity(op)))
            }
        }
    }
    private func rnd(_ seed: Int) -> Double { let x = sin(Double(seed) * 12.9898) * 43758.5453; return x - floor(x) }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Root Tabs
struct RootTabsView: View {
    @EnvironmentObject var store: RaceStore
    @State private var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            SeriesHubView().tabItem { Label("賽事", systemImage: "flag.checkered") }.tag(0)
            TelemetryView().tabItem { Label("遙測", systemImage: "waveform.path.ecg") }.tag(1)
            StatsView().tabItem { Label("統計", systemImage: "chart.bar.fill") }.tag(2)
            NewsView().tabItem { Label("新聞", systemImage: "newspaper.fill") }.tag(3)
            SettingsView().tabItem { Label("設定", systemImage: "gearshape.fill") }.tag(4)
        }
        .tint(store.theme.accent)
    }
}

// MARK: - TAB 1: Series Hub
struct SeriesHubView: View {
    @EnvironmentObject var store: RaceStore
    @State private var active: RaceSeries? = .f1
    @State private var path = NavigationPath()
    @State private var showAI = false
    @State private var toast: String?
    @State private var reveal = false

    var body: some View {
        let masked = store.spoilerFree && !reveal
        let nextEv = store.nextGlobal()
        NavigationStack(path: $path) {
            ZStack {
                RacingBG()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        HStack {
                            Button { store.haptic(); showAI = true; Task { await store.makeBriefing() } } label: {
                                Label("AI 速報", systemImage: "sparkles").font(.caption.bold()).foregroundStyle(.white)
                                    .padding(.horizontal, 11).padding(.vertical, 6).background(.ultraThinMaterial, in: Capsule())
                            }
                            Spacer()
                            Text("賽事").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                            Spacer()
                            Button { store.haptic(); withAnimation { store.spoilerFree.toggle(); reveal = false } } label: {
                                Label(store.spoilerFree ? "防劇透" : "即時", systemImage: store.spoilerFree ? "eye.slash.fill" : "eye.fill")
                                    .font(.caption.bold()).foregroundStyle(store.spoilerFree ? Color.yellow : Color.white)
                                    .padding(.horizontal, 11).padding(.vertical, 6).background(.ultraThinMaterial, in: Capsule())
                            }
                        }
                        .padding(.horizontal, 20).padding(.top, 10)

                        HStack(spacing: 7) {
                            Circle().fill(store.isLoading ? Color.yellow : Color.green).frame(width: 8, height: 8)
                            Text(store.isTranslating ? "AI 翻譯中..." : "即時數據已連線 · 澳門時間").font(.caption.bold()).foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 5).background(.ultraThinMaterial, in: Capsule()).padding(.top, 10)

                        ZStack {
                            StarRingView(animate: store.particles, tint: store.theme.accent).frame(width: 268, height: 240)
                            if let ev = nextEv {
                                let cd = RaceFmt.countdown(to: ev.raceDate)
                                VStack(spacing: 4) {
                                    Text(ev.series.rawValue).font(.system(size: 10, weight: .black)).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 2).background(ev.series.badgeColor, in: Capsule())
                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                        if cd.d > 0 { Text("\(cd.d)").font(.system(size: 36, weight: .bold, design: .rounded)); Text("日").font(.caption).foregroundStyle(.white.opacity(0.65)).padding(.trailing, 3) }
                                        Text("\(cd.h)").font(.system(size: 36, weight: .bold, design: .rounded)); Text("時").font(.caption).foregroundStyle(.white.opacity(0.65))
                                    }.foregroundStyle(.white).monospacedDigit()
                                    Text("· \(store.tr(ev.name)) ·").font(.caption.bold()).foregroundStyle(.white.opacity(0.78)).lineLimit(1).frame(maxWidth: 205)
                                    Text(RaceFmt.full.string(from: ev.raceDate)).font(.caption2).foregroundStyle(.white.opacity(0.5))
                                }
                            } else {
                                Text("APEXGRID").font(.title2.bold()).foregroundStyle(.white)
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(RaceSeries.allCases) { s in
                                    SeriesHeroCard(series: s, masked: masked)
                                        .containerRelativeFrame(.horizontal) { len, _ in min(len - 80, 310) }
                                        .id(s)
                                        .onTapGesture { store.haptic(); path.append(s) }
                                        .contextMenu {
                                            if let ev = store.nextEvent(s) {
                                                Button("預約開賽前 15 分鐘提醒") {
                                                    Task {
                                                        let ok = await store.remind(ev)
                                                        toast = ok ? "已預約 \(store.tr(ev.name)) 提醒！" : "無法排程（請檢查通知權限）"
                                                        try? await Task.sleep(nanoseconds: 2_200_000_000); toast = nil
                                                    }
                                                }
                                            }
                                        }
                                }
                            }.scrollTargetLayout()
                        }
                        .contentMargins(.horizontal, 40, for: .scrollContent)
                        .scrollTargetBehavior(.viewAligned)
                        .scrollPosition(id: $active)
                        .frame(height: 266)

                        HStack(spacing: 7) {
                            ForEach(RaceSeries.allCases) { s in
                                Circle().fill(Color.white.opacity((active ?? .f1) == s ? 0.92 : 0.25)).frame(width: 6, height: 6)
                            }
                        }.padding(.top, 12)

                        Text("輕點卡片進入積分與賽程 · 長按預約提醒 · 下拉刷新").font(.caption2).foregroundStyle(.white.opacity(0.48)).padding(.top, 6)

                        let breaking = Array(store.news.filter(\.isBreaking).prefix(3))
                        if !breaking.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label("重點突發快訊（AI 繁中）", systemImage: "bolt.fill").font(.subheadline.bold()).foregroundStyle(.white)
                                    Spacer()
                                    if masked { Button("解鎖") { reveal = true }.font(.caption.bold()).foregroundStyle(.yellow) }
                                }
                                ForEach(breaking) { item in
                                    GlassCard(radius: 16) {
                                        HStack(alignment: .top, spacing: 9) {
                                            Text(item.badge ?? "焦點").font(.system(size: 10, weight: .black)).foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 3).background(Color.red, in: Capsule())
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(store.tr(item.title)).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(.white).blur(radius: masked ? 6 : 0)
                                                Text("\(item.series.rawValue) · \(RaceFmt.relative(item.date))").font(.caption2).foregroundStyle(.white.opacity(0.5))
                                            }
                                            Spacer()
                                        }.padding(13)
                                    }
                                }
                            }.padding(.horizontal, 20).padding(.top, 18)
                        }
                    }.padding(.bottom, 30)
                }
                .refreshable { store.haptic(); await store.refreshAll() }

                if let msg = toast {
                    VStack { Spacer(); Text(msg).font(.caption.bold()).foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 9).background(.ultraThinMaterial, in: Capsule()).padding(.bottom, 22) }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: RaceSeries.self) { SeriesDetailView(series: $0) }
            .sheet(isPresented: $showAI) { BriefingSheet() }
        }
    }
}

struct SeriesHeroCard: View {
    @EnvironmentObject var store: RaceStore
    let series: RaceSeries
    let masked: Bool
    var body: some View {
        let list = store.drivers[series] ?? []
        let p1 = list.first, p2 = list.count > 1 ? list[1] : nil
        let gap = (p1?.points ?? 0) - (p2?.points ?? 0)
        GlassCard(radius: 28) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label(series.rawValue, systemImage: series.symbol).font(.caption.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5).background(series.badgeColor, in: Capsule())
                    Spacer()
                    if p2 != nil {
                        Text("領先 +\(Int(gap)) 分").font(.caption2.bold()).foregroundStyle(.green)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(Color.green.opacity(0.16), in: Capsule()).blur(radius: masked ? 5 : 0)
                    }
                }
                Spacer(minLength: 8)
                HStack(spacing: 14) {
                    Image(systemName: series.symbol).font(.system(size: 32, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 68, height: 68).background(RadialGradient(colors: [series.badgeColor.opacity(0.4), Color.clear], center: .center, startRadius: 4, endRadius: 38))
                    VStack(alignment: .leading, spacing: 4) {
                        Label("領先 P1", systemImage: "crown.fill").font(.caption2.bold()).foregroundStyle(.yellow)
                        Text(p1?.name ?? "載入中...").font(.system(size: 18, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                        Text(p1?.team ?? series.fullTitle).font(.caption).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                    }.blur(radius: masked ? 7 : 0)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(p1?.points ?? 0))").font(.system(size: 36, weight: .black, design: .rounded)).foregroundStyle(.white)
                    Text("PTS").font(.caption.bold()).foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    if let w = p1?.wins, w > 0 { Text("\(w) 勝").font(.caption.bold()).foregroundStyle(.yellow) }
                }.blur(radius: masked ? 7 : 0)
                if let ev = store.nextEvent(series) {
                    Text("下站：\(store.tr(ev.name)) · \(RaceFmt.md.string(from: ev.raceDate))").font(.caption2).foregroundStyle(.white.opacity(0.55)).lineLimit(1).padding(.top, 2)
                }
            }.padding(20)
        }
    }
}

struct SeriesDetailView: View {
    @EnvironmentObject var store: RaceStore
    @Environment(\.dismiss) var dismiss
    let series: RaceSeries
    @State private var tab = 0
    var body: some View {
        let dList = store.drivers[series] ?? [], tList = store.teams[series] ?? [], evs = store.schedules[series] ?? []
        ZStack {
            RacingBG()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Button { dismiss() } label: { Image(systemName: "chevron.left").font(.headline).foregroundStyle(.white).frame(width: 38, height: 38).background(.ultraThinMaterial, in: Circle()) }
                        Spacer()
                        Text(series.rawValue).font(.caption.bold()).foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 5).background(series.badgeColor, in: Capsule())
                    }
                    Text(series.fullTitle).font(.title.bold()).foregroundStyle(.white)
                    Picker("", selection: $tab) { Text("車手榜").tag(0); Text("車隊榜").tag(1); Text("最新站").tag(2); Text("賽程").tag(3) }.pickerStyle(.segmented)
                    if tab == 0 {
                        ForEach(dList) { d in
                            GlassCard(radius: 16) {
                                HStack(spacing: 12) {
                                    Text("\(d.position)").font(.headline.bold()).foregroundStyle(d.position <= 3 ? Color.yellow : Color.white.opacity(0.6)).frame(width: 24)
                                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: d.colorHex)).frame(width: 4, height: 30)
                                    VStack(alignment: .leading) { Text(d.name).font(.subheadline.bold()).foregroundStyle(.white); Text(d.team).font(.caption2).foregroundStyle(.white.opacity(0.55)) }
                                    Spacer()
                                    Text("\(Int(d.points)) PTS").font(.subheadline.bold()).foregroundStyle(.white)
                                }.padding(13)
                            }
                        }
                    } else if tab == 1 {
                        ForEach(tList) { t in
                            GlassCard(radius: 16) {
                                HStack(spacing: 12) {
                                    Text("\(t.position)").font(.headline.bold()).foregroundStyle(t.position <= 3 ? Color.yellow : Color.white.opacity(0.6)).frame(width: 24)
                                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: t.colorHex)).frame(width: 4, height: 26)
                                    Text(t.name).font(.subheadline.bold()).foregroundStyle(.white); Spacer()
                                    Text("\(Int(t.points)) PTS").font(.subheadline.bold()).foregroundStyle(.white)
                                }.padding(13)
                            }
                        }
                    } else if tab == 2 {
                        if let res = store.latestF1, series == .f1 {
                            Text(store.tr(res.raceName)).font(.headline).foregroundStyle(.white)
                            ForEach(res.results) { row in
                                GlassCard(radius: 14) {
                                    HStack {
                                        Text("P\(row.position)").font(.caption.bold()).foregroundStyle(row.position <= 3 ? Color.yellow : Color.white.opacity(0.7)).frame(width: 30, alignment: .leading)
                                        VStack(alignment: .leading) { Text(row.driverName).font(.subheadline.bold()).foregroundStyle(.white); Text(row.teamName).font(.caption2).foregroundStyle(.white.opacity(0.55)) }
                                        Spacer()
                                        Text(store.tr(row.status)).font(.caption.monospaced()).foregroundStyle(.white.opacity(0.8))
                                    }.padding(12)
                                }
                            }
                        } else {
                            GlassCard(radius: 16) { Text("最新一站詳細正賽成績暫支援 F1 即時拉取。").font(.subheadline).foregroundStyle(.white.opacity(0.6)).padding(16) }
                        }
                    } else {
                        ForEach(evs) { ev in
                            GlassCard(radius: 16) {
                                HStack {
                                    Text("R\(ev.round)").font(.caption.bold()).foregroundStyle(ev.raceDate < Date() ? Color.gray : series.badgeColor).frame(width: 30)
                                    VStack(alignment: .leading) { Text(store.tr(ev.name)).font(.subheadline.bold()).foregroundStyle(.white); Text("\(ev.circuit) · \(RaceFmt.full.string(from: ev.raceDate))").font(.caption2).foregroundStyle(.white.opacity(0.55)) }
                                    Spacer()
                                }.padding(13)
                            }
                        }
                    }
                }.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 30)
            }
        }.toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - TAB 2: F1 Telemetry Lab
struct TelemetryView: View {
    @EnvironmentObject var store: RaceStore
    @EnvironmentObject var radio: RadioPlayer
    @State private var tab = 0
    var body: some View {
        let prog = store.f1Progress(), ratio = Double(prog.0) / Double(max(1, prog.1))
        NavigationStack {
            ZStack {
                RacingBG()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("遙測實驗室").font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
                        Text(store.openF1Name.isEmpty ? "OpenF1 同步中..." : store.openF1Name).font(.caption.bold()).foregroundStyle(store.theme.accent)

                        GlassCard(radius: 24) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 10)
                                    Circle().trim(from: 0, to: ratio).stroke(store.theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
                                    Text("\(Int(ratio * 100))%").font(.headline.bold()).foregroundStyle(.white)
                                }.frame(width: 82, height: 82)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("F1 完成 \(prog.0) / \(prog.1) 站").font(.subheadline.bold()).foregroundStyle(.white)
                                    if let w = store.weather {
                                        Text("賽道 \(Int(w.trackTemp))°C · 氣溫 \(Int(w.airTemp))°C · \(w.isRaining ? "有雨" : "乾地")").font(.caption).foregroundStyle(.white.opacity(0.8))
                                    }
                                    Text("最快單圈：\(store.fastestLap)").font(.caption2).foregroundStyle(.white.opacity(0.55))
                                }
                                Spacer()
                            }.padding(16)
                        }

                        Picker("", selection: $tab) { Text("換胎").tag(0); Text("尾速/進站").tag(1); Text("Radio").tag(2); Text("判罰翻譯").tag(3) }.pickerStyle(.segmented)

                        if tab == 0 {
                            let maxLap = max(1, store.strategies.map(\.totalLaps).max() ?? 50)
                            GlassCard(radius: 20) {
                                VStack(spacing: 10) {
                                    ForEach(store.strategies) { drv in
                                        HStack(spacing: 8) {
                                            Text(drv.acronym).font(.caption.bold().monospaced()).foregroundStyle(.white).frame(width: 38, alignment: .leading)
                                            GeometryReader { g in
                                                HStack(spacing: 2) {
                                                    ForEach(drv.stints) { st in
                                                        ZStack {
                                                            RoundedRectangle(cornerRadius: 4).fill(st.color)
                                                            Text("\(st.letter)\(st.laps)").font(.system(size: 9, weight: .black)).foregroundStyle(st.compound.uppercased() == "HARD" || st.compound.uppercased() == "MEDIUM" ? Color.black : Color.white)
                                                        }.frame(width: max(16, CGFloat(st.laps) / CGFloat(maxLap) * g.size.width - 2), height: 19)
                                                    }
                                                }
                                            }.frame(height: 19)
                                        }
                                    }
                                }.padding(15)
                            }
                        } else if tab == 1 {
                            GlassCard(radius: 20) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("尾速排行榜 (km/h)", systemImage: "gauge.with.needle.fill").font(.subheadline.bold()).foregroundStyle(.white)
                                    ForEach(Array(store.speeds.prefix(8).enumerated()), id: \.offset) { idx, r in
                                        HStack {
                                            Text("\(idx + 1)").font(.caption.bold()).foregroundStyle(idx == 0 ? Color.yellow : Color.gray).frame(width: 18)
                                            Text(r.acronym).font(.caption.bold().monospaced()).foregroundStyle(.white)
                                            Spacer()
                                            Text("\(r.kmh) km/h").font(.caption.bold().monospaced()).foregroundStyle(.white)
                                        }
                                    }
                                }.padding(16)
                            }
                            GlassCard(radius: 20) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("最快進站 (秒)", systemImage: "wrench.and.screwdriver.fill").font(.subheadline.bold()).foregroundStyle(.white)
                                    ForEach(Array(store.pits.enumerated()), id: \.offset) { idx, p in
                                        HStack {
                                            Text("P\(idx + 1)").font(.caption.bold()).foregroundStyle(idx == 0 ? Color.yellow : Color.gray).frame(width: 24)
                                            Text("\(p.acronym) (L\(p.lap))").font(.caption.bold().monospaced()).foregroundStyle(.white)
                                            Spacer()
                                            Text(String(format: "%.2f s", p.sec)).font(.caption.bold().monospaced()).foregroundStyle(idx == 0 ? Color.green : Color.white)
                                        }
                                    }
                                }.padding(16)
                            }
                        } else if tab == 2 {
                            ForEach(store.radios) { clip in
                                let playing = radio.currentURL == clip.url && radio.isPlaying
                                GlassCard(radius: 16) {
                                    HStack(spacing: 12) {
                                        Button { store.haptic(); radio.toggle(clip.url) } label: {
                                            Image(systemName: playing ? "stop.fill" : "play.fill").foregroundStyle(.white).frame(width: 38, height: 38).background(Color(hex: clip.colorHex), in: Circle())
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(clip.acronym) · \(clip.fullName)").font(.subheadline.bold()).foregroundStyle(.white).lineLimit(1)
                                            Text("澳門 \(RaceFmt.full.string(from: clip.date))").font(.caption2).foregroundStyle(.white.opacity(0.55))
                                        }
                                        Spacer()
                                    }.padding(13)
                                }
                            }
                        } else {
                            ForEach(store.controls) { msg in
                                GlassCard(radius: 16) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack {
                                            Text(msg.flag).font(.caption2.bold()).foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 2).background(msg.isCritical ? Color.red : Color.white.opacity(0.16), in: Capsule())
                                            if let lap = msg.lap { Text("L\(lap)").font(.caption2.monospaced()).foregroundStyle(.white.opacity(0.6)) }
                                            Spacer()
                                            Text(RaceFmt.hm.string(from: msg.date)).font(.caption2.monospaced()).foregroundStyle(.white.opacity(0.45))
                                        }
                                        Text(store.tr(msg.message)).font(.subheadline.bold()).foregroundStyle(.white)
                                        if store.showEnglish && store.hasTr(msg.message) { Text(msg.message).font(.caption2.monospaced()).foregroundStyle(.white.opacity(0.45)) }
                                    }.padding(13)
                                }
                            }
                        }
                    }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 30)
                }.refreshable { store.haptic(); await store.fetchOpenF1(); await store.translateAll() }
            }.toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - TAB 3: Stats, Heatmap, H2H & HD Poster
struct StatsView: View {
    @EnvironmentObject var store: RaceStore
    @State private var series: RaceSeries = .f1
    @State private var idxA = 0
    @State private var idxB = 1
    @State private var showPoster = false

    var body: some View {
        let list = store.drivers[series] ?? []
        let f1Top = store.drivers[.f1]?.first
        let topWin = list.max { $0.wins < $1.wins }
        NavigationStack {
            ZStack {
                RacingBG()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("統計").font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
                            Spacer()
                            Button { store.haptic(); showPoster = true } label: {
                                Image(systemName: "square.and.arrow.up").foregroundStyle(.white).frame(width: 38, height: 38).background(.ultraThinMaterial, in: Circle())
                            }
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            statTile("F1 積分王", "\(Int(f1Top?.points ?? 0)) PTS", f1Top?.name ?? "-")
                            statTile("最多冠軍", "\(topWin?.wins ?? 0) 勝", topWin?.name ?? "-")
                            statTile("極速王", store.speeds.first.map { "\($0.kmh) km/h" } ?? "--", store.speeds.first?.acronym ?? "OpenF1")
                            statTile("最快進站", store.pits.first.map { String(format: "%.2fs", $0.sec) } ?? "--", store.pits.first?.acronym ?? "OpenF1")
                        }
                        HeatmapCard()
                        HStack(spacing: 8) {
                            ForEach(RaceSeries.allCases) { s in
                                Button { store.haptic(); series = s; idxA = 0; idxB = min(1, max(0, (store.drivers[s]?.count ?? 1) - 1)) } label: {
                                    Text(s.rawValue).font(.caption.bold()).foregroundStyle(series == s ? Color.white : Color.white.opacity(0.55))
                                        .frame(maxWidth: .infinity).padding(.vertical, 8).background(series == s ? s.badgeColor : Color.white.opacity(0.08), in: Capsule())
                                }.buttonStyle(.plain)
                            }
                        }
                        if list.count >= 2 {
                            H2HCard(list: list, idxA: $idxA, idxB: $idxB, a: list[min(idxA, list.count - 1)], b: list[min(idxB, list.count - 1)])
                        }
                    }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 30)
                }
                .refreshable { store.haptic(); await store.refreshAll() }
                .sheet(isPresented: $showPoster) { PosterSheet() }
            }.toolbar(.hidden, for: .navigationBar)
        }
    }
    private func statTile(_ t: String, _ v: String, _ sub: String) -> some View {
        GlassCard(radius: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(t).font(.caption).foregroundStyle(.white.opacity(0.6))
                Text(v).font(.title2.bold()).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.75)
                Text(sub).font(.caption2).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(15)
        }
    }
}

struct HeatmapCard: View {
    @EnvironmentObject var store: RaceStore
    @State private var picked: RaceEvent?
    private func eventOn(_ d: Date) -> RaceEvent? {
        let all = (store.schedules[.f1] ?? []) + (store.schedules[.motogp] ?? []) + (store.schedules[.tcr] ?? [])
        return all.first { Calendar.current.isDate($0.raceDate, inSameDayAs: d) }
    }
    var body: some View {
        let cal = Calendar.current, start = cal.date(byAdding: .day, value: -77, to: cal.startOfDay(for: Date())) ?? Date()
        let cols: [[Date]] = (0..<16).map { w in (0..<7).compactMap { d in cal.date(byAdding: .day, value: w * 7 + d, to: start) } }
        GlassCard(radius: 22) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("16 週賽事熱力圖", systemImage: "square.grid.3x3.fill").font(.subheadline.bold()).foregroundStyle(.white)
                    Spacer()
                    if let ev = picked { Text("\(ev.series.rawValue) \(RaceFmt.md.string(from: ev.raceDate))").font(.caption2.bold()).foregroundStyle(ev.series.badgeColor) }
                }
                HStack(spacing: 4) {
                    ForEach(0..<cols.count, id: \.self) { c in
                        VStack(spacing: 4) {
                            ForEach(0..<cols[c].count, id: \.self) { r in
                                let dt = cols[c][r], ev = eventOn(dt)
                                RoundedRectangle(cornerRadius: 3).fill(ev?.series.badgeColor ?? Color.white.opacity(cal.isDateInToday(dt) ? 0.35 : 0.08))
                                    .aspectRatio(1, contentMode: .fit)
                                    .onTapGesture { if let ev { store.haptic(); picked = ev } }
                            }
                        }
                    }
                }
                if let ev = picked { Text("🏁 \(store.tr(ev.name))").font(.caption.bold()).foregroundStyle(.white.opacity(0.85)) }
            }.padding(16)
        }
    }
}

struct H2HCard: View {
    let list: [DriverStanding]
    @Binding var idxA: Int
    @Binding var idxB: Int
    let a: DriverStanding
    let b: DriverStanding
    var body: some View {
        let tot = max(1.0, a.points + b.points), rA = a.points / tot, diff = abs(a.points - b.points)
        GlassCard(radius: 22) {
            VStack(spacing: 14) {
                HStack {
                    Picker("", selection: $idxA) { ForEach(0..<list.count, id: \.self) { Text("P\(list[$0].position) \(list[$0].shortCode)").tag($0) } }.tint(Color(hex: a.colorHex))
                    Text("VS").font(.caption.bold()).foregroundStyle(.white.opacity(0.5))
                    Picker("", selection: $idxB) { ForEach(0..<list.count, id: \.self) { Text("P\(list[$0].position) \(list[$0].shortCode)").tag($0) } }.tint(Color(hex: b.colorHex))
                }
                HStack {
                    Text("\(a.shortCode) \(Int(a.points))").font(.title3.bold()).foregroundStyle(Color(hex: a.colorHex))
                    Spacer()
                    Text("\(Int(b.points)) \(b.shortCode)").font(.title3.bold()).foregroundStyle(Color(hex: b.colorHex))
                }
                GeometryReader { g in
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 5).fill(Color(hex: a.colorHex)).frame(width: max(12, g.size.width * rA - 2))
                        RoundedRectangle(cornerRadius: 5).fill(Color(hex: b.colorHex)).frame(width: max(12, g.size.width * (1 - rA) - 2))
                    }
                }.frame(height: 11)
                Text(diff == 0 ? "目前同分！" : "分差 \(Int(diff)) 分（最少需 \(Int(ceil(diff / 25.0))) 站全勝先可反超）").font(.caption).foregroundStyle(.white.opacity(0.75))
            }.padding(16)
        }
    }
}

struct PosterSheet: View {
    @EnvironmentObject var store: RaceStore
    @Environment(\.dismiss) var dismiss
    @State private var img: UIImage?
    @State private var share = false
    var body: some View {
        let f1 = store.drivers[.f1]?.first, mgp = store.drivers[.motogp]?.first, tcr = store.drivers[.tcr]?.first
        let card = VStack(alignment: .leading, spacing: 14) {
            HStack { Text("APEXGRID").font(.caption.bold()).tracking(2).foregroundStyle(store.theme.accent); Spacer(); Text(RaceFmt.ymd.string(from: Date())).font(.caption2).foregroundStyle(.white.opacity(0.5)) }
            Text("多賽事積分戰報").font(.title2.bold()).foregroundStyle(.white)
            row("F1", RaceSeries.f1.badgeColor, f1); row("MotoGP", RaceSeries.motogp.badgeColor, mgp); row("TCR", RaceSeries.tcr.badgeColor, tcr)
        }.padding(22).background(LinearGradient(colors: store.theme.bgColors, startPoint: .topLeading, endPoint: .bottomTrailing))

        NavigationStack {
            ZStack {
                RacingBG()
                VStack(spacing: 20) {
                    card.clipShape(RoundedRectangle(cornerRadius: 24)).padding(.horizontal, 20)
                    Button {
                        let r = ImageRenderer(content: card.frame(width: 340)); r.scale = 3.0
                        if let ui = r.uiImage { img = ui; share = true }
                    } label: {
                        Label("儲存／分享高清海報", systemImage: "square.and.arrow.up").font(.headline).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.white, in: Capsule())
                    }.padding(.horizontal, 28)
                }
            }
            .navigationTitle("賽車海報").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("關閉") { dismiss() } } }
            .sheet(isPresented: $share) { if let img { ShareSheet(items: [img]) } }
        }
    }
    private func row(_ tag: String, _ col: Color, _ d: DriverStanding?) -> some View {
        HStack {
            Text(tag).font(.caption2.bold()).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 3).background(col, in: Capsule())
            Text(d?.name ?? "--").font(.subheadline.bold()).foregroundStyle(.white); Spacer()
            Text("\(Int(d?.points ?? 0)) PTS").font(.subheadline.bold()).foregroundStyle(.white)
        }.padding(11).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct BriefingSheet: View {
    @EnvironmentObject var store: RaceStore
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                RacingBG()
                ScrollView {
                    GlassCard(radius: 22) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Label("AI 廣東話賽況速報", systemImage: "sparkles").font(.headline).foregroundStyle(store.theme.accent); Spacer(); if store.isBriefing { ProgressView().tint(.white) } }
                            Text(store.briefing.isEmpty ? "正在分析最新數據..." : store.briefing).font(.body).lineSpacing(5).foregroundStyle(.white)
                        }.padding(18)
                    }.padding(20)
                }
            }
            .navigationTitle("AI 賽車助手").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("關閉") { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
}

// MARK: - TAB 4: AI Translated News
struct NewsView: View {
    @EnvironmentObject var store: RaceStore
    @State private var filter: RaceSeries?
    @State private var activeURL: IdentifiableURL?
    @State private var showAI = false
    var body: some View {
        let list = store.news.filter { (filter == nil || $0.series == filter) && (!store.onlyBreaking || $0.isBreaking) }
        NavigationStack {
            ZStack {
                RacingBG()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            Text("重點新聞").font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
                            Spacer()
                            Button { store.haptic(); showAI = true; Task { await store.makeBriefing() } } label: {
                                Label("AI 總結", systemImage: "sparkles").font(.caption.bold()).foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 6).background(.ultraThinMaterial, in: Capsule())
                            }
                            Button { store.haptic(); store.onlyBreaking.toggle() } label: {
                                Image(systemName: store.onlyBreaking ? "flame.fill" : "flame").foregroundStyle(.white).frame(width: 34, height: 34).background(store.onlyBreaking ? Color.red : Color.white.opacity(0.1), in: Circle())
                            }
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                chip("全部", filter == nil, store.theme.accent) { filter = nil }
                                ForEach(RaceSeries.allCases) { s in chip(s.rawValue, filter == s, s.badgeColor) { filter = s } }
                            }
                        }
                        ForEach(list) { item in
                            Button { store.haptic(); if let u = URL(string: item.link) { activeURL = IdentifiableURL(url: u) } } label: {
                                GlassCard(radius: 18) {
                                    VStack(alignment: .leading, spacing: 7) {
                                        HStack(spacing: 6) {
                                            Text(item.series.rawValue).font(.system(size: 10, weight: .black)).foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 2).background(item.series.badgeColor, in: Capsule())
                                            if let b = item.badge { Text(b).font(.system(size: 10, weight: .black)).foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 2).background(Color.red, in: Capsule()) }
                                            Spacer()
                                            Text(RaceFmt.relative(item.date)).font(.caption2).foregroundStyle(.white.opacity(0.5))
                                        }
                                        Text(store.tr(item.title)).font(.subheadline.bold()).foregroundStyle(.white).multilineTextAlignment(.leading).blur(radius: store.spoilerFree ? 6 : 0)
                                        if store.showEnglish && store.autoTranslate && store.hasTr(item.title) {
                                            Text(item.title).font(.caption2).foregroundStyle(.white.opacity(0.45)).multilineTextAlignment(.leading)
                                        }
                                    }.padding(14)
                                }
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 30)
                }
                .refreshable { store.haptic(); await store.refreshAll() }
                .sheet(item: $activeURL) { SafariView(url: $0.url).ignoresSafeArea() }
                .sheet(isPresented: $showAI) { BriefingSheet() }
            }.toolbar(.hidden, for: .navigationBar)
        }
    }
    private func chip(_ t: String, _ on: Bool, _ c: Color, _ act: @escaping () -> Void) -> some View {
        Button { store.haptic(); act() } label: { Text(t).font(.caption.bold()).foregroundStyle(on ? Color.white : Color.white.opacity(0.65)).padding(.horizontal, 13).padding(.vertical, 6).background(on ? c : Color.white.opacity(0.1), in: Capsule()) }.buttonStyle(.plain)
    }
}

// MARK: - TAB 5: Settings
struct SettingsView: View {
    @EnvironmentObject var store: RaceStore
    @ObservedObject private var wall = WallpaperRepo.shared
    @State private var pickedWall: PhotosPickerItem?
    var body: some View {
        NavigationStack {
            ZStack {
                RacingBG()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("設定").font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
                        GlassCard(radius: 22) {
                            VStack(spacing: 13) {
                                Toggle("AI 自動英翻中（免 Key 即用）", isOn: $store.autoTranslate).tint(store.theme.accent)
                                Divider().overlay(Color.white.opacity(0.1))
                                Toggle("保留英文原文對照", isOn: $store.showEnglish).tint(store.theme.accent)
                                Divider().overlay(Color.white.opacity(0.1))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Gemini API Key（可選，解鎖專業粵語賽評）").font(.caption).foregroundStyle(.white.opacity(0.6))
                                    SecureField("貼上 AIza... Key", text: $store.geminiKey).textFieldStyle(.plain).padding(9).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                }
                            }.padding(16)
                        }
                        GlassCard(radius: 22) {
                            VStack(spacing: 13) {
                                HStack {
                                    Text("車隊主題色"); Spacer()
                                    Picker("", selection: $store.theme) { ForEach(TeamTheme.allCases) { Text($0.title).tag($0) } }.tint(store.theme.accent)
                                }
                                Divider().overlay(Color.white.opacity(0.1))
                                PhotosPicker(selection: $pickedWall, matching: .images) {
                                    HStack { Label("從相簿揀賽車相做背景", systemImage: "photo.fill.on.rectangle.fill").foregroundStyle(store.theme.accent); Spacer(); if wall.image != nil { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) } }
                                }
                                if wall.image != nil {
                                    Slider(value: $store.wallBlur, in: 0...28, step: 1).tint(store.theme.accent)
                                    Slider(value: $store.wallDim, in: 0.1...0.85, step: 0.05).tint(store.theme.accent)
                                    Button("移除自定義背景", role: .destructive) { wall.remove() }.font(.caption.bold()).frame(maxWidth: .infinity, alignment: .leading)
                                }
                                Divider().overlay(Color.white.opacity(0.1))
                                Toggle("防劇透模式", isOn: $store.spoilerFree).tint(store.theme.accent)
                                Divider().overlay(Color.white.opacity(0.1))
                                Toggle("星空粒子動畫", isOn: $store.particles).tint(store.theme.accent)
                            }.padding(16)
                        }
                        GlassCard(radius: 22) {
                            Button { store.haptic(); Task { await store.refreshAll() } } label: {
                                HStack { Label("立即同步所有數據與小工具", systemImage: "arrow.triangle.2.circlepath").foregroundStyle(store.theme.accent); Spacer() }
                            }.padding(16)
                        }
                    }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: pickedWall) { _, it in Task { if let d = try? await it?.loadTransferable(type: Data.self), let img = UIImage(data: d) { wall.save(img) } } }
        }
    }
}
