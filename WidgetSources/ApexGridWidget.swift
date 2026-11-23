import WidgetKit
import SwiftUI

struct RaceWidgetEntry: TimelineEntry {
    let date: Date
    let nextRaceName: String
    let circuitName: String
    let raceDate: Date
    let leaderName: String
    let leaderPoints: String
    let leaderTeam: String
}

final class WidgetRaceFetcher {
    private static let cacheKey = "apexgrid_widget_v3"

    private struct CacheData: Codable {
        let nextRaceName: String
        let circuitName: String
        let raceTimestamp: TimeInterval
        let leaderName: String
        let leaderPoints: String
        let leaderTeam: String
    }

    private struct SchedRoot: Codable {
        let MRData: MR?
        struct MR: Codable { let RaceTable: RT? }
        struct RT: Codable { let Races: [R]? }
        struct R: Codable { let raceName: String; let date: String; let time: String?; let Circuit: C? }
        struct C: Codable { let circuitName: String? }
    }

    private struct StandRoot: Codable {
        let MRData: MR?
        struct MR: Codable { let StandingsTable: ST? }
        struct ST: Codable { let StandingsLists: [SL]? }
        struct SL: Codable { let DriverStandings: [Row]? }
        struct Row: Codable { let points: String?; let Driver: D?; let Constructors: [C]? }
        struct D: Codable { let givenName: String?; let familyName: String? }
        struct C: Codable { let name: String? }
    }

    static func fallback() -> RaceWidgetEntry {
        if let d = UserDefaults.standard.data(forKey: cacheKey),
           let c = try? JSONDecoder().decode(CacheData.self, from: d) {
            return RaceWidgetEntry(
                date: Date(), nextRaceName: c.nextRaceName, circuitName: c.circuitName,
                raceDate: Date(timeIntervalSince1970: c.raceTimestamp),
                leaderName: c.leaderName, leaderPoints: c.leaderPoints, leaderTeam: c.leaderTeam
            )
        }
        return RaceWidgetEntry(
            date: Date(), nextRaceName: "Grand Prix", circuitName: "Formula 1",
            raceDate: Date().addingTimeInterval(86400 * 5),
            leaderName: "載入中", leaderPoints: "-- PTS", leaderTeam: "F1"
        )
    }

    static func fetch(completion: @escaping (RaceWidgetEntry) -> Void) {
        Task {
            let entry = await fetchAsync()
            await MainActor.run { completion(entry) }
        }
    }

    private static func fetchAsync() async -> RaceWidgetEntry {
        var name = "Next Grand Prix", circuit = "Formula 1"
        var dt = Date().addingTimeInterval(86400 * 7)
        var leader = "--", pts = "--", team = "F1", ok = false

        if let u = URL(string: "https://api.jolpi.ca/ergast/f1/current.json"),
           let (d, _) = try? await URLSession.shared.data(from: u),
           let races = (try? JSONDecoder().decode(SchedRoot.self, from: d))?.MRData?.RaceTable?.Races {
            let iso = ISO8601DateFormatter()
            for r in races {
                if let parsed = iso.date(from: "\(r.date)T\(r.time ?? "12:00:00Z")"), parsed > Date() {
                    name = r.raceName
                    circuit = r.Circuit?.circuitName ?? "Formula 1"
                    dt = parsed
                    ok = true
                    break
                }
            }
        }

        if let u = URL(string: "https://api.jolpi.ca/ergast/f1/current/driverStandings.json"),
           let (d, _) = try? await URLSession.shared.data(from: u),
           let p1 = (try? JSONDecoder().decode(StandRoot.self, from: d))?.MRData?.StandingsTable?.StandingsLists?.first?.DriverStandings?.first {
            leader = "\(String((p1.Driver?.givenName ?? "").prefix(1))). \(p1.Driver?.familyName ?? "")"
            pts = "\(p1.points ?? "0") PTS"
            team = p1.Constructors?.first?.name ?? "F1"
            ok = true
        }

        guard ok else { return fallback() }
        let cache = CacheData(nextRaceName: name, circuitName: circuit, raceTimestamp: dt.timeIntervalSince1970, leaderName: leader, leaderPoints: pts, leaderTeam: team)
        if let enc = try? JSONEncoder().encode(cache) { UserDefaults.standard.set(enc, forKey: cacheKey) }
        return RaceWidgetEntry(date: Date(), nextRaceName: name, circuitName: circuit, raceDate: dt, leaderName: leader, leaderPoints: pts, leaderTeam: team)
    }
}

struct ApexGridProvider: TimelineProvider {
    func placeholder(in context: Context) -> RaceWidgetEntry {
        RaceWidgetEntry(date: Date(), nextRaceName: "Qatar Grand Prix", circuitName: "Lusail", raceDate: Date().addingTimeInterval(86400 * 5), leaderName: "C. Leclerc", leaderPoints: "380 PTS", leaderTeam: "Ferrari")
    }
    func getSnapshot(in context: Context, completion: @escaping (RaceWidgetEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)) } else { WidgetRaceFetcher.fetch(completion: completion) }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RaceWidgetEntry>) -> Void) {
        WidgetRaceFetcher.fetch { entry in
            let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

struct ApexGridWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: RaceWidgetEntry

    private func macau(_ d: Date) -> String {
        let f = DateFormatter(); f.timeZone = TimeZone(identifier: "Asia/Macau"); f.dateFormat = "M/d HH:mm"; return f.string(from: d)
    }
    private func cd(_ d: Date) -> String {
        let s = max(0, Int(d.timeIntervalSinceNow)), days = s / 86400, hrs = (s % 86400) / 3600
        return days > 0 ? "\(days)日 \(hrs)小時" : "\(hrs)h \((s % 3600) / 60)m"
    }

    var body: some View {
        switch family {
        case .systemMedium:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("F1 下一站").font(.system(size: 10.5, weight: .black)).foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 2).background(Color.red, in: Capsule())
                    Text(entry.nextRaceName).font(.system(size: 15, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                    Text(entry.circuitName).font(.system(size: 11)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                    Spacer(minLength: 2)
                    Text(cd(entry.raceDate)).font(.system(size: 21, weight: .black, design: .rounded)).foregroundStyle(Color(red: 1.0, green: 0.36, blue: 0.32)).monospacedDigit()
                    Text("澳門 \(macau(entry.raceDate))").font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.55))
                }
                Divider().overlay(Color.white.opacity(0.15))
                VStack(alignment: .leading, spacing: 5) {
                    Label("領先 P1", systemImage: "crown.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.yellow)
                    Spacer(minLength: 2)
                    Text(entry.leaderName).font(.system(size: 15.5, weight: .bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
                    Text(entry.leaderTeam).font(.system(size: 11)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                    Spacer(minLength: 2)
                    Text(entry.leaderPoints).font(.system(size: 13.5, weight: .heavy, design: .rounded)).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 4).background(Color.white.opacity(0.12), in: Capsule())
                }.frame(width: 112, alignment: .leading)
            }
            .containerBackground(for: .widget) {
                LinearGradient(colors: [Color(red: 0.14, green: 0.04, blue: 0.06), Color(red: 0.04, green: 0.04, blue: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        case .accessoryCircular:
            VStack(spacing: 1) {
                Image(systemName: "flag.checkered").font(.system(size: 11))
                Text("\(max(0, Int(entry.raceDate.timeIntervalSinceNow / 86400)))D").font(.system(size: 14, weight: .black, design: .rounded))
            }.containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.nextRaceName).font(.caption.bold()).lineLimit(1)
                Text(cd(entry.raceDate)).font(.system(size: 15, weight: .black, design: .rounded))
                Text("P1 \(entry.leaderName)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading).containerBackground(for: .widget) { Color.clear }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text("F1").font(.system(size: 11, weight: .black)).foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 2).background(Color.red, in: Capsule())
                Spacer(minLength: 2)
                Text(entry.nextRaceName).font(.system(size: 13.5, weight: .bold)).foregroundStyle(.white).lineLimit(2)
                Text(cd(entry.raceDate)).font(.system(size: 19, weight: .black, design: .rounded)).foregroundStyle(Color(red: 1.0, green: 0.36, blue: 0.32)).monospacedDigit()
                Spacer(minLength: 2)
                Text("澳門 \(macau(entry.raceDate))").font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(for: .widget) {
                LinearGradient(colors: [Color(red: 0.14, green: 0.04, blue: 0.06), Color(red: 0.04, green: 0.04, blue: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
}

@main
struct ApexGridWidgetBundle: WidgetBundle {
    var body: some Widget { ApexGridRaceWidget() }
}

struct ApexGridRaceWidget: Widget {
    let kind: String = "ApexGridRaceWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ApexGridProvider()) { entry in
            ApexGridWidgetView(entry: entry)
        }
        .configurationDisplayName("ApexGrid 賽車倒數")
        .description("顯示下一站大賽澳門時間倒數與目前領先榜 P1。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
