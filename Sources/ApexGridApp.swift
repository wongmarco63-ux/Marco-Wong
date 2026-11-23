import SwiftUI
import SafariServices
import PhotosUI
import UIKit
#if canImport(Translation)
import Translation
#endif

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

// MARK: - Apple Native On-Device Translation Bridge (iOS 18+)
#if canImport(Translation)
@available(iOS 18.0, *)
struct NativeTranslationBridge: View {
    @EnvironmentObject var store: MotorsportStore
    @State private var config: TranslationSession.Configuration?

    var body: some View {
        let storeRef = store
        Color.clear
            .frame(width: 0, height: 0)
            .translationTask(config) { session in
                let batch = await MainActor.run { storeRef.pendingNativeTexts }
                guard !batch.isEmpty else { return }
                let reqs = batch.map { TranslationSession.Request(sourceText: $0) }
                if let responses = try? await session.translations(from: reqs) {
                    var map: [String: String] = [:]
                    for (orig, res) in zip(batch, responses) {
                        map[orig] = res.targetText
                    }
                    await MainActor.run { storeRef.applyNativeTranslations(map) }
                } else {
                    await MainActor.run { storeRef.isTranslating = false }
                }
            }
            .onChange(of: store.nativeTranslateTriggerID) { _, _ in
                if config == nil {
                    config = TranslationSession.Configuration(
                        source: Locale.Language(identifier: "en"),
                        target: Locale.Language(identifier: "zh-Hant")
                    )
                } else {
                    config?.invalidate()
                }
            }
    }
}
#endif

// MARK: - Design System (Cosmic + Native Liquid Glass)
struct RaceGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            if interactive {
                content.glassEffect(.regular.interactive(), in: shape)
            } else {
                content.glassEffect(.regular, in: shape)
            }
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
    @ObservedObject private var wallRepo = WallpaperRepository.shared
    var showSubtleGrid: Bool = false

    var body: some View {
        ZStack {
            if let img = wallRepo.customWallpaper {
                GeometryReader { geo in
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: store.wallpaperBlur)
                        .scaleEffect(1.06)
                }
                Color.black.opacity(store.wallpaperDim)
            } else {
                LinearGradient(colors: store.theme.bgColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [store.theme.accent.opacity(0.26), .clear], center: .top, startRadius: 20, endRadius: 430)
            }

            if showSubtleGrid && wallRepo.customWallpaper == nil {
                Canvas { context, size in
                    let step: CGFloat = 24
                    var path = Path()
                    var x: CGFloat = 0
                    var y: CGFloat = 0
                    while x < size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += step
                    }
                    while y < size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += step
                    }
                    context.stroke(path, with: .color(.white.opacity(0.025)), lineWidth: 0.5)
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct GlassPanel<Content: View>: View {
    var cornerRadius: CGFloat = 24
    var highlightOpacity: Double = 0.24
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.11), Color.white.opacity(0.04), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.56))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color.white.opacity(highlightOpacity), Color.white.opacity(0.06), Color.white.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.32), radius: 16, x: 0, y: 8)
    }
}

struct ConstellationRingView: View {
    let animate: Bool
    let tintColor: Color
    private let particleCount = 240

    var body: some View {
        if animate {
            TimelineView(.animation) { timeline in
                ringCanvas(t: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            ringCanvas(t: 14.0)
        }
    }

    private func ringCanvas(t: Double) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let baseRadius = min(size.width, size.height) * 0.37
            for i in 0..<particleCount {
                let s1 = pseudoRandom(i * 3 + 1)
                let s2 = pseudoRandom(i * 3 + 2)
                let s3 = pseudoRandom(i * 3 + 3)
                let spread = (s1 + s2 - 1.0) * (baseRadius * 0.42)
                let angle = s1 * .pi * 2 + t * (0.04 + s3 * 0.08) * (i % 2 == 0 ? 1 : -1)
                let r = baseRadius + spread + sin(t * (0.6 + s2) + Double(i)) * 4.0
                let twinkle = 0.24 + 0.76 * abs(sin(t * (0.9 + s3 * 1.4) + Double(i) * 0.7))
                let dotR = (s3 > 0.86) ? 2.4 : (s3 > 0.55 ? 1.5 : 0.95)
                let rect = CGRect(x: center.x + cos(angle) * r - dotR, y: center.y + sin(angle) * r - dotR, width: dotR * 2, height: dotR * 2)
                context.fill(Path(ellipseIn: rect), with: .color(((i % 4 == 0) ? tintColor : .white).opacity(twinkle * 0.88)))
            }
        }
    }

    private func pseudoRandom(_ seed: Int) -> Double {
        let x = sin(Double(seed) * 12.9898) * 43758.5453
        return x - floor(x)
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

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Root Container
struct MainTabRootView: View {
    @EnvironmentObject var store: MotorsportStore
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                SeriesHubView()
                    .tabItem { Label("賽事", systemImage: "flag.checkered") }
                    .tag(0)
                TelemetryWeekendView()
                    .tabItem { Label("遙測", systemImage: "waveform.path.ecg") }
                    .tag(1)
                SeasonStatsView()
                    .tabItem { Label("統計", systemImage: "chart.bar.fill") }
                    .tag(2)
                NewsRoomView()
                    .tabItem { Label("新聞", systemImage: "newspaper.fill") }
                    .tag(3)
                AppSettingsView()
                    .tabItem { Label("設定", systemImage: "gearshape.fill") }
                    .tag(4)
            }
            .tint(store.theme.accent)

            #if canImport(Translation)
            if #available(iOS 18.0, *) {
                NativeTranslationBridge()
            }
            #endif
        }
    }
}

// MARK: - TAB 1: Series Hub
struct SeriesHubView: View {
    @EnvironmentObject var store: MotorsportStore
    @State private var activeSeries: RaceSeries? = .f1
    @State private var navPath = NavigationPath()
    @State private var showBriefing = false
    @State private var reminderToast: String?
    @State private var revealOnce = false
    @State private var pulse = false

    private var isMasked: Bool { store.spoilerFree && !revealOnce }

    var body: some View {
        let nextEv = store.nextGlobalEvent()

        NavigationStack(path: $navPath) {
            ZStack {
                RacingBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        HStack {
                            Button {
                                store.haptic()
                                showBriefing = true
                                Task { await store.generateAIBriefing() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                    Text("AI 速報")
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 11).padding(.vertical, 6)
                                .raceGlass(in: Capsule(), interactive: true)
                            }

                            Spacer()
                            Text("賽事").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                            Spacer()

                            Button {
                                store.haptic()
                                withAnimation { store.spoilerFree.toggle(); revealOnce = false }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: store.spoilerFree ? "eye.slash.fill" : "eye.fill")
                                    Text(store.spoilerFree ? "防劇透" : "即時")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(store.spoilerFree ? .yellow : .white.opacity(0.92))
                                .padding(.horizontal, 11).padding(.vertical, 6)
                                .raceGlass(in: Capsule(), interactive: true)
                            }
                        }
                        .padding(.horizontal, 20).padding(.top, 10)

                        HStack(spacing: 8) {
                            Circle()
                                .fill(store.isLoading ? Color.yellow : Color.green)
                                .frame(width: 8, height: 8)
                                .scaleEffect(pulse ? 1.3 : 0.85)
                                .opacity(pulse ? 1.0 : 0.6)
                                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
                                .onAppear { pulse = true }

                            Text(store.isTranslating ? "AI 翻譯中..." : "即時數據已連線 · 澳門時間")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))

                            if store.autoTranslateEnabled {
                                Text("AI 繁中").font(.system(size: 10, weight: .black)).foregroundStyle(store.theme.accent)
                            }
                        }
                        .padding(.horizontal, 13).padding(.vertical, 6)
                        .raceGlass(in: Capsule(), interactive: false)
                        .padding(.top, 10)

                        TimelineView(.periodic(from: .now, by: 60)) { _ in
                            ZStack {
                                ConstellationRingView(animate: store.enableParticles, tintColor: store.theme.accent)
                                    .frame(width: 274, height: 248)

                                if let ev = nextEv {
                                    let cd = RaceDateFmt.countdownParts(to: ev.raceDate)
                                    VStack(spacing: 5) {
                                        Text(ev.series.rawValue)
                                            .font(.system(size: 11, weight: .black, design: .rounded))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8).padding(.vertical, 2)
                                            .background(ev.series.badgeColor, in: Capsule())

                                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                                            if cd.days > 0 {
                                                Text("\(cd.days)").font(.system(size: 38, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                                Text("日").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.65)).padding(.trailing, 4)
                                            }
                                            Text("\(cd.hours)").font(.system(size: 38, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                            Text("時").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.65))
                                        }
                                        .monospacedDigit()

                                        Text("· \(store.displayTranslated(ev.name)) ·")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.75))
                                            .lineLimit(1).frame(maxWidth: 210)

                                        Text(RaceDateFmt.fullMacau.string(from: ev.raceDate))
                                            .font(.system(size: 10.5, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                } else {
                                    VStack(spacing: 6) {
                                        Text("APEXGRID").font(.system(size: 24, weight: .black, design: .rounded)).foregroundStyle(.white)
                                        Text("· 下拉同步最新賽事 ·").font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.55))
                                    }
                                }
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(RaceSeries.allCases) { series in
                                    SeriesHeroCard(series: series, masked: isMasked)
                                        .containerRelativeFrame(.horizontal) { length, _ in min(length - 80, 310) }
                                        .id(series)
                                        .onTapGesture { store.haptic(); navPath.append(series) }
                                        .contextMenu {
                                            Button { navPath.append(series) } label: { Label("查看完整積分榜與賽程", systemImage: "list.number") }
                                            if let ev = store.nextEvent(for: series) {
                                                Button {
                                                    Task {
                                                        let ok = await store.scheduleReminder(for: ev)
                                                        showToast(ok ? "已預約 \(store.displayTranslated(ev.name)) 開賽前 15 分鐘提醒" : "無法排程提醒（請檢查通知權限）")
                                                    }
                                                } label: { Label("預約下一場開賽提醒", systemImage: "bell.badge.fill") }
                                            }
                                        }
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .contentMargins(.horizontal, 40, for: .scrollContent)
                        .scrollTargetBehavior(.viewAligned)
                        .scrollPosition(id: $activeSeries)
                        .frame(height: 274)

                        HStack(spacing: 7) {
                            ForEach(RaceSeries.allCases) { s in
                                let isCurrent = (activeSeries ?? .f1) == s
                                Circle().fill(Color.white.opacity(isCurrent ? 0.94 : 0.25))
                                    .frame(width: isCurrent ? 7 : 5.5, height: isCurrent ? 7 : 5.5)
                            }
                        }
                        .padding(.top, 14)

                        Text("輕點卡片進入完整積分與賽程 · 長按預約提醒 · 下拉刷新")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.48)).padding(.top, 8)

                        let breaking = Array(store.articles.filter(\.isBreaking).prefix(3))
                        if !breaking.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label("重點突發快訊（AI 繁中）", systemImage: "bolt.fill")
                                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.9))
                                    Spacer()
                                    if isMasked {
                                        Button("暫時解鎖") { withAnimation { revealOnce = true } }
                                            .font(.caption.bold()).foregroundStyle(.yellow)
                                    }
                                }
                                ForEach(breaking) { art in
                                    GlassPanel(cornerRadius: 18, highlightOpacity: 0.18) {
                                        HStack(alignment: .top, spacing: 10) {
                                            Text(art.alertTag ?? "焦點")
                                                .font(.system(size: 10, weight: .black)).foregroundStyle(.white)
                                                .padding(.horizontal, 8).padding(.vertical, 4).background(Color.red, in: Capsule())
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(store.displayTranslated(art.title))
                                                    .font(.system(size: 13.5, weight: .semibold)).foregroundStyle(.white)
                                                    .blur(radius: isMasked ? 6 : 0)
                                                Text("\(art.series.rawValue) · \(RaceDateFmt.relativeText(art.pubDate))")
                                                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                                            }
                                            Spacer()
                                        }
                                        .padding(14)
                                    }
                                }
                            }
                            .padding(.horizontal, 20).padding(.top, 20)
                        }
                    }
                    .padding(.bottom, 30)
                }
                .refreshable { store.haptic(); await store.refreshAll() }

                if let toast = reminderToast {
                    VStack {
                        Spacer()
                        Text(toast).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .raceGlass(in: Capsule(), interactive: false).padding(.bottom, 24)
                    }
                    .transition(.opacity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: RaceSeries.self) { series in SeriesDetailView(series: series) }
            .sheet(isPresented: $showBriefing) { AIBriefingSheet() }
        }
    }

    private func showToast(_ msg: String) {
        withAnimation { reminderToast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { withAnimation { reminderToast = nil } }
    }
}

struct SeriesHeroCard: View {
    @EnvironmentObject var store: MotorsportStore
    let series: RaceSeries
    let masked: Bool

    var body: some View {
        let drivers = store.driverStandings[series] ?? []
        let p1 = drivers.first
        let p2 = drivers.count > 1 ? drivers[1] : nil
        let gap = (p1?.points ?? 0) - (p2?.points ?? 0)
        let nextEv = store.nextEvent(for: series)

        GlassPanel(cornerRadius: 28, highlightOpacity: 0.28) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: series.symbol).font(.system(size: 12, weight: .bold))
                        Text(series.rawValue).font(.system(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 5)
                    .background(series.badgeColor, in: Capsule())

                    Spacer()

                    if p1 != nil && p2 != nil {
                        Text("領先 +\(Int(gap)) 分")
                            .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.green)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(Color.green.opacity(0.16), in: Capsule())
                            .blur(radius: masked ? 5 : 0)
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [series.badgeColor.opacity(0.35), .clear], center: .center, startRadius: 4, endRadius: 44))
                            .frame(width: 78, height: 78)
                        Image(systemName: series.symbol).font(.system(size: 34, weight: .semibold)).foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Label("目前領先 P1", systemImage: "crown.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.yellow)
                        Text(p1?.name ?? "載入中...").font(.system(size: 19, weight: .bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
                        Text(p1?.team ?? series.fullTitle).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                    }
                    .blur(radius: masked ? 7 : 0)
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 8)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(p1?.points ?? 0))").font(.system(size: 36, weight: .black, design: .rounded)).foregroundStyle(.white).monospacedDigit()
                        Text("PTS").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        if let wins = p1?.wins, wins > 0 {
                            Text("\(wins) 場分站冠軍").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(.yellow.opacity(0.9))
                        }
                    }
                    .blur(radius: masked ? 7 : 0)

                    if let ev = nextEv {
                        Text("下站：\(store.displayTranslated(ev.name)) · \(RaceDateFmt.md.string(from: ev.raceDate))")
                            .font(.system(size: 11.5, weight: .medium)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Series Detail View
struct SeriesDetailView: View {
    @EnvironmentObject var store: MotorsportStore
    @Environment(\.dismiss) var dismiss
    let series: RaceSeries

    @State private var subTab = 0
    @State private var selectedBarIdx: Int?
    @State private var revealLatest = false

    var body: some View {
        let drivers = store.driverStandings[series] ?? []
        let teams = store.teamStandings[series] ?? []
        let events = store.schedules[series] ?? []
        let p1 = drivers.first
        let p2 = drivers.count > 1 ? drivers[1] : nil
        let top10 = Array(drivers.prefix(10))

        ZStack {
            RacingBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                                .frame(width: 40, height: 40).raceGlass(in: Circle(), interactive: true)
                        }
                        Spacer()
                        Text(series.rawValue).font(.system(size: 13, weight: .black, design: .rounded)).foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6).background(series.badgeColor, in: Capsule())
                    }

                    Text(series.fullTitle).font(.system(size: 28, weight: .bold)).foregroundStyle(.white)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        RaceMetricTile(title: "目前榜首", bigValue: p1?.shortCode ?? "--", sub: p1?.name ?? "-")
                        RaceMetricTile(title: "領先分差", bigValue: p2 != nil ? "+\(Int((p1?.points ?? 0) - (p2?.points ?? 0)))" : "--", sub: "對第 2 名積分優勢")
                        RaceMetricTile(title: "參賽車手", bigValue: "\(drivers.count)", sub: "名積分榜車手")
                        RaceMetricTile(title: "賽季分站", bigValue: "\(events.count)", sub: "場全年大賽")
                    }

                    if !top10.isEmpty {
                        GlassPanel(cornerRadius: 22) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("前 10 名積分分佈").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(.white)
                                        Text("輕點柱形查看車手分數").font(.system(size: 11)).foregroundStyle(.white.opacity(0.48))
                                    }
                                    Spacer()
                                    if let idx = selectedBarIdx, idx < top10.count {
                                        let d = top10[idx]
                                        Text("\(d.shortCode) · \(Int(d.points)) PTS")
                                            .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Color(hex: d.colorHex))
                                            .padding(.horizontal, 10).padding(.vertical, 5).background(.white.opacity(0.10), in: Capsule())
                                    }
                                }
                                let maxPts = max(1.0, top10.map(\.points).max() ?? 1.0)
                                HStack(alignment: .bottom, spacing: 6) {
                                    ForEach(Array(top10.enumerated()), id: \.offset) { idx, d in
                                        let picked = selectedBarIdx == idx
                                        VStack(spacing: 5) {
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .fill(picked ? Color(hex: d.colorHex) : Color(hex: d.colorHex).opacity(0.65))
                                                .frame(maxWidth: .infinity).frame(height: max(8, CGFloat(d.points / maxPts) * 98))
                                            Text(d.shortCode).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(picked ? 1.0 : 0.55))
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture { store.haptic(); withAnimation(.easeOut(duration: 0.16)) { selectedBarIdx = (selectedBarIdx == idx) ? nil : idx } }
                                    }
                                }
                                .frame(height: 118, alignment: .bottom)
                            }
                            .padding(18)
                        }
                    }

                    Picker("", selection: $subTab) {
                        Text("車手榜").tag(0); Text("車隊榜").tag(1); Text("最新站").tag(2); Text("賽程").tag(3)
                    }
                    .pickerStyle(.segmented)

                    if subTab == 0 {
                        ForEach(drivers) { d in
                            GlassPanel(cornerRadius: 16, highlightOpacity: 0.16) {
                                HStack(spacing: 12) {
                                    Text("\(d.position)").font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(d.position <= 3 ? .yellow : .white.opacity(0.6)).frame(width: 26)
                                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: d.colorHex)).frame(width: 4, height: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(d.name).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                                        Text(d.team).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.55))
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(Int(d.points)) PTS").font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(.white)
                                        if d.wins > 0 { Text("\(d.wins) 勝").font(.caption2.bold()).foregroundStyle(.yellow) }
                                    }
                                }
                                .padding(13)
                            }
                        }
                    } else if subTab == 1 {
                        ForEach(teams) { t in
                            GlassPanel(cornerRadius: 16, highlightOpacity: 0.16) {
                                HStack(spacing: 12) {
                                    Text("\(t.position)").font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(t.position <= 3 ? .yellow : .white.opacity(0.6)).frame(width: 26)
                                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: t.colorHex)).frame(width: 4, height: 28)
                                    Text(t.name).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                                    Spacer()
                                    Text("\(Int(t.points)) PTS").font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(.white)
                                }
                                .padding(14)
                            }
                        }
                    } else if subTab == 2 {
                        if let latest = store.latestResults[series] {
                            let masked = store.spoilerFree && !revealLatest
                            HStack {
                                Text(store.displayTranslated(latest.raceName)).font(.headline).foregroundStyle(.white)
                                Spacer()
                                if masked {
                                    Button("解鎖成績") { withAnimation { revealLatest = true } }
                                        .font(.caption.bold()).foregroundStyle(.black).padding(.horizontal, 10).padding(.vertical, 5).background(Color.yellow, in: Capsule())
                                }
                            }
                            ForEach(latest.results) { row in
                                GlassPanel(cornerRadius: 14, highlightOpacity: 0.14) {
                                    HStack {
                                        Text("P\(row.position)").font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(row.position <= 3 ? .yellow : .white.opacity(0.7)).frame(width: 34, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(row.driverName).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                            Text(row.teamName).font(.caption2).foregroundStyle(.white.opacity(0.55))
                                        }
                                        Spacer()
                                        Text(store.displayTranslated(row.timeOrStatus)).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.85))
                                    }
                                    .padding(12).blur(radius: masked ? 7 : 0)
                                }
                            }
                        } else {
                            GlassPanel(cornerRadius: 16) {
                                Text("最新正賽詳細名次暫支援 F1 即時拉取。").font(.subheadline).foregroundStyle(.white.opacity(0.6)).padding(18)
                            }
                        }
                    } else {
                        ForEach(events) { ev in
                            let isPast = ev.raceDate < Date()
                            GlassPanel(cornerRadius: 16, highlightOpacity: 0.15) {
                                HStack {
                                    Text("R\(ev.round)").font(.system(size: 13, weight: .black, design: .rounded)).foregroundStyle(isPast ? .white.opacity(0.35) : series.badgeColor).frame(width: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(store.displayTranslated(ev.name)).font(.system(size: 14.5, weight: .bold)).foregroundStyle(isPast ? .white.opacity(0.55) : .white)
                                        Text("\(ev.circuit) · 澳門 \(RaceDateFmt.fullMacau.string(from: ev.raceDate))").font(.caption).foregroundStyle(.white.opacity(0.5))
                                    }
                                    Spacer()
                                    if isPast { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green.opacity(0.6)) }
                                }
                                .padding(13)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct RaceMetricTile: View {
    let title: String
    let bigValue: String
    let sub: String

    var body: some View {
        GlassPanel(cornerRadius: 20, highlightOpacity: 0.18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.58))
                Text(bigValue).font(.system(size: 26, weight: .black, design: .rounded)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.75)
                Text(sub).font(.system(size: 11)).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }
}
