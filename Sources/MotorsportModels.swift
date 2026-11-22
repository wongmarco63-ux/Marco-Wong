import Foundation
import SwiftUI
import AVFoundation
import UserNotifications
import WidgetKit
import UIKit

// MARK: - Core Enums
enum RaceSeries: String, CaseIterable, Identifiable, Codable {
    case f1 = "F1"
    case motogp = "MotoGP"
    case tcr = "TCR"

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

enum TranslationEngineMode: String, CaseIterable, Identifiable {
    case autoFree = "autoFree"
    case appleOnDevice = "appleOnDevice"
    case geminiPro = "geminiPro"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .autoFree: return "免費即時翻譯（免 Key 即用）"
        case .appleOnDevice: return "Apple 原生離線翻譯（iOS 18+）"
        case .geminiPro: return "Gemini AI 賽評翻譯（需填 Key）"
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

// MARK: - OpenF1 Telemetry Models
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

struct F1WeatherSnapshot {
    let airTemp: Double
    let trackTemp: Double
    let humidity: Double
    let windSpeed: Double
    let isRaining: Bool
}

struct F1SpeedTrapRow: Identifiable {
    let id: Int
    let acronym: String
    let fullName: String
    let teamColorHex: String
    let maxSpeedKmh: Int
}

struct F1PitStopRow: Identifiable {
    let id = UUID()
    let acronym: String
    let teamColorHex: String
    let lapNumber: Int
    let durationSec: Double
}

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

// MARK: - Custom Wallpaper Repository (PodsStats Style)
@MainActor
final class WallpaperRepository: ObservableObject {
    static let shared = WallpaperRepository()
    @Published var customWallpaper: UIImage?

    private var wallpaperURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("apexgrid_custom_wallpaper.jpg")
    }

    init() {
        if let data = try? Data(contentsOf: wallpaperURL), let img = UIImage(data: data) {
            customWallpaper = img
        }
    }

    func save(_ image: UIImage) {
        let size = image.size
        let longest = max(size.width, size.height)
        let finalImg: UIImage
        if longest > 1600 {
            let scale = 1600 / longest
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            finalImg = UIGraphicsImageRenderer(size: newSize).image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            finalImg = image
        }
        if let data = finalImg.jpegData(compressionQuality: 0.86) {
            try? data.write(to: wallpaperURL, options: .atomic)
        }
        customWallpaper = finalImg
    }

    func remove() {
        try? FileManager.default.removeItem(at: wallpaperURL)
        customWallpaper = nil
    }
}

// MARK: - AI Auto-Translation & Motorsport Glossary Engine
enum MotorsportTranslator {
    // 常見賽車名詞即時本地映射（免等待、零誤差）
    static let quickGlossary: [String: String] = [
        "Australian Grand Prix": "澳洲大獎賽",
        "Chinese Grand Prix": "中國大獎賽",
        "Japanese Grand Prix": "日本大獎賽",
        "Bahrain Grand Prix": "巴林大獎賽",
        "Saudi Arabian Grand Prix": "沙特阿拉伯大獎賽",
        "Miami Grand Prix": "邁阿密大獎賽",
        "Emilia Romagna Grand Prix": "艾米利亞-羅馬涅大獎賽",
        "Monaco Grand Prix": "摩納哥大獎賽",
        "Spanish Grand Prix": "西班牙大獎賽",
        "Canadian Grand Prix": "加拿大大獎賽",
        "Austrian Grand Prix": "奧地利大獎賽",
        "British Grand Prix": "英國大獎賽",
        "Belgian Grand Prix": "比利時大獎賽",
        "Hungarian Grand Prix": "匈牙利大獎賽",
        "Dutch Grand Prix": "荷蘭大獎賽",
        "Italian Grand Prix": "意大利大獎賽",
        "Azerbaijan Grand Prix": "阿塞拜疆大獎賽",
        "Singapore Grand Prix": "新加坡大獎賽",
        "United States Grand Prix": "美國大獎賽",
        "Mexico City Grand Prix": "墨西哥城大獎賽",
        "São Paulo Grand Prix": "聖保羅大獎賽",
        "Las Vegas Grand Prix": "拉斯維加斯大獎賽",
        "Qatar Grand Prix": "卡塔爾大獎賽",
        "Abu Dhabi Grand Prix": "阿布扎比大獎賽",
        "Madrid Grand Prix": "馬德里大獎賽",
        "Finished": "完賽",
        "+1 Lap": "+1 圈",
        "+2 Laps": "+2 圈",
        "Retired": "退賽",
        "Collision": "碰撞退賽",
        "Disqualified": "取消資格 (DSQ)"
    ]

    static func quickLookup(_ text: String) -> String? {
        if let exact = quickGlossary[text] { return exact }
        return nil
    }

    // 1. 免費即時翻譯（Google Translate Public Endpoint + 賽車專有名詞修正）
    static func translateFreeCloud(_ text: String) async -> String? {
        if let exact = quickLookup(text) { return exact }
        guard var comps = URLComponents(string: "https://translate.googleapis.com/translate_a/single") else { return nil }
        comps.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "en"),
            URLQueryItem(name: "tl", value: "zh-TW"),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]
        guard let url = comps.url else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let root = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let sentences = root.first as? [Any] else { return nil }

        var combined = ""
        for item in sentences {
            if let arr = item as? [Any], let chunk = arr.first as? String {
                combined += chunk
            }
        }
        let cleaned = polishMotorsportChinese(combined.trimmingCharacters(in: .whitespacesAndNewlines))
        return cleaned.isEmpty ? nil : cleaned
    }

    // 2. Gemini AI 批量專業賽車翻譯（香港／澳門繁體賽車術語）
    static func translateBatchGemini(_ texts: [String], apiKey: String) async -> [String: String] {
        guard !texts.isEmpty, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [:] }
        let numbered = texts.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let prompt = """
        你係港澳專業賽車（F1、MotoGP、TCR）編輯。請將以下英文賽車標題或賽會通報翻譯成自然流暢嘅繁體中文（使用港澳賽車術語：如杆位、進站、安全車、虛擬安全車、罰秒、退賽、紅旗、法拉利、平治、麥拿倫、紅牛）。
        嚴格按照原本編號每行一條輸出，不要加任何開場白或解釋：
        \(numbered)
        """
        guard let output = await callGemini(prompt: prompt, apiKey: apiKey) else { return [:] }
        var result: [String: String] = [:]
        let lines = output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for line in lines {
            if let dotIdx = line.firstIndex(of: "."), let num = Int(line[..<dotIdx].trimmingCharacters(in: .whitespaces)),
               num >= 1, num <= texts.count {
                let translated = String(line[line.index(after: dotIdx)...]).trimmingCharacters(in: .whitespaces)
                if !translated.isEmpty {
                    result[texts[num - 1]] = translated
                }
            }
        }
        return result
    }

    // 3. Gemini AI 廣東話賽況重點懶人包
    static func generateGeminiBriefing(contextText: String, apiKey: String) async -> String? {
        let prompt = """
        你係一位專業又貼地嘅港澳賽車評述員。請根據以下最新嘅 F1、MotoGP、TCR 實時數據與突發新聞，用自然流暢嘅廣東話（書面粵語）寫一份約 200 字嘅「賽車焦點懶人包」，分 3 至 4 個短重點，指出依家邊個領先緊、最新一站數據亮點（如尾速／換胎／天氣）同最值得留意嘅突發新聞：

        \(contextText)
        """
        return await callGemini(prompt: prompt, apiKey: apiKey)
    }

    private static func callGemini(prompt: String, apiKey: String) async -> String? {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(cleanKey)") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func polishMotorsportChinese(_ s: String) -> String {
        s.replacingOccurrences(of: "安全汽車", with: "安全車")
            .replacingOccurrences(of: "維修站", with: "維修區進站")
            .replacingOccurrences(of: "桿位", with: "杆位")
            .replacingOccurrences(of: "梅賽德斯", with: "平治")
            .replacingOccurrences(of: "邁凱倫", with: "麥拿倫")
            .replacingOccurrences(of: "維斯塔潘", with: "韋斯達賓")
            .replacingOccurrences(of: "漢密爾頓", with: "咸美頓")
            .replacingOccurrences(of: "勒克萊爾", with: "陸克萊")
            .replacingOccurrences(of: "大獎賽大獎賽", with: "大獎賽")
    }
}

// MARK: - Color Hex & Date Formatters
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
        let f = DateFormatter(); f.timeZone = macauTZ; f.dateFormat = "M月d日 HH:mm"; return f
    }()
    static let md: DateFormatter = {
        let f = DateFormatter(); f.timeZone = macauTZ; f.dateFormat = "M.d"; return f
    }()
    static let hmMacau: DateFormatter = {
        let f = DateFormatter(); f.timeZone = macauTZ; f.dateFormat = "HH:mm"; return f
    }()
    static let ymd: DateFormatter = {
        let f = DateFormatter(); f.timeZone = macauTZ; f.dateFormat = "yyyy.MM.dd"; return f
    }()

    static func parseISO(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFrac.date(from: raw) { return d }
        if let d = ISO8601DateFormatter().date(from: raw) { return d }
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

// MARK: - RSS Parser
final class MotorsportRSSParser: NSObject, XMLParserDelegate {
    private var articles: [NewsArticle] = []
    private var currentElement = "", currentTitle = "", currentLink = "", currentDateStr = ""
    private var inItem = false
    private let series: RaceSeries, sourceName: String

    init(series: RaceSeries, sourceName: String) {
        self.series = series; self.sourceName = sourceName
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
            inItem = true; currentTitle = ""; currentLink = ""; currentDateStr = ""
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
            articles.append(NewsArticle(id: cleanLink, series: series, title: cleanTitle, link: cleanLink, pubDate: date, source: sourceName, alertTag: badge, isBreaking: breaking))
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
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz", "yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy-MM-dd'T'HH:mm:ssZ"] {
            f.dateFormat = fmt
            if let d = f.date(from: str) { return d }
        }
        return nil
    }

    private func classifyTitle(_ title: String) -> (String?, Bool) {
        let l = title.lowercased()
        if l.contains("penalty") || l.contains("penalis") || l.contains("disqualif") || l.contains("dsq") || l.contains("grid drop") || l.contains("overpower") || l.contains("steward") { return ("判罰", true) }
        if l.contains("red flag") || l.contains("crash") || l.contains("collision") || l.contains("injury") || l.contains("withdraw") { return ("紅旗 / 意外", true) }
        if l.contains("macau") || l.contains("guia") { return ("澳門站", true) }
        if l.contains("signs") || l.contains("contract") || l.contains("joins") || l.contains("official") || l.contains("confirmed") || l.contains("champion") || l.contains("title") { return ("重磅焦點", true) }
        return (nil, false)
    }
}

// MARK: - Team Radio Player
@MainActor
final class RadioAudioPlayer: ObservableObject {
    @Published var currentURL: String?
    @Published var isPlaying = false
    private var player: AVPlayer?
    private var endObserver: Any?

    func toggle(urlString: String) {
        if currentURL == urlString && isPlaying { stop(); return }
        stop()
        guard let url = URL(string: urlString) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        currentURL = urlString
        let item = AVPlayerItem(url: url)
        let av = AVPlayer(playerItem: item)
        self.player = av
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isPlaying = false; self?.currentURL = nil }
        }
        av.play()
        isPlaying = true
    }

    func stop() {
        player?.pause(); player = nil
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs); endObserver = nil }
        isPlaying = false; currentURL = nil
    }
}

// MARK: - Main Store
@MainActor
final class MotorsportStore: ObservableObject {
    private let ud = UserDefaults.standard
    private let transCacheKey = "apexgrid_trans_cache_v1"

    @Published var isLoading = false
    @Published var isLoadingTelemetry = false
    @Published var isTranslating = false
    @Published var lastUpdated: Date?

    @Published var driverStandings: [RaceSeries: [DriverStanding]] = [:]
    @Published var teamStandings: [RaceSeries: [TeamStanding]] = [:]
    @Published var schedules: [RaceSeries: [RaceEvent]] = [:]
    @Published var latestResults: [RaceSeries: LatestRaceSummary] = [:]

    // OpenF1 Rich Telemetry
    @Published var openF1SessionName = ""
    @Published var f1Strategies: [F1DriverStrategy] = []
    @Published var f1RadioClips: [F1TeamRadioClip] = []
    @Published var f1RaceControl: [F1RaceControlMsg] = []
    @Published var f1Weather: F1WeatherSnapshot?
    @Published var f1TopSpeeds: [F1SpeedTrapRow] = []
    @Published var f1FastestPits: [F1PitStopRow] = []
    @Published var f1FastestLapText = "--"

    // News & AI Translation
    @Published var articles: [NewsArticle] = []
    @Published var translatedCache: [String: String] = [:]
    @Published var pendingNativeTexts: [String] = []
    @Published var nativeTranslateTriggerID = UUID()

    // AI Race Briefing
    @Published var aiBriefingText = ""
    @Published var isGeneratingBriefing = false

    // User Settings
    @Published var spoilerFree: Bool { didSet { ud.set(spoilerFree, forKey: "ag_spoiler_free") } }
    @Published var theme: TeamTheme { didSet { ud.set(theme.rawValue, forKey: "ag_theme") } }
    @Published var wallpaperBlur: Double { didSet { ud.set(wallpaperBlur, forKey: "ag_wall_blur") } }
    @Published var wallpaperDim: Double { didSet { ud.set(wallpaperDim, forKey: "ag_wall_dim") } }
    @Published var enableParticles: Bool { didSet { ud.set(enableParticles, forKey: "ag_particles") } }
    @Published var enableHaptics: Bool { didSet { ud.set(enableHaptics, forKey: "ag_haptics") } }
    @Published var onlyBreakingNews: Bool { didSet { ud.set(onlyBreakingNews, forKey: "ag_breaking_only") } }

    @Published var autoTranslateEnabled: Bool { didSet { ud.set(autoTranslateEnabled, forKey: "ag_auto_trans") } }
    @Published var showOriginalEnglish: Bool { didSet { ud.set(showOriginalEnglish, forKey: "ag_show_orig") } }
    @Published var translationMode: TranslationEngineMode { didSet { ud.set(translationMode.rawValue, forKey: "ag_trans_mode") } }
    @Published var geminiAPIKey: String { didSet { ud.set(geminiAPIKey, forKey: "ag_gemini_key") } }

    init() {
        let ud = UserDefaults.standard
        spoilerFree = ud.object(forKey: "ag_spoiler_free") as? Bool ?? false
        theme = TeamTheme(rawValue: ud.string(forKey: "ag_theme") ?? "") ?? .ferrari
        wallpaperBlur = ud.object(forKey: "ag_wall_blur") as? Double ?? 8.0
        wallpaperDim = ud.object(forKey: "ag_wall_dim") as? Double ?? 0.52
        enableParticles = ud.object(forKey: "ag_particles") as? Bool ?? true
        enableHaptics = ud.object(forKey: "ag_haptics") as? Bool ?? true
        onlyBreakingNews = ud.object(forKey: "ag_breaking_only") as? Bool ?? false
        autoTranslateEnabled = ud.object(forKey: "ag_auto_trans") as? Bool ?? true
        showOriginalEnglish = ud.object(forKey: "ag_show_orig") as? Bool ?? true
        translationMode = TranslationEngineMode(rawValue: ud.string(forKey: "ag_trans_mode") ?? "") ?? .autoFree
        geminiAPIKey = ud.string(forKey: "ag_gemini_key") ?? ""
        translatedCache = ud.dictionary(forKey: transCacheKey) as? [String: String] ?? [:]

        seedTCRFallback()
        seedMotoGPFallback()
    }

    func haptic() {
        guard enableHaptics else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func displayTranslated(_ raw: String) -> String {
        guard autoTranslateEnabled else { return raw }
        if let hit = translatedCache[raw] { return hit }
        if let quick = MotorsportTranslator.quickLookup(raw) { return quick }
        return raw
    }

    func hasTranslation(for raw: String) -> Bool {
        translatedCache[raw] != nil || MotorsportTranslator.quickLookup(raw) != nil
    }

    func applyNativeTranslations(_ map: [String: String]) {
        guard !map.isEmpty else { return }
        for (k, v) in map { translatedCache[k] = v }
        persistTransCache()
        isTranslating = false
    }

    func clearTranslationCache() {
        translatedCache = [:]
        ud.removeObject(forKey: transCacheKey)
    }

    private func persistTransCache() {
        // Keep cache bounded to 400 latest entries
        if translatedCache.count > 400 {
            let trimmed = Dictionary(uniqueKeysWithValues: Array(translatedCache.prefix(350)))
            translatedCache = trimmed
        }
        ud.set(translatedCache, forKey: transCacheKey)
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

        if autoTranslateEnabled {
            await translateLoadedContent()
        }
    }

    func translateLoadedContent() async {
        guard autoTranslateEnabled else { return }
        var targets: [String] = []
        for art in articles.prefix(24) {
            if translatedCache[art.title] == nil && MotorsportTranslator.quickLookup(art.title) == nil {
                targets.append(art.title)
            }
        }
        for msg in f1RaceControl.prefix(15) {
            if translatedCache[msg.message] == nil {
                targets.append(msg.message)
            }
        }
        guard !targets.isEmpty else { return }

        if translationMode == .appleOnDevice {
            isTranslating = true
            pendingNativeTexts = targets
            nativeTranslateTriggerID = UUID()
            return
        }

        isTranslating = true
        defer { isTranslating = false }

        if translationMode == .geminiPro && !geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let batch = await MotorsportTranslator.translateBatchGemini(Array(targets.prefix(25)), apiKey: geminiAPIKey)
            if !batch.isEmpty {
                for (k, v) in batch { translatedCache[k] = v }
                persistTransCache()
                return
            }
        }

        // Default / Fallback: Free Instant Cloud Auto-Translation (batches of 5)
        let limited = Array(targets.prefix(22))
        await withTaskGroup(of: (String, String?).self) { group in
            for text in limited {
                group.addTask {
                    let zh = await MotorsportTranslator.translateFreeCloud(text)
                    return (text, zh)
                }
            }
            for await (orig, zh) in group {
                if let zh, !zh.isEmpty {
                    translatedCache[orig] = zh
                }
            }
        }
        persistTransCache()
    }

    func generateAIBriefing() async {
        isGeneratingBriefing = true
        defer { isGeneratingBriefing = false }

        var lines: [String] = []
        for s in RaceSeries.allCases {
            if let p1 = driverStandings[s]?.first {
                let gap = (driverStandings[s]?.count ?? 0) > 1 ? Int(p1.points - driverStandings[s]![1].points) : 0
                lines.append("\(s.rawValue) 領先車手：\(p1.name)（\(p1.team)）\(Int(p1.points))分，領先第2名 \(gap) 分。")
            }
        }
        if let latest = latestResults[.f1], let winner = latest.results.first {
            lines.append("最新 F1 賽事 \(latest.raceName) 冠軍：\(winner.driverName)（\(winner.teamName)）。")
        }
        if let topSpd = f1TopSpeeds.first {
            lines.append("最新 F1 尾速王：\(topSpd.acronym) 錄得 \(topSpd.maxSpeedKmh) km/h。")
        }
        if let pit = f1FastestPits.first {
            lines.append("最快進站：\(pit.acronym) 僅花 \(String(format: "%.1f", pit.durationSec)) 秒。")
        }
        if let w = f1Weather {
            lines.append("賽道天氣：賽道 \(Int(w.trackTemp))°C / 氣溫 \(Int(w.airTemp))°C / \(w.isRaining ? "有雨" : "乾地")。")
        }
        let topNews = articles.prefix(5).map { "[\($0.series.rawValue)] \(displayTranslated($0.title))" }
        if !topNews.isEmpty {
            lines.append("最新焦點新聞：\n" + topNews.joined(separator: "\n"))
        }

        let summaryContext = lines.joined(separator: "\n")
        if !geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let aiText = await MotorsportTranslator.generateGeminiBriefing(contextText: summaryContext, apiKey: geminiAPIKey) {
            aiBriefingText = aiText
        } else {
            // Instant local structured Cantonese summary
            var local = "🏁 即時賽況重點速報\n\n"
            for s in RaceSeries.allCases {
                if let p1 = driverStandings[s]?.first {
                    let gap = (driverStandings[s]?.count ?? 0) > 1 ? Int(p1.points - driverStandings[s]![1].points) : 0
                    local += "• \(s.rawValue) 榜首：\(p1.name)（\(Int(p1.points)) 分，領先 +\(gap) 分）\n"
                }
            }
            if let spd = f1TopSpeeds.first, let pit = f1FastestPits.first {
                local += "• 遙測亮點：\(spd.acronym) 飆出全場最高 \(spd.maxSpeedKmh) km/h 尾速；\(pit.acronym) 造出 \(String(format: "%.1f", pit.durationSec)) 秒最快進站。\n"
            }
            if let firstNews = articles.first {
                local += "• 頭條焦點：\(displayTranslated(firstNews.title))\n"
            }
            local += "\n💡 提示：喺「設定」貼入免費 Gemini API Key 即可解鎖 AI 廣東話深度賽評分析。"
            aiBriefingText = local
        }
    }

    // MARK: - Season Progress & Helpers
    func nextEvent(for series: RaceSeries) -> RaceEvent? {
        let now = Date()
        return (schedules[series] ?? []).first { $0.raceDate > now } ?? (schedules[series] ?? []).last
    }

    func nextGlobalEvent() -> RaceEvent? {
        let now = Date()
        return RaceSeries.allCases.compactMap { s in (schedules[s] ?? []).first { $0.raceDate > now } }
            .sorted { $0.raceDate < $1.raceDate }.first
    }

    func f1SeasonProgress() -> (completed: Int, total: Int) {
        let all = schedules[.f1] ?? []
        guard !all.isEmpty else { return (0, 24) }
        let done = all.filter { $0.raceDate < Date() }.count
        return (done, all.count)
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
            content.body = "\(displayTranslated(event.name)) 將於澳門時間 \(RaceDateFmt.hmMacau.string(from: event.raceDate)) 燈滅起跑。"
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let req = UNNotificationRequest(identifier: "race_\(event.id)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
            try await center.add(req)
            return true
        } catch { return false }
    }

    func exportStandingsCSV() -> URL? {
        var csv = "Series,Position,Driver,Team,Points,Wins\n"
        for s in RaceSeries.allCases {
            for d in driverStandings[s] ?? [] {
                csv += "\(s.rawValue),\(d.position),\(d.name.replacingOccurrences(of: ",", with: " ")),\(d.team.replacingOccurrences(of: ",", with: " ")),\(Int(d.points)),\(d.wins)\n"
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ApexGrid_Standings.csv")
        do { try csv.write(to: url, atomically: true, encoding: .utf8); return url } catch { return nil }
    }

    // MARK: - 1. Jolpica F1 API
    private func fetchF1Jolpica() async {
        if let url = URL(string: "https://api.jolpi.ca/ergast/f1/current/driverStandings.json"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let root = try? JSONDecoder().decode(JolpicaDriverRoot.self, from: data),
           let list = root.MRData?.StandingsTable?.StandingsLists?.first?.DriverStandings, !list.isEmpty {
            driverStandings[.f1] = list.map { row in
                let team = row.Constructors?.first?.name ?? "F1"
                let code = row.Driver?.code ?? String((row.Driver?.familyName ?? "DRV").prefix(3)).uppercased()
                return DriverStanding(
                    id: "f1_\(row.Driver?.driverId ?? code)", series: .f1,
                    position: Int(row.position ?? "0") ?? 0,
                    name: "\(row.Driver?.givenName ?? "") \(row.Driver?.familyName ?? "")",
                    shortCode: code, number: row.Driver?.permanentNumber ?? "",
                    team: team, points: Double(row.points ?? "0") ?? 0,
                    wins: Int(row.wins ?? "0") ?? 0, colorHex: Self.f1TeamColor(team)
                )
            }
        }

        if let url = URL(string: "https://api.jolpi.ca/ergast/f1/current/constructorStandings.json"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let root = try? JSONDecoder().decode(JolpicaConstructorRoot.self, from: data),
           let list = root.MRData?.StandingsTable?.StandingsLists?.first?.ConstructorStandings, !list.isEmpty {
            teamStandings[.f1] = list.map { row in
                let name = row.Constructor?.name ?? "Team"
                return TeamStanding(
                    id: "f1_team_\(row.Constructor?.constructorId ?? name)", series: .f1,
                    position: Int(row.position ?? "0") ?? 0, name: name,
                    points: Double(row.points ?? "0") ?? 0, wins: Int(row.wins ?? "0") ?? 0,
                    colorHex: Self.f1TeamColor(name)
                )
            }
        }

        if let url = URL(string: "https://api.jolpi.ca/ergast/f1/current.json"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let root = try? JSONDecoder().decode(JolpicaScheduleRoot.self, from: data),
           let races = root.MRData?.RaceTable?.Races, !races.isEmpty {
            schedules[.f1] = races.compactMap { r in
                guard let raceD = RaceDateFmt.parseISO("\(r.date)T\(r.time ?? "12:00:00Z")") else { return nil }
                return RaceEvent(
                    id: "f1_r\(r.round)", series: .f1, round: Int(r.round) ?? 0, name: r.raceName,
                    circuit: r.Circuit?.circuitName ?? "",
                    location: "\(r.Circuit?.Location?.locality ?? ""), \(r.Circuit?.Location?.country ?? "")",
                    raceDate: raceD,
                    qualiDate: r.Qualifying.flatMap { RaceDateFmt.parseISO("\($0.date)T\($0.time ?? "12:00:00Z")") },
                    sprintDate: r.Sprint.flatMap { RaceDateFmt.parseISO("\($0.date)T\($0.time ?? "12:00:00Z")") }
                )
            }
        }

        if let url = URL(string: "https://api.jolpi.ca/ergast/f1/current/last/results.json"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let root = try? JSONDecoder().decode(JolpicaResultsRoot.self, from: data),
           let race = root.MRData?.RaceTable?.Races?.first, let res = race.Results, !res.isEmpty {
            latestResults[.f1] = LatestRaceSummary(
                series: .f1, raceName: race.raceName, dateText: race.date,
                results: res.map { r in
                    RaceResultRow(
                        id: "f1_res_\(r.position ?? "0")_\(r.Driver?.familyName ?? "")",
                        position: Int(r.position ?? "0") ?? 0,
                        driverName: "\(r.Driver?.givenName ?? "") \(r.Driver?.familyName ?? "")",
                        teamName: r.Constructor?.name ?? "",
                        timeOrStatus: r.Time?.time ?? (r.status ?? ""),
                        points: Double(r.points ?? "0") ?? 0
                    )
                }
            )
        }
    }

    // MARK: - 2. OpenF1 Rate-Limit-Safe Telemetry (Stints + Radio + RaceControl + Weather + Pit + Speed Trap)
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
                    chosenSession = past; break
                } else if let last = list.last {
                    chosenSession = last; break
                }
            }
        }
        guard let session = chosenSession else { return }
        openF1SessionName = "\(session.country_name ?? "F1") GP · \(session.location ?? "") (\(session.year ?? currentYear))"
        let sk = session.session_key

        // Drivers
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
                    F1TireStint(stintNumber: $0.stint_number, lapStart: $0.lap_start ?? 1, lapEnd: $0.lap_end ?? ($0.lap_start ?? 1), compound: $0.compound ?? "UNKNOWN")
                }
                guard !stints.isEmpty else { return nil }
                let info = driverMap[num]
                return F1DriverStrategy(id: num, driverNumber: num, acronym: info?.name_acronym ?? "#\(num)", fullName: info?.full_name ?? "Driver #\(num)", teamColorHex: info?.team_colour ?? "88AADD", stints: stints)
            }
            .sorted { $0.totalLaps > $1.totalLaps || ($0.totalLaps == $1.totalLaps && $0.driverNumber < $1.driverNumber) }
            if !built.isEmpty { f1Strategies = built }
        }

        try? await Task.sleep(nanoseconds: 250_000_000)

        // Weather
        if let url = URL(string: "https://api.openf1.org/v1/weather?session_key=\(sk)"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let list = try? JSONDecoder().decode([OpenF1WeatherDTO].self, from: data),
           let last = list.last {
            f1Weather = F1WeatherSnapshot(
                airTemp: last.air_temperature ?? 24,
                trackTemp: last.track_temperature ?? 35,
                humidity: last.humidity ?? 55,
                windSpeed: last.wind_speed ?? 2.0,
                isRaining: (last.rainfall ?? 0) > 0
            )
        }

        // Pit Stops
        if let url = URL(string: "https://api.openf1.org/v1/pit?session_key=\(sk)"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let list = try? JSONDecoder().decode([OpenF1PitDTO].self, from: data) {
            let valid = list.compactMap { p -> F1PitStopRow? in
                guard let dur = p.pit_duration, dur > 1.5, dur < 60 else { return nil }
                let info = driverMap[p.driver_number]
                return F1PitStopRow(acronym: info?.name_acronym ?? "#\(p.driver_number)", teamColorHex: info?.team_colour ?? "FFFFFF", lapNumber: p.lap_number ?? 0, durationSec: dur)
            }
            .sorted { $0.durationSec < $1.durationSec }
            f1FastestPits = Array(valid.prefix(8))
        }

        try? await Task.sleep(nanoseconds: 250_000_000)

        // Speed Trap & Fastest Lap (OpenF1 /v1/laps)
        if let url = URL(string: "https://api.openf1.org/v1/laps?session_key=\(sk)"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let list = try? JSONDecoder().decode([OpenF1LapDTO].self, from: data) {
            var maxSpeedByDriver: [Int: Int] = [:]
            var bestLap: (num: Int, sec: Double)?
            for l in list {
                if let spd = l.st_speed, spd > 150, spd < 400 {
                    maxSpeedByDriver[l.driver_number] = max(maxSpeedByDriver[l.driver_number] ?? 0, spd)
                }
                if let dur = l.lap_duration, dur > 50, dur < 200 {
                    if bestLap == nil || dur < bestLap!.sec {
                        bestLap = (l.driver_number, dur)
                    }
                }
            }
            f1TopSpeeds = maxSpeedByDriver.map { num, spd in
                let info = driverMap[num]
                return F1SpeedTrapRow(id: num, acronym: info?.name_acronym ?? "#\(num)", fullName: info?.full_name ?? "Driver #\(num)", teamColorHex: info?.team_colour ?? "88CCFF", maxSpeedKmh: spd)
            }
            .sorted { $0.maxSpeedKmh > $1.maxSpeedKmh }

            if let best = bestLap {
                let mins = Int(best.sec) / 60
                let rem = best.sec - Double(mins * 60)
                let code = driverMap[best.num]?.name_acronym ?? "#\(best.num)"
                f1FastestLapText = String(format: "%@ %d:%06.3f", code, mins, rem)
            }
        }

        try? await Task.sleep(nanoseconds: 250_000_000)

        // Team Radio
        if let url = URL(string: "https://api.openf1.org/v1/team_radio?session_key=\(sk)"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let list = try? JSONDecoder().decode([OpenF1RadioDTO].self, from: data) {
            f1RadioClips = Array(list.compactMap { r -> F1TeamRadioClip? in
                guard let rec = r.recording_url, !rec.isEmpty else { return nil }
                let info = driverMap[r.driver_number]
                return F1TeamRadioClip(id: rec, driverNumber: r.driver_number, acronym: info?.name_acronym ?? "#\(r.driver_number)", fullName: info?.full_name ?? "Driver #\(r.driver_number)", teamColorHex: info?.team_colour ?? "E82028", date: RaceDateFmt.parseISO(r.date) ?? Date(), recordingURL: rec)
            }.sorted { $0.date > $1.date }.prefix(36))
        }

        // Race Control
        if let url = URL(string: "https://api.openf1.org/v1/race_control?session_key=\(sk)"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let list = try? JSONDecoder().decode([OpenF1RaceControlDTO].self, from: data) {
            f1RaceControl = Array(list.compactMap { m -> F1RaceControlMsg? in
                guard let txt = m.message, !txt.isEmpty else { return nil }
                return F1RaceControlMsg(date: RaceDateFmt.parseISO(m.date) ?? Date(), category: m.category ?? "INFO", flag: m.flag ?? "", message: txt, lapNumber: m.lap_number)
            }.sorted { $0.date > $1.date }.prefix(30))
        }
    }

    // MARK: - 3. MotoGP PulseLive
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
            driverStandings[.motogp] = rows.enumerated().map { idx, row in
                let fullName = row.rider?.full_name ?? "Rider"
                let code = String((fullName.split(separator: " ").last ?? Substring(fullName)).prefix(3)).uppercased()
                let team = row.team?.name ?? row.constructor?.name ?? "MotoGP"
                return DriverStanding(id: "mgp_\(row.rider?.id ?? "\(idx)")", series: .motogp, position: row.position ?? (idx + 1), name: fullName, shortCode: code, number: row.rider?.number.map { "\($0)" } ?? "", team: team, points: row.points ?? 0, wins: 0, colorHex: Self.motoTeamColor(team))
            }
        }

        if let evURL = URL(string: "https://api.motogp.pulselive.com/motogp/v1/results/events?seasonUuid=\(season.id)&isFinished=false"),
           let (evData, _) = try? await URLSession.shared.data(from: evURL),
           let events = try? JSONDecoder().decode([PulseEventDTO].self, from: evData), !events.isEmpty {
            let mapped: [RaceEvent] = events.enumerated().compactMap { idx, e in
                guard let dt = RaceDateFmt.parseISO(e.date_end ?? e.date_start) else { return nil }
                return RaceEvent(id: "mgp_ev_\(e.id)", series: .motogp, round: idx + 1, name: e.name ?? e.short_name ?? "MotoGP GP", circuit: e.circuit?.name ?? "Circuit", location: e.country?.name ?? "", raceDate: dt, qualiDate: nil, sprintDate: nil)
            }
            if !mapped.isEmpty { schedules[.motogp] = mapped }
        }
    }

    // MARK: - 4. RSS Aggregator
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
                    var req = URLRequest(url: url); req.timeoutInterval = 10
                    req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
                    guard let (data, resp) = try? await URLSession.shared.data(for: req),
                          let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return [] }
                    return Array(MotorsportRSSParser(series: feed.series, sourceName: feed.name).parse(data: data).prefix(14))
                }
            }
            for await batch in group { collected.append(contentsOf: batch) }
        }
        var seen = Set<String>()
        let unique = collected.filter { seen.insert($0.id).inserted }.sorted { $0.pubDate > $1.pubDate }
        if !unique.isEmpty { articles = unique }
    }

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
            DriverStanding(id: "mgp_f1", series: .motogp, position: 1, name: "Marc Márquez", shortCode: "MAR", number: "93", team: "Ducati Lenovo Team", points: 439, wins: 9, colorHex: "E01018"),
            DriverStanding(id: "mgp_f2", series: .motogp, position: 2, name: "Jorge Martín", shortCode: "MRT", number: "89", team: "Aprilia Racing", points: 396, wins: 5, colorHex: "22C55E"),
            DriverStanding(id: "mgp_f3", series: .motogp, position: 3, name: "Marco Bezzecchi", shortCode: "BEZ", number: "72", team: "Aprilia Racing", points: 394, wins: 4, colorHex: "22C55E"),
            DriverStanding(id: "mgp_f4", series: .motogp, position: 4, name: "Pedro Acosta", shortCode: "ACO", number: "37", team: "Red Bull KTM Factory", points: 315, wins: 2, colorHex: "FF6B00")
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

// MARK: - Private DTOs
private struct JolpicaDriverRoot: Codable {
    let MRData: MR?; struct MR: Codable { let StandingsTable: ST? }; struct ST: Codable { let StandingsLists: [SL]? }; struct SL: Codable { let DriverStandings: [DS]? }
    struct DS: Codable { let position: String?; let points: String?; let wins: String?; let Driver: Drv?; let Constructors: [Con]? }
    struct Drv: Codable { let driverId: String?; let permanentNumber: String?; let code: String?; let givenName: String?; let familyName: String? }
    struct Con: Codable { let constructorId: String?; let name: String? }
}
private struct JolpicaConstructorRoot: Codable {
    let MRData: MR?; struct MR: Codable { let StandingsTable: ST? }; struct ST: Codable { let StandingsLists: [SL]? }; struct SL: Codable { let ConstructorStandings: [CS]? }
    struct CS: Codable { let position: String?; let points: String?; let wins: String?; let Constructor: Con? }
    struct Con: Codable { let constructorId: String?; let name: String? }
}
private struct JolpicaScheduleRoot: Codable {
    let MRData: MR?; struct MR: Codable { let RaceTable: RT? }; struct RT: Codable { let Races: [R]? }
    struct R: Codable { let round: String; let raceName: String; let date: String; let time: String?; let Circuit: Circ?; let Qualifying: Sess?; let Sprint: Sess? }
    struct Circ: Codable { let circuitName: String?; let Location: Loc? }; struct Loc: Codable { let locality: String?; let country: String? }; struct Sess: Codable { let date: String; let time: String? }
}
private struct JolpicaResultsRoot: Codable {
    let MRData: MR?; struct MR: Codable { let RaceTable: RT? }; struct RT: Codable { let Races: [R]? }
    struct R: Codable { let raceName: String; let date: String; let Results: [Res]? }
    struct Res: Codable { let position: String?; let points: String?; let status: String?; let Driver: Drv?; let Constructor: Con?; let Time: Tm? }
    struct Drv: Codable { let givenName: String?; let familyName: String? }; struct Con: Codable { let name: String? }; struct Tm: Codable { let time: String? }
}
private struct OpenF1Session: Codable { let session_key: Int; let country_name: String?; let location: String?; let date_start: String?; let year: Int? }
private struct OpenF1Driver: Codable { let driver_number: Int; let name_acronym: String?; let full_name: String?; let team_colour: String? }
private struct OpenF1StintDTO: Codable { let driver_number: Int; let stint_number: Int; let lap_start: Int?; let lap_end: Int?; let compound: String? }
private struct OpenF1RadioDTO: Codable { let driver_number: Int; let date: String?; let recording_url: String? }
private struct OpenF1RaceControlDTO: Codable { let date: String?; let category: String?; let flag: String?; let message: String?; let lap_number: Int? }
private struct OpenF1WeatherDTO: Codable { let air_temperature: Double?; let track_temperature: Double?; let humidity: Double?; let wind_speed: Double?; let rainfall: Int? }
private struct OpenF1PitDTO: Codable { let driver_number: Int; let lap_number: Int?; let pit_duration: Double? }
private struct OpenF1LapDTO: Codable { let driver_number: Int; let lap_duration: Double?; let st_speed: Int? }
private struct PulseSeasonDTO: Codable { let id: String; let year: Int; let current: Bool? }
private struct PulseCategoryDTO: Codable { let id: String; let name: String }
private struct PulseStandingsRoot: Codable {
    let classification: [Row]?
    struct Row: Codable { let position: Int?; let points: Double?; let rider: Rider?; let team: Named?; let constructor: Named? }
    struct Rider: Codable { let id: String?; let full_name: String?; let number: Int? }; struct Named: Codable { let name: String? }
}
private struct PulseEventDTO: Codable {
    let id: String; let name: String?; let short_name: String?; let date_start: String?; let date_end: String?; let circuit: Named?; let country: Named?
    struct Named: Codable { let name: String? }
}
