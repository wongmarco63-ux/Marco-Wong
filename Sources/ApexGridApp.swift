import SwiftUI
import SafariServices

@main
struct ApexGridApp: App {
    @StateObject private var store = MotorsportStore()
    @StateObject private var radioPlayer = RadioAudioPlayer()

    var body: some Scene {
        WindowGroup {
            MainTabRootView()
                .environmentObject(store)
                .environmentObject(radioPlayer)
                .preferredColorScheme(.dark)
                .task {
                    await store.refreshAll()
                }
        }
    }
}

// MARK: - Native iOS 26 Liquid Glass Modifier (Safe Fallback for iOS 17/18)
struct RaceGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let interactive: Bool

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.white.opacity(0.20), lineWidth: 0.8))
        }
        #else
        content
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.20), lineWidth: 0.8))
        #endif
    }
}

extension View {
    func raceGlass<S: InsettableShape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(RaceGlassModifier(shape: shape, interactive: interactive))
    }
}

struct RacingBackgroundView: View {
    @EnvironmentObject var store: MotorsportStore
    var body: some View {
        ZStack {
            LinearGradient(colors: store.theme.bgColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [store.theme.accent.opacity(0.24), .clear], center: .topTrailing, startRadius: 10, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

struct GlassPanel<Content: View>: View {
    var cornerRadius: CGFloat = 22
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.55))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.05), .white.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
    }
}

struct SafariSheetView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredBarTintColor = .black
        vc.preferredControlTintColor = .white
        return vc
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Root Native TabView (5 Tabs)
struct MainTabRootView: View {
    @EnvironmentObject var store: MotorsportStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HubDashboardView()
                .tabItem { Label("看板", systemImage: "flag.checkered") }
                .tag(0)

            StandingsAndH2HView()
                .tabItem { Label("積分", systemImage: "trophy.fill") }
                .tag(1)

            F1TelemetryLabView()
                .tabItem { Label("遙測", systemImage: "waveform.path.ecg") }
                .tag(2)

            NewsFeedView()
                .tabItem { Label("新聞", systemImage: "newspaper.fill") }
                .tag(3)

            AppSettingsView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(store.theme.accent)
    }
}

// MARK: - TAB 1: Cross-Series Hub Dashboard
struct HubDashboardView: View {
    @EnvironmentObject var store: MotorsportStore
    @State private var reminderToast: String?
    @State private var revealSpoilersOnce = false

    private var isMasked: Bool { store.spoilerFree && !revealSpoilersOnce }

    var body: some View {
        NavigationStack {
            ZStack {
                RacingBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        // Top Bar
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("APEXGRID")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .tracking(2.5)
                                    .foregroundStyle(store.theme.accent)
                                Text("賽車總覽")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Button {
                                store.haptic()
                                withAnimation {
                                    store.spoilerFree.toggle()
                                    revealSpoilersOnce = false
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: store.spoilerFree ? "eye.slash.fill" : "eye.fill")
                                    Text(store.spoilerFree ? "防劇透" : "即時")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(store.spoilerFree ? .yellow : .white)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .raceGlass(in: Capsule(), interactive: true)
                            }
                        }

                        // Next Global Race Countdown Hero
                        if let next = store.nextGlobalEvent() {
                            NextRaceCountdownCard(event: next) {
                                Task {
                                    let ok = await store.scheduleReminder(for: next)
                                    showToast(ok ? "已設定開賽前 15 分鐘提醒！" : "無法排程（請檢查通知權限或賽事已開始）")
                                }
                            }
                        }

                        // Who's Leading Now (F1 / MotoGP / TCR)
                        HStack {
                            Text("誰領先緊 · 積分榜 P1")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            if isMasked {
                                Button("點此解鎖") {
                                    store.haptic()
                                    withAnimation { revealSpoilersOnce = true }
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.yellow)
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(RaceSeries.allCases) { series in
                                    let list = store.driverStandings[series] ?? []
                                    let p1 = list.first
                                    let p2 = list.count > 1 ? list[1] : nil
                                    LeaderMiniCard(series: series, p1: p1, p2: p2, masked: isMasked)
                                        .frame(width: 245)
                                }
                            }
                        }

                        // Upcoming Calendar (Macau Time)
                        Text("近期賽程（澳門時間）")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)

                        VStack(spacing: 10) {
                            ForEach(RaceSeries.allCases) { series in
                                if let ev = store.nextEvent(for: series) {
                                    GlassPanel(cornerRadius: 18) {
                                        HStack(spacing: 12) {
                                            Image(systemName: series.symbol)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(.white)
                                                .frame(width: 38, height: 38)
                                                .background(series.badgeColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                                            VStack(alignment: .leading, spacing: 3) {
                                                HStack(spacing: 6) {
                                                    Text(series.rawValue)
                                                        .font(.caption2.bold())
                                                        .foregroundStyle(series.badgeColor)
                                                    Text(ev.name)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundStyle(.white)
                                                        .lineLimit(1)
                                                }
                                                Text("\(ev.circuit) · \(RaceDateFmt.fullMacau.string(from: ev.raceDate))")
                                                    .font(.system(size: 11.5))
                                                    .foregroundStyle(.white.opacity(0.58))
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            Button {
                                                store.haptic()
                                                Task {
                                                    let ok = await store.scheduleReminder(for: ev)
                                                    showToast(ok ? "已預約 \(ev.name) 開賽提醒" : "賽事已過期或未開啟通知權限")
                                                }
                                            } label: {
                                                Image(systemName: "bell.badge.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(store.theme.accent)
                                                    .frame(width: 34, height: 34)
                                                    .background(.white.opacity(0.08), in: Circle())
                                            }
                                        }
                                        .padding(14)
                                    }
                                }
                            }
                        }

                        // Breaking Alerts Preview
                        let breaking = store.articles.filter(\.isBreaking).prefix(3)
                        if !breaking.isEmpty {
                            Text("重點突發快訊")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)

                            ForEach(Array(breaking)) { art in
                                GlassPanel(cornerRadius: 16) {
                                    HStack(alignment: .top, spacing: 10) {
                                        Text(art.alertTag ?? "重點")
                                            .font(.system(size: 10, weight: .black))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 7).padding(.vertical, 3)
                                            .background(Color.red, in: Capsule())
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(art.title)
                                                .font(.system(size: 13.5, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .blur(radius: isMasked ? 6 : 0)
                                            Text("\(art.series.rawValue) · \(RaceDateFmt.relativeText(art.pubDate))")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                        Spacer()
                                    }
                                    .padding(14)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
                .refreshable {
                    store.haptic()
                    await store.refreshAll()
                }

                if let toast = reminderToast {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .raceGlass(in: Capsule(), interactive: false)
                            .padding(.bottom, 22)
                    }
                    .transition(.opacity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func showToast(_ msg: String) {
        withAnimation { reminderToast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { reminderToast = nil }
        }
    }
}

struct NextRaceCountdownCard: View {
    @EnvironmentObject var store: MotorsportStore
    let event: RaceEvent
    let onRemind: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            let cd = RaceDateFmt.countdownParts(to: event.raceDate)
            GlassPanel(cornerRadius: 26) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: event.series.symbol)
                            Text("\(event.series.rawValue) · ROUND \(event.round)")
                        }
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(event.series.badgeColor, in: Capsule())

                        Spacer()

                        Button(action: onRemind) {
                            Label("提醒我", systemImage: "bell.fill")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.white.opacity(0.12), in: Capsule())
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(event.circuit) · 澳門時間 \(RaceDateFmt.fullMacau.string(from: event.raceDate))")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.white.opacity(0.65))
                    }

                    HStack(spacing: 10) {
                        countdownBox(value: "\(cd.days)", unit: "日")
                        countdownBox(value: "\(cd.hours)", unit: "小時")
                        countdownBox(value: "\(cd.mins)", unit: "分鐘")
                    }

                    if let quali = event.qualiDate {
                        HStack(spacing: 14) {
                            Label("排位 \(RaceDateFmt.fullMacau.string(from: quali))", systemImage: "stopwatch")
                            if let sprint = event.sprintDate {
                                Label("衝刺 \(RaceDateFmt.fullMacau.string(from: sprint))", systemImage: "bolt.fill")
                            }
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(20)
            }
        }
    }

    private func countdownBox(value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct LeaderMiniCard: View {
    let series: RaceSeries
    let p1: DriverStanding?
    let p2: DriverStanding?
    let masked: Bool

    var body: some View {
        let gap = (p1?.points ?? 0) - (p2?.points ?? 0)
        GlassPanel(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(series.rawValue)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(series.badgeColor, in: Capsule())
                    Spacer()
                    Image(systemName: "crown.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.yellow)
                }

                if let leader = p1 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(leader.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(leader.team)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    .blur(radius: masked ? 7 : 0)

                    HStack(alignment: .firstTextBaseline) {
                        Text("\(Int(leader.points))")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: leader.colorHex))
                        Text("PTS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.55))
                        Spacer()
                        if p2 != nil {
                            Text("領先 +\(Int(gap)) 分")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.green.opacity(0.16), in: Capsule())
                        }
                    }
                    .blur(radius: masked ? 7 : 0)
                } else {
                    Text("載入中...").foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(16)
        }
    }
}

// MARK: - TAB 2: Standings, Latest Results & Driver H2H Comparison (v2.0)
struct StandingsAndH2HView: View {
    @EnvironmentObject var store: MotorsportStore
    @State private var selectedSeries: RaceSeries = .f1
    @State private var subTab = 0 // 0=車手, 1=車隊, 2=最新成績, 3=H2H對比
    @State private var driverAIndex = 0
    @State private var driverBIndex = 1
    @State private var revealLatest = false

    var body: some View {
        let drivers = store.driverStandings[selectedSeries] ?? []
        let teams = store.teamStandings[selectedSeries] ?? []

        NavigationStack {
            ZStack {
                RacingBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("積分榜與對比")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)

                        // Series Selector
                        HStack(spacing: 8) {
                            ForEach(RaceSeries.allCases) { s in
                                let active = selectedSeries == s
                                Button {
                                    store.haptic()
                                    withAnimation(.spring(response: 0.25)) {
                                        selectedSeries = s
                                        driverAIndex = 0
                                        driverBIndex = min(1, max(0, (store.driverStandings[s]?.count ?? 1) - 1))
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: s.symbol).font(.system(size: 12))
                                        Text(s.rawValue).font(.system(size: 13.5, weight: .bold))
                                    }
                                    .foregroundStyle(active ? .white : .white.opacity(0.55))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(active ? s.badgeColor : Color.white.opacity(0.08), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Sub-mode Picker
                        Picker("", selection: $subTab) {
                            Text("車手榜").tag(0)
                            Text("車隊榜").tag(1)
                            Text("最新站").tag(2)
                            Text("H2H 對比").tag(3)
                        }
                        .pickerStyle(.segmented)

                        if subTab == 0 {
                            VStack(spacing: 10) {
                                ForEach(drivers) { d in
                                    GlassPanel(cornerRadius: 16) {
                                        HStack(spacing: 12) {
                                            Text("\(d.position)")
                                                .font(.system(size: 16, weight: .black, design: .rounded))
                                                .foregroundStyle(d.position <= 3 ? .yellow : .white.opacity(0.65))
                                                .frame(width: 26)
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color(hex: d.colorHex))
                                                .frame(width: 4, height: 32)
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 6) {
                                                    Text(d.name).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                                                    if !d.number.isEmpty {
                                                        Text("#\(d.number)").font(.caption2.bold()).foregroundStyle(.white.opacity(0.45))
                                                    }
                                                }
                                                Text(d.team).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.55))
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text("\(Int(d.points)) PTS")
                                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                                    .foregroundStyle(.white)
                                                if d.wins > 0 {
                                                    Text("\(d.wins) 勝").font(.caption2.bold()).foregroundStyle(.yellow)
                                                }
                                            }
                                        }
                                        .padding(13)
                                    }
                                }
                            }
                        } else if subTab == 1 {
                            if teams.isEmpty {
                                Text("此賽事暫無車隊榜數據").foregroundStyle(.white.opacity(0.55)).padding()
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(teams) { t in
                                        GlassPanel(cornerRadius: 16) {
                                            HStack(spacing: 12) {
                                                Text("\(t.position)").font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(t.position <= 3 ? .yellow : .white.opacity(0.65)).frame(width: 26)
                                                RoundedRectangle(cornerRadius: 2).fill(Color(hex: t.colorHex)).frame(width: 4, height: 28)
                                                Text(t.name).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                                                Spacer()
                                                Text("\(Int(t.points)) PTS").font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(.white)
                                            }
                                            .padding(14)
                                        }
                                    }
                                }
                            }
                        } else if subTab == 2 {
                            if let latest = store.latestResults[selectedSeries] {
                                let masked = store.spoilerFree && !revealLatest
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(latest.raceName).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                                            Text(latest.dateText).font(.caption).foregroundStyle(.white.opacity(0.55))
                                        }
                                        Spacer()
                                        if masked {
                                            Button("解鎖成績") {
                                                store.haptic()
                                                withAnimation { revealLatest = true }
                                            }
                                            .font(.caption.bold())
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(Color.yellow, in: Capsule())
                                        }
                                    }

                                    ForEach(latest.results) { row in
                                        GlassPanel(cornerRadius: 14) {
                                            HStack {
                                                Text("P\(row.position)")
                                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                                    .foregroundStyle(row.position <= 3 ? .yellow : .white.opacity(0.7))
                                                    .frame(width: 34, alignment: .leading)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(row.driverName).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                                    Text(row.teamName).font(.caption2).foregroundStyle(.white.opacity(0.55))
                                                }
                                                Spacer()
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text(row.timeOrStatus).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.85))
                                                    if row.points > 0 {
                                                        Text("+\(Int(row.points)) pts").font(.caption2.bold()).foregroundStyle(store.theme.accent)
                                                    }
                                                }
                                            }
                                            .padding(12)
                                            .blur(radius: masked ? 7 : 0)
                                        }
                                    }
                                }
                            } else {
                                GlassPanel(cornerRadius: 18) {
                                    Text("最新一站正賽成績暫時只支援 F1 即時拉取，請切換至 F1 或下拉更新。")
                                        .font(.system(size: 13.5))
                                        .foregroundStyle(.white.opacity(0.65))
                                        .padding(20)
                                }
                            }
                        } else {
                            // v2.0 Driver Head-to-Head Comparison
                            if drivers.count >= 2 {
                                let safeA = min(driverAIndex, drivers.count - 1)
                                let safeB = min(driverBIndex, drivers.count - 1)
                                DriverH2HCard(
                                    drivers: drivers,
                                    indexA: $driverAIndex,
                                    indexB: $driverBIndex,
                                    dA: drivers[safeA],
                                    dB: drivers[safeB]
                                )
                            } else {
                                Text("需要至少兩位車手數據進行對比").foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
                .refreshable {
                    store.haptic()
                    await store.refreshAll()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct DriverH2HCard: View {
    let drivers: [DriverStanding]
    @Binding var indexA: Int
    @Binding var indexB: Int
    let dA: DriverStanding
    let dB: DriverStanding

    var body: some View {
        let totalPts = max(1.0, dA.points + dB.points)
        let ratioA = dA.points / totalPts
        let diff = abs(dA.points - dB.points)
        let leader = dA.points >= dB.points ? dA : dB
        let racesNeeded = Int(ceil(diff / 25.0))

        return GlassPanel(cornerRadius: 24) {
            VStack(spacing: 18) {
                HStack {
                    Picker("車手 A", selection: $indexA) {
                        ForEach(0..<drivers.count, id: \.self) { i in
                            Text("P\(drivers[i].position) \(drivers[i].shortCode)").tag(i)
                        }
                    }
                    .tint(Color(hex: dA.colorHex))

                    Text("VS")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))

                    Picker("車手 B", selection: $indexB) {
                        ForEach(0..<drivers.count, id: \.self) { i in
                            Text("P\(drivers[i].position) \(drivers[i].shortCode)").tag(i)
                        }
                    }
                    .tint(Color(hex: dB.colorHex))
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dA.shortCode).font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(Color(hex: dA.colorHex))
                        Text(dA.name).font(.caption.bold()).foregroundStyle(.white).lineLimit(1)
                        Text(dA.team).font(.caption2).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(dB.shortCode).font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(Color(hex: dB.colorHex))
                        Text(dB.name).font(.caption.bold()).foregroundStyle(.white).lineLimit(1)
                        Text(dB.team).font(.caption2).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                    }
                }

                // Visual Points Share Bar
                VStack(spacing: 6) {
                    HStack {
                        Text("\(Int(dA.points)) PTS").font(.system(size: 15, weight: .black, design: .rounded))
                        Spacer()
                        Text("積分佔比").font(.caption2).foregroundStyle(.white.opacity(0.55))
                        Spacer()
                        Text("\(Int(dB.points)) PTS").font(.system(size: 15, weight: .black, design: .rounded))
                    }
                    GeometryReader { geo in
                        HStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: dA.colorHex))
                                .frame(width: max(12, geo.size.width * ratioA - 2))
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: dB.colorHex))
                                .frame(width: max(12, geo.size.width * (1 - ratioA) - 2))
                        }
                    }
                    .frame(height: 12)
                }

                Divider().overlay(.white.opacity(0.12))

                h2hRow(left: "P\(dA.position)", label: "目前排名", right: "P\(dB.position)")
                h2hRow(left: "\(dA.wins)", label: "分站冠軍", right: "\(dB.wins)")
                h2hRow(left: String(format: "%.0f%%", ratioA * 100), label: "分數比重", right: String(format: "%.0f%%", (1 - ratioA) * 100))

                // Championship Math Note
                HStack(spacing: 8) {
                    Image(systemName: "function")
                        .foregroundStyle(.yellow)
                    Text(diff == 0
                         ? "兩位車手目前同分！"
                         : "\(leader.shortCode) 領先 \(Int(diff)) 分；按每站最高 25 分計，落後一方最少需 \(racesNeeded) 站全勝（且對手零分）先可反超。")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(18)
        }
    }

    private func h2hRow(left: String, label: String, right: String) -> some View {
        HStack {
            Text(left).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white).frame(width: 70, alignment: .leading)
            Spacer()
            Text(label).font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
            Spacer()
            Text(right).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white).frame(width: 70, alignment: .trailing)
        }
    }
}

// MARK: - TAB 3: F1 Telemetry Lab (v2.0: Tire Strategy + Team Radio Player + Race Control)
struct F1TelemetryLabView: View {
    @EnvironmentObject var store: MotorsportStore
    @EnvironmentObject var radioPlayer: RadioAudioPlayer
    @State private var labSection = 0 // 0=換胎策略, 1=Team Radio, 2=賽事控制
    @State private var selectedRadioDriver = "ALL"

    var body: some View {
        NavigationStack {
            ZStack {
                RacingBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("F1 遙測實驗室")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(.white)
                                Text(store.openF1SessionName.isEmpty ? "OpenF1 即時數據連接中..." : store.openF1SessionName)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundStyle(store.theme.accent)
                            }
                            Spacer()
                            if store.isLoadingTelemetry {
                                ProgressView().tint(.white)
                            }
                        }

                        Picker("", selection: $labSection) {
                            Text("換胎策略").tag(0)
                            Text("Team Radio").tag(1)
                            Text("判罰 / 旗號").tag(2)
                        }
                        .pickerStyle(.segmented)

                        if labSection == 0 {
                            tireStrategySection
                        } else if labSection == 1 {
                            teamRadioSection
                        } else {
                            raceControlSection
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
                .refreshable {
                    store.haptic()
                    await store.fetchOpenF1Telemetry()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var tireStrategySection: some View {
        let maxLap = max(1, store.f1Strategies.map(\.totalLaps).max() ?? 50)
        return VStack(alignment: .leading, spacing: 12) {
            // Compound Legend
            HStack(spacing: 12) {
                legendDot(color: Color(red: 0.94, green: 0.20, blue: 0.22), text: "S 軟胎")
                legendDot(color: Color(red: 0.98, green: 0.82, blue: 0.16), text: "M 中胎")
                legendDot(color: Color(white: 0.92), text: "H 硬胎")
                legendDot(color: Color(red: 0.20, green: 0.80, blue: 0.36), text: "I 半雨")
                legendDot(color: Color(red: 0.16, green: 0.56, blue: 0.98), text: "W 全雨")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.75))

            if store.f1Strategies.isEmpty {
                GlassPanel(cornerRadius: 18) {
                    Text("暫未載入換胎策略數據，請下拉重新同步 OpenF1。")
                        .font(.system(size: 13.5)).foregroundStyle(.white.opacity(0.6)).padding(20)
                }
            } else {
                GlassPanel(cornerRadius: 22) {
                    VStack(spacing: 12) {
                        ForEach(store.f1Strategies) { drv in
                            HStack(spacing: 10) {
                                HStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: drv.teamColorHex))
                                        .frame(width: 3, height: 18)
                                    Text(drv.acronym)
                                        .font(.system(size: 12.5, weight: .black, design: .monospaced))
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 46, alignment: .leading)

                                GeometryReader { geo in
                                    HStack(spacing: 2.5) {
                                        ForEach(drv.stints) { st in
                                            let w = max(16, (CGFloat(st.lapCount) / CGFloat(maxLap)) * geo.size.width - 2.5)
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                    .fill(st.compoundColor)
                                                Text("\(st.shortLetter)\(st.lapCount)")
                                                    .font(.system(size: 9.5, weight: .black, design: .rounded))
                                                    .foregroundStyle(st.compound.uppercased() == "HARD" || st.compound.uppercased() == "MEDIUM" ? .black : .white)
                                                    .minimumScaleFactor(0.6)
                                                    .lineLimit(1)
                                            }
                                            .frame(width: w, height: 20)
                                        }
                                    }
                                }
                                .frame(height: 20)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }

    private var teamRadioSection: some View {
        let driverCodes = ["ALL"] + Array(Set(store.f1RadioClips.map(\.acronym))).sorted()
        let filtered = selectedRadioDriver == "ALL"
            ? store.f1RadioClips
            : store.f1RadioClips.filter { $0.acronym == selectedRadioDriver }

        return VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(driverCodes, id: \.self) { code in
                        let sel = selectedRadioDriver == code
                        Button {
                            store.haptic()
                            selectedRadioDriver = code
                        } label: {
                            Text(code == "ALL" ? "全部車手" : code)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(sel ? .black : .white.opacity(0.8))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(sel ? Color.white : Color.white.opacity(0.10), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if filtered.isEmpty {
                GlassPanel(cornerRadius: 18) {
                    Text("暫無 Team Radio 錄音，請下拉刷新。")
                        .font(.system(size: 13.5)).foregroundStyle(.white.opacity(0.6)).padding(20)
                }
            } else {
                ForEach(filtered) { clip in
                    let isPlayingThis = radioPlayer.currentURL == clip.recordingURL && radioPlayer.isPlaying
                    GlassPanel(cornerRadius: 18) {
                        HStack(spacing: 12) {
                            Button {
                                store.haptic()
                                radioPlayer.toggle(urlString: clip.recordingURL)
                            } label: {
                                Image(systemName: isPlayingThis ? "stop.fill" : "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 42, height: 42)
                                    .background(Color(hex: clip.teamColorHex), in: Circle())
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(clip.acronym)
                                        .font(.system(size: 14, weight: .black, design: .monospaced))
                                        .foregroundStyle(Color(hex: clip.teamColorHex))
                                    Text(clip.fullName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                }
                                Text("澳門時間 \(RaceDateFmt.fullMacau.string(from: clip.date)) · 點擊播放無線電")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            Spacer()
                            if isPlayingThis {
                                Image(systemName: "waveform")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(store.theme.accent)
                                    .symbolEffect(.variableColor.iterative)
                            }
                        }
                        .padding(14)
                    }
                }
            }
        }
    }

    private var raceControlSection: some View {
        VStack(spacing: 10) {
            if store.f1RaceControl.isEmpty {
                GlassPanel(cornerRadius: 18) {
                    Text("暫無賽事控制通報，請下拉刷新。")
                        .font(.system(size: 13.5)).foregroundStyle(.white.opacity(0.6)).padding(20)
                }
            } else {
                ForEach(store.f1RaceControl) { msg in
                    GlassPanel(cornerRadius: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(msg.flag.isEmpty ? msg.category : msg.flag)
                                    .font(.system(size: 10.5, weight: .black))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(msg.isCritical ? Color.red : Color.white.opacity(0.16), in: Capsule())
                                if let lap = msg.lapNumber {
                                    Text("LAP \(lap)")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                Spacer()
                                Text(RaceDateFmt.hmMacau.string(from: msg.date))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            Text(msg.message)
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .padding(14)
                    }
                }
            }
        }
    }
}

// MARK: - TAB 4: Multi-Series News Feed
struct NewsFeedView: View {
    @EnvironmentObject var store: MotorsportStore
    @State private var filterSeries: RaceSeries? = nil
    @State private var activeURL: IdentifiableURL?

    private var filteredNews: [NewsArticle] {
        store.articles.filter { art in
            let matchSeries = (filterSeries == nil || art.series == filterSeries)
            let matchBreak = (!store.onlyBreakingNews || art.isBreaking)
            return matchSeries && matchBreak
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RacingBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("重點新聞")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Button {
                                store.haptic()
                                store.onlyBreakingNews.toggle()
                            } label: {
                                Label(store.onlyBreakingNews ? "只看重點" : "全部新聞", systemImage: "flame.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(store.onlyBreakingNews ? .white : .white.opacity(0.75))
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(store.onlyBreakingNews ? Color.red : Color.white.opacity(0.10), in: Capsule())
                            }
                        }

                        // Series Filter Chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                filterChip(title: "全部", active: filterSeries == nil, color: store.theme.accent) { filterSeries = nil }
                                ForEach(RaceSeries.allCases) { s in
                                    filterChip(title: s.rawValue, active: filterSeries == s, color: s.badgeColor) { filterSeries = s }
                                }
                            }
                        }

                        if filteredNews.isEmpty {
                            GlassPanel(cornerRadius: 18) {
                                Text("暫無符合條件的新聞，請下拉更新或關閉「只看重點」。")
                                    .font(.system(size: 13.5)).foregroundStyle(.white.opacity(0.6)).padding(20)
                            }
                        } else {
                            ForEach(filteredNews) { art in
                                Button {
                                    store.haptic()
                                    if let u = URL(string: art.link) { activeURL = IdentifiableURL(url: u) }
                                } label: {
                                    GlassPanel(cornerRadius: 18) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack(spacing: 6) {
                                                Text(art.series.rawValue)
                                                    .font(.system(size: 10, weight: .black))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                                    .background(art.series.badgeColor, in: Capsule())

                                                if let alert = art.alertTag {
                                                    Text(alert)
                                                        .font(.system(size: 10, weight: .black))
                                                        .foregroundStyle(.white)
                                                        .padding(.horizontal, 7).padding(.vertical, 3)
                                                        .background(Color.red, in: Capsule())
                                                }
                                                Spacer()
                                                Text(RaceDateFmt.relativeText(art.pubDate))
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.white.opacity(0.48))
                                            }

                                            Text(art.title)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .multilineTextAlignment(.leading)
                                                .blur(radius: store.spoilerFree ? 6 : 0)

                                            Text(art.source)
                                                .font(.system(size: 11))
                                                .foregroundStyle(.white.opacity(0.45))
                                        }
                                        .padding(15)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
                .refreshable {
                    store.haptic()
                    await store.refreshAll()
                }
                .sheet(item: $activeURL) { item in
                    SafariSheetView(url: item.url).ignoresSafeArea()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func filterChip(title: String, active: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            store.haptic()
            action()
        } label: {
            Text(title)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(active ? .white : .white.opacity(0.65))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(active ? color : Color.white.opacity(0.09), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - TAB 5: Settings
struct AppSettingsView: View {
    @EnvironmentObject var store: MotorsportStore
    @State private var syncedToast = false

    var body: some View {
        NavigationStack {
            ZStack {
                RacingBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("設定")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)

                        GlassPanel(cornerRadius: 22) {
                            VStack(spacing: 14) {
                                HStack {
                                    Text("本命車隊主題色").font(.system(size: 14.5, weight: .medium))
                                    Spacer()
                                    Picker("", selection: $store.theme) {
                                        ForEach(TeamTheme.allCases) { th in
                                            Text(th.displayName).tag(th)
                                        }
                                    }
                                    .tint(store.theme.accent)
                                }

                                Divider().overlay(.white.opacity(0.10))

                                Toggle("防劇透模式（模糊最新成績與新聞）", isOn: $store.spoilerFree)
                                    .font(.system(size: 14, weight: .medium))
                                    .tint(store.theme.accent)

                                Divider().overlay(.white.opacity(0.10))

                                Toggle("觸覺震動回饋", isOn: $store.enableHaptics)
                                    .font(.system(size: 14, weight: .medium))
                                    .tint(store.theme.accent)
                            }
                            .padding(18)
                        }

                        GlassPanel(cornerRadius: 22) {
                            VStack(spacing: 14) {
                                Button {
                                    store.haptic()
                                    Task {
                                        await store.refreshAll()
                                        withAnimation { syncedToast = true }
                                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                                        withAnimation { syncedToast = false }
                                    }
                                } label: {
                                    HStack {
                                        Label("立即重新同步所有賽事與小工具", systemImage: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 14.5, weight: .semibold))
                                            .foregroundStyle(store.theme.accent)
                                        Spacer()
                                        if let dt = store.lastUpdated {
                                            Text(RaceDateFmt.hmMacau.string(from: dt))
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                    }
                                }

                                Divider().overlay(.white.opacity(0.10))

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("免費數據源狀態").font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.8))
                                    Text("• F1 積分與賽程：Jolpica-F1 Public API\n• F1 換胎 / Team Radio / 判罰：OpenF1 API\n• MotoGP：PulseLive Public API\n• 新聞：Motorsport.com & TouringCarTimes RSS")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(18)
                        }

                        if syncedToast {
                            Text("已同步最新數據並刷新桌面小工具")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        Text("ApexGrid 2.0 · Macau Time (CST) Edition")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.38))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
