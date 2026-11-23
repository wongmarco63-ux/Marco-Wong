import SwiftUI
import PhotosUI
import UIKit

// MARK: - TAB 2: F1 Telemetry & Race Weekend
struct TelemetryWeekendView: View {
    @EnvironmentObject var store: MotorsportStore
    @EnvironmentObject var radioPlayer: RadioAudioPlayer
    @State private var labTab = 0
    @State private var selectedRadioDriver = "ALL"

    var body: some View {
        let prog = store.f1SeasonProgress()
        let ratio = Double(prog.completed) / Double(max(1, prog.total))

        NavigationStack {
            ZStack {
                RacingBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("遙測實驗室")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(.white)
                                Text(store.openF1SessionName.isEmpty ? "OpenF1 數據同步中..." : store.openF1SessionName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(store.theme.accent)
                            }
                            Spacer()
                            if store.isLoadingTelemetry {
                                ProgressView().tint(.white)
                            }
                        }

                        GlassPanel(cornerRadius: 26, highlightOpacity: 0.25) {
                            HStack(spacing: 18) {
                                ZStack {
                                    Circle().stroke(Color.white.opacity(0.10), lineWidth: 11)
                                    Circle()
                                        .trim(from: 0, to: ratio)
                                        .stroke(
                                            LinearGradient(colors: [store.theme.accent, store.theme.accent.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                            style: StrokeStyle(lineWidth: 11, lineCap: .round)
                                        )
                                        .rotationEffect(.degrees(-90))
                                    VStack(spacing: 1) {
                                        Text("\(Int(round(ratio * 100)))%")
                                            .font(.system(size: 19, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                        Text("賽季進度")
                                            .font(.system(size: 9.5))
                                            .foregroundStyle(.white.opacity(0.55))
                                    }
                                }
                                .frame(width: 92, height: 92)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("F1 全季完成 \(prog.completed) / \(prog.total) 站")
                                        .font(.system(size: 13.5, weight: .bold))
                                        .foregroundStyle(.white)
                                    if let w = store.f1Weather {
                                        HStack(spacing: 10) {
                                            Label("賽道 \(Int(w.trackTemp))°C", systemImage: "road.lanes")
                                            Label("氣溫 \(Int(w.airTemp))°C", systemImage: "thermometer.medium")
                                        }
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.82))
                                        Text("\(w.isRaining ? "🌧️ 賽道濕地有雨" : "☀️ 乾地賽道") · 濕度 \(Int(w.humidity))% · 最快圈 \(store.f1FastestLapText)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white.opacity(0.55))
                                            .lineLimit(2)
                                    } else {
                                        Text("最快單圈：\(store.f1FastestLapText)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white.opacity(0.65))
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(18)
                        }

                        Picker("", selection: $labTab) {
                            Text("換胎策略").tag(0)
                            Text("尾速 / 進站").tag(1)
                            Text("Radio").tag(2)
                            Text("判罰翻譯").tag(3)
                        }
                        .pickerStyle(.segmented)

                        if labTab == 0 {
                            tireStrategyView
                        } else if labTab == 1 {
                            speedAndPitView
                        } else if labTab == 2 {
                            teamRadioView
                        } else {
                            raceControlView
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
                .refreshable {
                    store.haptic()
                    await store.fetchOpenF1Telemetry()
                    await store.translateLoadedContent()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var tireStrategyView: some View {
        let maxLap = max(1, store.f1Strategies.map(\.totalLaps).max() ?? 50)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                legendDot(color: Color(red: 0.94, green: 0.20, blue: 0.22), text: "S 軟胎")
                legendDot(color: Color(red: 0.98, green: 0.82, blue: 0.16), text: "M 中胎")
                legendDot(color: Color(white: 0.92), text: "H 硬胎")
                legendDot(color: Color(red: 0.20, green: 0.80, blue: 0.36), text: "I 半雨")
                legendDot(color: Color(red: 0.16, green: 0.56, blue: 0.98), text: "W 全雨")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.75))

            GlassPanel(cornerRadius: 22) {
                VStack(spacing: 11) {
                    if store.f1Strategies.isEmpty {
                        Text("下拉刷新載入最新一場換胎策略")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
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
                                                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(st.compoundColor)
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
                }
                .padding(16)
            }
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }

    private var speedAndPitView: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassPanel(cornerRadius: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("測速點極速排行榜 (Speed Trap)", systemImage: "gauge.with.needle.fill")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.white)
                    if store.f1TopSpeeds.isEmpty {
                        Text("下拉刷新以載入 OpenF1 測速數據")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        let maxS = Double(store.f1TopSpeeds.first?.maxSpeedKmh ?? 340)
                        ForEach(Array(store.f1TopSpeeds.prefix(10).enumerated()), id: \.offset) { idx, row in
                            HStack(spacing: 10) {
                                Text("\(idx + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(idx == 0 ? .yellow : .white.opacity(0.5))
                                    .frame(width: 18)
                                Text(row.acronym)
                                    .font(.system(size: 12.5, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, alignment: .leading)
                                GeometryReader { geo in
                                    Capsule()
                                        .fill(LinearGradient(colors: [Color(hex: row.teamColorHex), Color(hex: row.teamColorHex).opacity(0.45)], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: max(20, geo.size.width * CGFloat(Double(row.maxSpeedKmh) / maxS)), height: 10)
                                        .frame(maxHeight: .infinity, alignment: .center)
                                }
                                .frame(height: 16)
                                Text("\(row.maxSpeedKmh) km/h")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                .padding(18)
            }

            GlassPanel(cornerRadius: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("最快進站排行榜 (Pit Lane)", systemImage: "wrench.and.screwdriver.fill")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.white)
                    if store.f1FastestPits.isEmpty {
                        Text("暫無進站時間記錄")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        ForEach(Array(store.f1FastestPits.enumerated()), id: \.offset) { idx, pit in
                            HStack {
                                Text("P\(idx + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(idx == 0 ? .yellow : .white.opacity(0.55))
                                    .frame(width: 26, alignment: .leading)
                                Circle().fill(Color(hex: pit.teamColorHex)).frame(width: 8, height: 8)
                                Text(pit.acronym)
                                    .font(.system(size: 13.5, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                Text("第 \(pit.lapNumber) 圈")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                                Spacer()
                                Text(String(format: "%.2f s", pit.durationSec))
                                    .font(.system(size: 14, weight: .black, design: .monospaced))
                                    .foregroundStyle(idx == 0 ? .green : .white)
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
    }

    private var teamRadioView: some View {
        let codes = ["ALL"] + Array(Set(store.f1RadioClips.map(\.acronym))).sorted()
        let filtered = selectedRadioDriver == "ALL"
            ? store.f1RadioClips
            : store.f1RadioClips.filter { $0.acronym == selectedRadioDriver }

        return VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(codes, id: \.self) { code in
                        let sel = selectedRadioDriver == code
                        Button {
                            store.haptic()
                            selectedRadioDriver = code
                        } label: {
                            Text(code == "ALL" ? "全部車手" : code)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(sel ? .black : .white.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(sel ? Color.white : Color.white.opacity(0.10), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            ForEach(filtered) { clip in
                let isPlaying = radioPlayer.currentURL == clip.recordingURL && radioPlayer.isPlaying
                GlassPanel(cornerRadius: 18) {
                    HStack(spacing: 12) {
                        Button {
                            store.haptic()
                            radioPlayer.toggle(urlString: clip.recordingURL)
                        } label: {
                            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                                .font(.system(size: 15, weight: .bold))
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
                            Text("澳門 \(RaceDateFmt.fullMacau.string(from: clip.date)) · 點擊播放無線電")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer()
                        if isPlaying {
                            Image(systemName: "waveform")
                                .font(.system(size: 18))
                                .foregroundStyle(store.theme.accent)
                                .symbolEffect(.variableColor.iterative)
                        }
                    }
                    .padding(14)
                }
            }
        }
    }

    private var raceControlView: some View {
        VStack(spacing: 10) {
            ForEach(store.f1RaceControl) { msg in
                GlassPanel(cornerRadius: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(msg.flag.isEmpty ? msg.category : msg.flag)
                                .font(.system(size: 10.5, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
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
                        Text(store.displayTranslated(msg.message))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        if store.showOriginalEnglish && store.hasTranslation(for: msg.message) {
                            Text(msg.message)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    .padding(14)
                }
            }
        }
    }
}

// MARK: - TAB 3: Season Stats, Calendar Heatmap, H2H & HD Poster
struct SeasonStatsView: View {
    @EnvironmentObject var store: MotorsportStore
    @State private var selectedSeries: RaceSeries = .f1
    @State private var driverAIndex = 0
    @State private var driverBIndex = 1
    @State private var showPosterSheet = false

    var body: some View {
        let drivers = store.driverStandings[selectedSeries] ?? []
        let f1Top = store.driverStandings[.f1]?.first
        let maxWinsDriver = drivers.max { $0.wins < $1.wins }

        NavigationStack {
            ZStack {
                RacingBackgroundView(showSubtleGrid: true)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("統計")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Button {
                                store.haptic()
                                showPosterSheet = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .raceGlass(in: Circle(), interactive: true)
                            }
                        }

                        Text("賽季紀錄看板")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            RaceRecordTile(icon: "crown.fill", title: "F1 積分王", value: "\(Int(f1Top?.points ?? 0))", unit: "PTS", sub: f1Top?.name ?? "-")
                            RaceRecordTile(icon: "trophy.fill", title: "最多分站冠軍", value: "\(maxWinsDriver?.wins ?? 0)", unit: "勝", sub: maxWinsDriver?.name ?? "-")
                            RaceRecordTile(icon: "gauge.with.needle.fill", title: "全場極速王", value: store.f1TopSpeeds.first.map { "\($0.maxSpeedKmh)" } ?? "--", unit: "km/h", sub: store.f1TopSpeeds.first?.fullName ?? "OpenF1")
                            RaceRecordTile(icon: "timer", title: "最快進站紀錄", value: store.f1FastestPits.first.map { String(format: "%.1f", $0.durationSec) } ?? "--", unit: "秒", sub: store.f1FastestPits.first.map { "\($0.acronym) · Lap \($0.lapNumber)" } ?? "OpenF1")
                        }

                        SeasonCalendarHeatmapCard()

                        HStack(spacing: 8) {
                            ForEach(RaceSeries.allCases) { s in
                                let active = selectedSeries == s
                                Button {
                                    store.haptic()
                                    withAnimation {
                                        selectedSeries = s
                                        driverAIndex = 0
                                        driverBIndex = min(1, max(0, (store.driverStandings[s]?.count ?? 1) - 1))
                                    }
                                } label: {
                                    Text(s.rawValue)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(active ? .white : .white.opacity(0.55))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(active ? s.badgeColor : Color.white.opacity(0.08), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }

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
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
                .refreshable {
                    store.haptic()
                    await store.refreshAll()
                }
                .sheet(isPresented: $showPosterSheet) {
                    ShareRacePosterSheet()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct RaceRecordTile: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let sub: String

    var body: some View {
        GlassPanel(cornerRadius: 22, highlightOpacity: 0.22) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: 22, height: 22)
                        .background(.white.opacity(0.11), in: Circle())
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(unit)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }
                Text(sub)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }
}

struct SeasonCalendarHeatmapCard: View {
    @EnvironmentObject var store: MotorsportStore
    @State private var pickedEvent: RaceEvent?

    private var allEvents: [RaceEvent] {
        (store.schedules[.f1] ?? []) + (store.schedules[.motogp] ?? []) + (store.schedules[.tcr] ?? [])
    }

    private func eventOn(_ date: Date) -> RaceEvent? {
        let cal = Calendar.current
        return allEvents.first { cal.isDate($0.raceDate, inSameDayAs: date) }
    }

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -11 * 7, to: today) ?? today
        let weeks: [[Date]] = (0..<16).map { w in
            (0..<7).compactMap { d in cal.date(byAdding: .day, value: w * 7 + d, to: start) }
        }

        GlassPanel(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("16 週賽事密度熱力圖", systemImage: "square.grid.3x3.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("亮色方格代表比賽日，輕點查看賽站")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    if let ev = pickedEvent {
                        Text("\(ev.series.rawValue) · \(RaceDateFmt.md.string(from: ev.raceDate))")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(ev.series.badgeColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.10), in: Capsule())
                    }
                }

                HStack(spacing: 4) {
                    ForEach(0..<weeks.count, id: \.self) { col in
                        VStack(spacing: 4) {
                            ForEach(0..<weeks[col].count, id: \.self) { row in
                                let date = weeks[col][row]
                                let ev = eventOn(date)
                                let isToday = cal.isDateInToday(date)
                                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                    .fill(ev?.series.badgeColor ?? Color.white.opacity(isToday ? 0.35 : 0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3.5)
                                            .strokeBorder(pickedEvent?.id == ev?.id && ev != nil ? Color.white : Color.clear, lineWidth: 1.4)
                                    )
                                    .aspectRatio(1, contentMode: .fit)
                                    .onTapGesture {
                                        if let ev {
                                            store.haptic()
                                            pickedEvent = ev
                                        }
                                    }
                            }
                        }
                    }
                }

                if let ev = pickedEvent {
                    Text("🏁 \(store.displayTranslated(ev.name))（\(ev.circuit)）")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(18)
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
        let total = max(1.0, dA.points + dB.points)
        let ratioA = dA.points / total
        let diff = abs(dA.points - dB.points)
        let leader = dA.points >= dB.points ? dA : dB
        let racesNeeded = Int(ceil(diff / 25.0))

        GlassPanel(cornerRadius: 24) {
            VStack(spacing: 16) {
                HStack {
                    Picker("", selection: $indexA) {
                        ForEach(0..<drivers.count, id: \.self) { i in
                            Text("P\(drivers[i].position) \(drivers[i].shortCode)").tag(i)
                        }
                    }
                    .tint(Color(hex: dA.colorHex))

                    Text("VS")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))

                    Picker("", selection: $indexB) {
                        ForEach(0..<drivers.count, id: \.self) { i in
                            Text("P\(drivers[i].position) \(drivers[i].shortCode)").tag(i)
                        }
                    }
                    .tint(Color(hex: dB.colorHex))
                }

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(dA.shortCode)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: dA.colorHex))
                        Text(dA.name)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(dB.shortCode)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: dB.colorHex))
                        Text(dB.name)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }

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

                HStack(spacing: 8) {
                    Image(systemName: "function").foregroundStyle(.yellow)
                    Text(diff == 0
                         ? "兩位車手目前同分！"
                         : "\(leader.shortCode) 領先 \(Int(diff)) 分；落後一方最少需 \(racesNeeded) 站全勝（且對手零分）先可反超。")
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
}

// MARK: - Shareable HD Race Poster
struct ShareRacePosterSheet: View {
    @EnvironmentObject var store: MotorsportStore
    @Environment(\.dismiss) var dismiss
    @State private var renderedImage: UIImage?
    @State private var showShare = false

    var body: some View {
        let f1P1 = store.driverStandings[.f1]?.first
        let motoP1 = store.driverStandings[.motogp]?.first
        let tcrP1 = store.driverStandings[.tcr]?.first
        let next = store.nextGlobalEvent()

        let poster = VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("APEXGRID")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(store.theme.accent)
                Spacer()
                Text(RaceDateFmt.ymd.string(from: Date()))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Text("多賽事積分榜戰報")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.white)

            VStack(spacing: 10) {
                posterLeaderRow(tag: "F1", color: RaceSeries.f1.badgeColor, driver: f1P1)
                posterLeaderRow(tag: "MotoGP", color: RaceSeries.motogp.badgeColor, driver: motoP1)
                posterLeaderRow(tag: "TCR", color: RaceSeries.tcr.badgeColor, driver: tcrP1)
            }

            if let ev = next {
                VStack(alignment: .leading, spacing: 4) {
                    Text("下一站大賽 · 澳門時間").font(.caption2).foregroundStyle(.white.opacity(0.55))
                    Text("\(ev.series.rawValue) \(store.displayTranslated(ev.name))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text(RaceDateFmt.fullMacau.string(from: ev.raceDate))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(store.theme.accent)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(24)
        .background(LinearGradient(colors: store.theme.bgColors, startPoint: .topLeading, endPoint: .bottomTrailing))

        NavigationStack {
            ZStack {
                RacingBackgroundView()
                ScrollView {
                    VStack(spacing: 20) {
                        poster
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                            .padding(.horizontal, 20)
                        Button {
                            let renderer = ImageRenderer(content: poster.frame(width: 360))
                            renderer.scale = 3.0
                            if let img = renderer.uiImage {
                                renderedImage = img
                                showShare = true
                            }
                        } label: {
                            Label("儲存或分享高清戰報海報", systemImage: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.white, in: Capsule())
                        }
                        .padding(.horizontal, 28)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("生成賽車海報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) {
                if let img = renderedImage {
                    ShareSheet(items: [img])
                }
            }
        }
    }

    private func posterLeaderRow(tag: String, color: Color, driver: DriverStanding?) -> some View {
        HStack {
            Text(tag)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color, in: Capsule())
            VStack(alignment: .leading, spacing: 2) {
                Text(driver?.name ?? "--").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                Text(driver?.team ?? "").font(.caption2).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Text("\(Int(driver?.points ?? 0)) PTS")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(12)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - AI Cantonese Race Briefing Sheet
struct AIBriefingSheet: View {
    @EnvironmentObject var store: MotorsportStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                RacingBackgroundView()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        GlassPanel(cornerRadius: 24) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Label("AI 廣東話賽況懶人包", systemImage: "sparkles")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(store.theme.accent)
                                    Spacer()
                                    if store.isGeneratingBriefing {
                                        ProgressView().tint(.white)
                                    }
                                }
                                if store.aiBriefingText.isEmpty && store.isGeneratingBriefing {
                                    Text("正在整理最新 F1 / MotoGP / TCR 積分、遙測與新聞...")
                                        .foregroundStyle(.white.opacity(0.6))
                                } else {
                                    Text(store.aiBriefingText)
                                        .font(.system(size: 15, weight: .medium))
                                        .lineSpacing(6)
                                        .foregroundStyle(.white.opacity(0.94))
                                }
                            }
                            .padding(20)
                        }

                        Button {
                            store.haptic()
                            Task { await store.generateAIBriefing() }
                        } label: {
                            Label("重新生成最新賽評", systemImage: "arrow.clockwise")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white, in: Capsule())
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("AI 賽車助手")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("關閉") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - TAB 4: AI Auto-Translated Newsroom
struct NewsRoomView: View {
    @EnvironmentObject var store: MotorsportStore
    @State private var filterSeries: RaceSeries? = nil
    @State private var activeURL: IdentifiableURL?
    @State private var showBriefing = false

    private var filteredNews: [NewsArticle] {
        store.articles.filter { art in
            (filterSeries == nil || art.series == filterSeries) && (!store.onlyBreakingNews || art.isBreaking)
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
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Button {
                                store.haptic()
                                showBriefing = true
                                Task { await store.generateAIBriefing() }
                            } label: {
                                Label("AI 總結", systemImage: "sparkles")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .raceGlass(in: Capsule(), interactive: true)
                            }
                            Button {
                                store.haptic()
                                store.onlyBreakingNews.toggle()
                            } label: {
                                Image(systemName: store.onlyBreakingNews ? "flame.fill" : "flame")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(store.onlyBreakingNews ? .white : .white.opacity(0.75))
                                    .frame(width: 36, height: 36)
                                    .background(store.onlyBreakingNews ? Color.red : Color.white.opacity(0.10), in: Circle())
                            }
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "character.bubble.fill").foregroundStyle(store.theme.accent)
                            Text(store.autoTranslateEnabled ? (store.isTranslating ? "AI 正在翻譯英文新聞成繁體中文..." : "AI 自動英翻中已啟用（\(store.translationMode.title)）") : "自動翻譯已關閉（顯示英文原文）")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(1)
                            Spacer()
                            Button {
                                store.haptic()
                                Task { await store.translateLoadedContent() }
                            } label: {
                                Text("重翻").font(.caption2.bold()).foregroundStyle(store.theme.accent)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                filterChip(title: "全部", active: filterSeries == nil, color: store.theme.accent) {
                                    filterSeries = nil
                                }
                                ForEach(RaceSeries.allCases) { s in
                                    filterChip(title: s.rawValue, active: filterSeries == s, color: s.badgeColor) {
                                        filterSeries = s
                                    }
                                }
                            }
                        }

                        ForEach(filteredNews) { art in
                            Button {
                                store.haptic()
                                if let u = URL(string: art.link) {
                                    activeURL = IdentifiableURL(url: u)
                                }
                            } label: {
                                GlassPanel(cornerRadius: 18, highlightOpacity: 0.18) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 6) {
                                            Text(art.series.rawValue)
                                                .font(.system(size: 10, weight: .black))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3)
                                                .background(art.series.badgeColor, in: Capsule())
                                            if let alert = art.alertTag {
                                                Text(alert)
                                                    .font(.system(size: 10, weight: .black))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 3)
                                                    .background(Color.red, in: Capsule())
                                            }
                                            Spacer()
                                            Text(RaceDateFmt.relativeText(art.pubDate))
                                                .font(.system(size: 11))
                                                .foregroundStyle(.white.opacity(0.48))
                                        }

                                        Text(store.displayTranslated(art.title))
                                            .font(.system(size: 15.5, weight: .bold))
                                            .foregroundStyle(.white)
                                            .multilineTextAlignment(.leading)
                                            .blur(radius: store.spoilerFree ? 6 : 0)

                                        if store.showOriginalEnglish && store.autoTranslateEnabled && store.hasTranslation(for: art.title) {
                                            Text(art.title)
                                                .font(.system(size: 11.5))
                                                .foregroundStyle(.white.opacity(0.48))
                                                .multilineTextAlignment(.leading)
                                                .blur(radius: store.spoilerFree ? 5 : 0)
                                        }

                                        Text(art.source)
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(.white.opacity(0.42))
                                    }
                                    .padding(15)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
                .refreshable {
                    store.haptic()
                    await store.refreshAll()
                }
                .sheet(item: $activeURL) { item in
                    SafariSheetView(url: item.url).ignoresSafeArea()
                }
                .sheet(isPresented: $showBriefing) {
                    AIBriefingSheet()
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
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
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
    @ObservedObject private var wallRepo = WallpaperRepository.shared

    @State private var pickedWallpaper: PhotosPickerItem?
    @State private var csvURL: URL?
    @State private var showCSVShare = false
    @State private var toastMsg: String?

    var body: some View {
        NavigationStack {
            ZStack {
                RacingBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("設定")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)

                        Label("AI 自動翻譯與賽評", systemImage: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
                            .padding(.leading, 4)

                        GlassPanel(cornerRadius: 22) {
                            VStack(spacing: 14) {
                                Toggle("自動將英文新聞與判罰翻成繁中", isOn: $store.autoTranslateEnabled)
                                    .font(.system(size: 14, weight: .medium))
                                    .tint(store.theme.accent)
                                Divider().overlay(.white.opacity(0.10))
                                Toggle("翻譯下方保留英文原文對照", isOn: $store.showOriginalEnglish)
                                    .font(.system(size: 14, weight: .medium))
                                    .tint(store.theme.accent)
                                Divider().overlay(.white.opacity(0.10))
                                HStack {
                                    Text("翻譯引擎").font(.system(size: 14, weight: .medium))
                                    Spacer()
                                    Picker("", selection: $store.translationMode) {
                                        ForEach(TranslationEngineMode.allCases) { m in
                                            Text(m.title).tag(m)
                                        }
                                    }
                                    .tint(store.theme.accent)
                                }
                                Divider().overlay(.white.opacity(0.10))
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Gemini API Key（可選，免費申請解鎖專業粵語賽評）")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.6))
                                    SecureField("貼上 AIza... 開頭的免費 Key", text: $store.geminiAPIKey)
                                        .textFieldStyle(.plain)
                                        .padding(10)
                                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                }
                                Button {
                                    store.haptic()
                                    store.clearTranslationCache()
                                    Task {
                                        await store.translateLoadedContent()
                                        showToast("已清除舊緩存並重新翻譯！")
                                    }
                                } label: {
                                    Label("清除翻譯緩存並立即重新翻譯", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .foregroundStyle(store.theme.accent)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(18)
                        }

                        Label("自定義背景與車隊外觀", systemImage: "paintbrush.pointed.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
                            .padding(.leading, 4)

                        GlassPanel(cornerRadius: 22) {
                            VStack(spacing: 14) {
                                HStack {
                                    Text("本命車隊主題色").font(.system(size: 14, weight: .medium))
                                    Spacer()
                                    Picker("", selection: $store.theme) {
                                        ForEach(TeamTheme.allCases) { th in
                                            Text(th.displayName).tag(th)
                                        }
                                    }
                                    .tint(store.theme.accent)
                                }
                                Divider().overlay(.white.opacity(0.10))
                                PhotosPicker(selection: $pickedWallpaper, matching: .images) {
                                    HStack {
                                        Label("從相簿揀賽車相做 App 背景", systemImage: "photo.fill.on.rectangle.fill")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(store.theme.accent)
                                        Spacer()
                                        if wallRepo.customWallpaper != nil {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                        }
                                    }
                                }
                                if wallRepo.customWallpaper != nil {
                                    VStack(spacing: 10) {
                                        HStack {
                                            Text("背景模糊度").font(.caption)
                                            Spacer()
                                            Text("\(Int(store.wallpaperBlur))").font(.caption.monospaced())
                                        }
                                        Slider(value: $store.wallpaperBlur, in: 0...30, step: 1).tint(store.theme.accent)
                                        HStack {
                                            Text("背景壓暗度").font(.caption)
                                            Spacer()
                                            Text("\(Int(store.wallpaperDim * 100))%").font(.caption.monospaced())
                                        }
                                        Slider(value: $store.wallpaperDim, in: 0.1...0.85, step: 0.05).tint(store.theme.accent)
                                        Button(role: .destructive) {
                                            store.haptic()
                                            wallRepo.remove()
                                        } label: {
                                            Label("移除自定義背景", systemImage: "xmark.circle")
                                                .font(.caption.bold())
                                                .foregroundStyle(.red)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                Divider().overlay(.white.opacity(0.10))
                                Toggle("防劇透模式（模糊成績與新聞）", isOn: $store.spoilerFree)
                                    .font(.system(size: 14, weight: .medium))
                                    .tint(store.theme.accent)
                                Divider().overlay(.white.opacity(0.10))
                                Toggle("星空粒子動畫", isOn: $store.enableParticles)
                                    .font(.system(size: 14, weight: .medium))
                                    .tint(store.theme.accent)
                                Divider().overlay(.white.opacity(0.10))
                                Toggle("觸覺震動回饋", isOn: $store.enableHaptics)
                                    .font(.system(size: 14, weight: .medium))
                                    .tint(store.theme.accent)
                            }
                            .padding(18)
                        }

                        Label("數據同步與匯出", systemImage: "externaldrive.badge.checkmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
                            .padding(.leading, 4)

                        GlassPanel(cornerRadius: 22) {
                            VStack(spacing: 14) {
                                Button {
                                    store.haptic()
                                    Task {
                                        await store.refreshAll()
                                        showToast("已同步最新賽事數據、AI 翻譯與桌面小工具！")
                                    }
                                } label: {
                                    HStack {
                                        Label("立即重新同步所有賽事與小工具", systemImage: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 14, weight: .semibold))
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
                                Button {
                                    store.haptic()
                                    if let url = store.exportStandingsCSV() {
                                        csvURL = url
                                        showCSVShare = true
                                    }
                                } label: {
                                    HStack {
                                        Label("匯出全賽事積分榜 (CSV)", systemImage: "doc.text.fill")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Text("CSV").font(.caption.bold()).foregroundStyle(.white.opacity(0.5))
                                    }
                                }
                            }
                            .padding(18)
                        }

                        Text("ApexGrid 2.5 · Liquid Glass + AI Auto-Translate")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.38))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }

                if let msg = toastMsg {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .raceGlass(in: Capsule(), interactive: false)
                            .padding(.bottom, 24)
                    }
                    .transition(.opacity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: pickedWallpaper) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        wallRepo.save(img)
                    }
                }
            }
            .sheet(isPresented: $showCSVShare) {
                if let url = csvURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func showToast(_ text: String) {
        withAnimation { toastMsg = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { toastMsg = nil }
        }
    }
}
