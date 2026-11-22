import WidgetKit
import SwiftUI

struct RaceWidgetEntry: TimelineEntry {
    let date: Date
    let seriesTag: String
    let nextRaceName: String
    let circuitName: String
    let raceDate: Date
    let leaderName: String
    let leaderPoints: String
    let leaderTeam: String
}

final class WidgetRaceFetcher {
    private static let cacheKey = "apexgrid_widget_cache_v1"

    private struct CachePayload: Codable {
        let nextRaceName: String
        let circuitName: String
        let raceTimestamp: TimeInterval
        let leaderName: String
        let leaderPoints: String
        let leaderTeam: String
    }

    private struct JolpicaScheduleRoot: Codable {
        let MRData: ScheduleMR?
        struct ScheduleMR: Codable { let RaceTable: RaceTable? }
        struct RaceTable: Codable { let Races: [Race]? }
        struct Race: Codable {
            let raceName: String
            let date: String
            let time: String?
            let Circuit: Circuit?
        }
        struct Circuit: Codable { let circuitName: String? }
    }

    private struct JolpicaStandingsRoot: Codable {
        let MRData: StandingsMR?
        struct StandingsMR: Codable { let StandingsTable: StandingsTable? }
        struct StandingsTable: Codable { let StandingsLists: [StandingsList]? }
        struct StandingsList: Codable { let DriverStandings: [DriverRow]? }
        struct DriverRow: Codable {
            let points: String?
            let Driver: Driver?
            let Constructors: [Constructor]?
        }
        struct Driver: Codable { let givenName: String?; let familyName: String? }
        struct Constructor: Codable { let name: String? }
    }

    static func fallbackEntry() -> RaceWidgetEntry {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let c = try? JSONDecoder().decode(CachePayload.self, from: data) {
            return RaceWidgetEntry(
                date: Date(),
                seriesTag: "F1",
                nextRaceName: c.nextRaceName,
                circuitName: c.circuitName,
                raceDate: Date(timeIntervalSince1970: c.raceTimestamp),
                leaderName: c.leaderName,
                leaderPoints: c.leaderPoints,
                leaderTeam: c.leaderTeam
            )
        }
        return RaceWidgetEntry(
            date: Date(),
            seriesTag: "F1",
            nextRaceName: "Grand Prix",
            circuitName: "FIA Formula 1",
            raceDate: Date().addingTimeInterval(86400 * 5),
            leaderName: "載入中",
            leaderPoints: "-- PTS",
            leaderTeam: "F1 World Championship"
        )
    }

    static func fetch(completion: @escaping (RaceWidgetEntry) -> Void) {
        let group = DispatchGroup()
        var nextName = "Next Grand Prix"
        var nextCircuit = "Formula 1"
        var nextDate = Date().addingTimeInterval(86400 * 7)
        var leader = "--"
        var pts = "--"
        var team = "F1"
        var success = false

        if let url = URL(string: "https://api.jolpi.ca/ergast/f1/current.json") {
            group.enter()
            URLSession.shared.dataTask(with: url) { data, _, _ in
                defer { group.leave() }
                guard let data, let root = try? JSONDecoder().decode(JolpicaScheduleRoot.self, from: data),
                      let races = root.MRData?.RaceTable?.Races else { return }
                let iso = ISO8601DateFormatter()
                let now = Date()
                for r in races {
                    let raw = "\(r.date)T\(r.time ?? "12:00:00Z")"
                    if let d = iso.date(from: raw), d > now {
                        nextName = r.raceName
                        nextCircuit = r.Circuit?.circuitName ?? "Formula 1"
                        nextDate = d
                        success = true
                        break
                    }
                }
            }.resume()
        }

        if let url = URL(string: "https://api.jolpi.ca/ergast/f1/current/driverStandings.json") {
            group.enter()
            URLSession.shared.dataTask(with: url) { data, _, _ in
                defer { group.leave() }
                guard let data, let root = try? JSONDecoder().decode(JolpicaStandingsRoot.self, from: data),
                      let first = root.MRData?.StandingsTable?.StandingsLists?.first?.DriverStandings?.first else { return }
                let fn = first.Driver?.givenName ?? ""
                let ln = first.Driver?.familyName ?? ""
                leader = "\(fn.prefix(1)). \(ln)"
                pts = "\(first.points ?? "0") PTS"
                team = first.Constructors?.first?.name ?? "F1"
                success = true
            }.resume()
        }

        group.notify(queue: .main) {
            if success {
                let payload = CachePayload(
                    nextRaceName: nextName,
                    circuitName: nextCircuit,
                    raceTimestamp: nextDate.timeIntervalSince1970,
                    leaderName: leader,
                    leaderPoints: pts,
                    leaderTeam: team
                )
                if let encoded = try? JSONEncoder().encode(payload) {
                    UserDefaults.standard.set(encoded, forKey: cacheKey)
                }
                completion(RaceWidgetEntry(
                    date: Date(),
                    seriesTag: "F1",
                    nextRaceName: nextName,
                    circuitName: nextCircuit,
                    raceDate: nextDate,
                    leaderName: leader,
                    leaderPoints: pts,
                    leaderTeam: team
                ))
            } else {
                completion(fallbackEntry())
            }
        }
    }
}

struct ApexGridProvider: TimelineProvider {
    func placeholder(in context: Context) -> RaceWidgetEntry {
        RaceWidgetEntry(
            date: Date(), seriesTag: "F1", nextRaceName: "Qatar Grand Prix",
            circuitName: "Lusail Circuit", raceDate: Date().addingTimeInterval(86400 * 6),
            leaderName: "C. Leclerc", leaderPoints: "382 PTS", leaderTeam: "Ferrari"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (RaceWidgetEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)) }
        else { WidgetRaceFetcher.fetch { completion($0) } }
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

    private func macauTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "Asia/Macau")
        f.dateFormat = "M/d HH:mm"
        return f.string(from: date)
    }

    private func countdownText(_ target: Date) -> String {
        let diff = max(0, Int(target.timeIntervalSinceNow))
        let days = diff / 86400
        let hours = (diff % 86400) / 3600
        let mins = (diff % 3600) / 60
        if days > 0 { return "\(days)日 \(hours)小時" }
        return "\(hours)h \(mins)m"
    }

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemMedium: mediumView
        case .accessoryCircular: lockCircular
        case .accessoryRectangular: lockRectangular
        default: smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.seriesTag)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color.red, in: Capsule())
                Spacer()
                Image(systemName: "flag.checkered")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer(minLength: 2)

            Text(entry.nextRaceName)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(countdownText(entry.raceDate))
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.32))
                .monospacedDigit()
                .minimumScaleFactor(0.75)

            Spacer(minLength: 2)

            Text("澳門 \(macauTime(entry.raceDate))")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.14, green: 0.04, blue: 0.06), Color(red: 0.04, green: 0.04, blue: 0.07)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    private var mediumView: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(entry.seriesTag)
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.red, in: Capsule())
                    Text("下一站倒數")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Text(entry.nextRaceName)
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(entry.circuitName)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(countdownText(entry.raceDate))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.36, blue: 0.32))
                    .monospacedDigit()
                Text("澳門時間 \(macauTime(entry.raceDate))")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Divider().overlay(.white.opacity(0.15))

            VStack(alignment: .leading, spacing: 5) {
                Label("領先榜 P1", systemImage: "crown.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.yellow)
                Spacer(minLength: 2)
                Text(entry.leaderName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(entry.leaderTeam)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(entry.leaderPoints)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            .frame(width: 116, alignment: .leading)
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.14, green: 0.04, blue: 0.06), Color(red: 0.04, green: 0.04, blue: 0.07)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    private var lockCircular: some View {
        let days = max(0, Int(entry.raceDate.timeIntervalSinceNow / 86400))
        return VStack(spacing: 1) {
            Image(systemName: "flag.checkered").font(.system(size: 11))
            Text("\(days)D").font(.system(size: 15, weight: .black, design: .rounded))
            Text("F1").font(.system(size: 9, weight: .bold))
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var lockRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flag.checkered")
                Text(entry.nextRaceName).font(.caption.bold()).lineLimit(1)
            }
            Text(countdownText(entry.raceDate)).font(.system(size: 16, weight: .black, design: .rounded))
            Text("P1 \(entry.leaderName) · \(entry.leaderPoints)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }
}

@main
struct ApexGridWidgetBundle: WidgetBundle {
    var body: some Widget {
        ApexGridRaceWidget()
    }
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
