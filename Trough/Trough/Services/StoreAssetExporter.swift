import SwiftUI
import SwiftData

#if DEBUG
/// `-TRExportAssets` (DEBUG, App Store screenshots: Trough/Tools/make_store_screenshots.sh).
/// Renders crisp, transparent marketing assets into Documents/StoreAssets/ so the compositor can
/// float them over the device frames instead of cropping them out of screenshots. Run it with
/// `-TRSeedDemo` so the numbers match the captured screens. Writes `done.txt` last (the list of
/// files), so the script can wait for it.
///
/// From `ShareRenderer.exportAssets(to:data:)` (achievements): card-rank/streak/badge-story|square,
/// medallion-<id>.png, emblem-streak-flame.png, emblem-rank.png.
/// Local (this file): rank-card, streak-card, score-card, next-injection, marker-card, xp-chip,
/// badge-1…3 (medallion + title), stamp-1…3 (injection stamps, transparent ink).
@MainActor
enum StoreAssetExporter {

    static func scheduleIfRequested(container: ModelContainer) {
        guard DemoMode.flag("-TRExportAssets") else { return }
        Task { @MainActor in
            // Let MainTabView run the gamification setup first (GamificationViewModel.active).
            for _ in 0..<40 where GamificationViewModel.active == nil {
                try? await Task.sleep(for: .milliseconds(250))
            }
            try? await Task.sleep(for: .seconds(1))
            run(context: ModelContext(container))
        }
    }

    static func run(context: ModelContext) {
        let folder = URL.documentsDirectory.appending(path: "StoreAssets", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var written: [String] = []

        func save(_ view: some View, _ name: String) {
            let renderer = ImageRenderer(content: view
                .environment(\.trStaticRender, true)
                .environment(\.colorScheme, .dark)
                .environment(\.dynamicTypeSize, .large))
            renderer.scale = 3
            renderer.isOpaque = false
            guard let data = renderer.uiImage?.pngData() else { return }
            try? data.write(to: folder.appending(path: name))
            written.append(name)
        }

        let data = ShareCardData.current
        let vm = GamificationViewModel.active

        // Share cards + medallions + emblems (owned by the Share feature).
        written += ShareRenderer.exportAssets(to: folder, data: data).map(\.lastPathComponent)

        // Rank passport card: the rank cover with XP progress.
        let xp = vm?.currentXP ?? 1_436
        let progress = vm?.levelProgressPercent ?? 0.8
        let toNext = vm?.xpUntilNextLevel ?? 84
        save(StoreRankCard(data: data, xp: xp, progress: progress, xpToNext: toNext).padding(36), "rank-card.png")

        // Streak card: flame emblem + count.
        save(StoreStreakCard(days: data.checkinStreak, weeks: data.injectionWeeks).padding(36), "streak-card.png")

        // Badge medals with their titles, most prestigious first.
        let unlocked = (vm?.badgeProgress ?? []).filter(\.isUnlocked).map(\.def).sorted { $0.prestige > $1.prestige }
        let showcase = ["checkin_streak_100", "on_schedule_weeks_12", "checkins_100"].compactMap(GamificationCatalog.badge)
        let medals = (showcase.filter { unlocked.contains($0) } + unlocked).reduce(into: [BadgeDef]()) { out, def in
            if !out.contains(def) { out.append(def) }
        }
        for (index, def) in medals.prefix(3).enumerated() {
            save(StoreBadgeMedal(def: def).padding(30), "badge-\(index + 1).png")
        }

        // Today's Protocol Score (self-rated; ring card).
        let checkins = (try? context.fetch(FetchDescriptor<SDCheckin>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        let week = checkins.prefix(7).map(\.protocolScore)
        save(StoreScoreCard(score: checkins.first?.protocolScore ?? 78, week: Array(week.reversed())).padding(36), "score-card.png")

        // Next injection card (primary protocol).
        let protocols = (try? context.fetch(FetchDescriptor<SDProtocol>())) ?? []
        let injections = (try? context.fetch(FetchDescriptor<SDInjection>(sortBy: [SortDescriptor(\.injectedAt, order: .reverse)]))) ?? []
        if let proto = protocols.first(where: { $0.isPrimary && $0.isActive }) {
            let next = InjectionCycleService.nextInjectionDate(for: proto, injections: injections)
            let own = injections.filter { $0.protocolID == proto.id }
            let site = InjectionCycleService.siteRotationSuggestion(recentInjections: own).displayName
            save(StoreNextInjectionCard(name: proto.name, next: next, site: site).padding(36), "next-injection.png")

            // The estimated PK curve card for the primary protocol (hCG's IU scale would flatten the curve).
            let active = [proto]
            let cutoff = Calendar.current.date(byAdding: .day, value: -42, to: .now) ?? .now
            let pkProtocols = active.map {
                PKProtocolInput(compoundName: $0.compoundName, doseAmountMg: $0.doseAmountMg, frequencyDays: $0.frequencyDays,
                                colorHex: PKCurveEngine.compoundColors(for: $0.compoundName), customHalfLife: nil, route: "intramuscular")
            }
            let pkInjections = injections.filter { $0.injectedAt > cutoff && $0.protocolID == proto.id }.reversed().map {
                PKInjectionInput(compoundName: $0.compoundName, doseAmountMg: $0.doseAmountMg, injectedAt: $0.injectedAt,
                                 route: $0.injectionSite?.lowercased().contains("sub") == true ? "subcutaneous" : "intramuscular")
            }
            save(PKCurveView(protocols: pkProtocols, injections: Array(pkInjections), overdueDays: 0)
                    .frame(width: 360)
                    .trCard(tint: TR.Palette.coral)
                    .padding(36), "pk-card.png")
            for (index, shot) in own.prefix(3).enumerated() {
                save(InjectionStampView(id: shot.id, compound: shot.compoundName, site: shot.injectionSite, date: shot.injectedAt, size: 240)
                        .padding(30), "stamp-\(index + 1).png")
            }
        }

        // Bloodwork marker card: the latest panel's key markers + a trend line (organizing, not judging).
        let panels = (try? context.fetch(FetchDescriptor<SDBloodwork>(sortBy: [SortDescriptor(\.drawnAt)]))) ?? []
        if !panels.isEmpty {
            save(StoreMarkerCard(panels: panels).padding(36), "marker-card.png")
        }

        save(StoreXPChip(xp: 20).padding(24), "xp-chip.png")

        try? written.joined(separator: "\n").write(to: folder.appending(path: "done.txt"), atomically: true, encoding: .utf8)
        print("[StoreAssetExporter] wrote \(written.count) assets to \(folder.path)")
    }
}

// MARK: - Asset views

private let cardShape = RoundedRectangle(cornerRadius: 26, style: .continuous)

/// Card chrome for floating assets: surface fill, hairline, tint glow, deep shadow baked in by the compositor.
private struct StoreCardChrome: ViewModifier {
    var tint: Color
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background {
                ZStack {
                    cardShape.fill(TR.Palette.surface)
                    cardShape.fill(RadialGradient(colors: [tint.opacity(0.32), .clear], center: .topLeading, startRadius: 0, endRadius: 280))
                    cardShape.strokeBorder(.white.opacity(0.14), lineWidth: 1)
                }
            }
    }
}

private extension View {
    func storeCard(tint: Color) -> some View { modifier(StoreCardChrome(tint: tint)) }
}

private struct StoreKicker: View {
    let text: String
    var color: Color = TR.Palette.textSecondary
    var body: some View {
        Text(verbatim: text.uppercased())
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(1.3)
            .foregroundStyle(color)
    }
}

private struct StoreRankCard: View {
    let data: ShareCardData
    let xp: Int
    let progress: Double
    let xpToNext: Int

    var body: some View {
        let cover = data.cover
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                RankEmblem(level: data.level, width: 78, shadow: false)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: String(format: gLoc("store.rankLine", "%1$@ RANK · LEVEL %2$d"), cover.displayName.uppercased(), data.level))
                        .font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(1.1)
                        .foregroundStyle(cover.ink.opacity(0.7))
                    Text(verbatim: data.levelName)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(cover.ink)
                    Text(verbatim: "\(xp.formatted()) XP")
                        .font(.system(size: 15, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(cover.ink.opacity(0.8))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(cover.ink.opacity(0.16))
                        Capsule().fill(LinearGradient(colors: [cover.ink.opacity(0.85), cover.ink.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * max(0.06, progress))
                    }
                }
                .frame(height: 9)
                Text(verbatim: String(format: gLoc("ach.passport.toNext", "%d XP to %@"), xpToNext,
                                       String(format: gLoc("ach.levelN", "Level %d"), min(11, data.level + 1))))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(cover.ink.opacity(0.7))
            }
            HStack(spacing: 8) {
                pill("flame.fill", String(format: gLoc("ach.chip.streak", "%d-day streak"), data.checkinStreak), cover.ink)
                pill("rosette", String(format: gLoc("ach.chip.badges", "%d/%d badges"), data.badgesUnlocked, data.badgesTotal), cover.ink)
            }
        }
        .padding(20)
        .frame(width: 330)
        .background {
            ZStack {
                cardShape.fill(cover.gradient)
                cardShape.fill(LinearGradient(colors: [.white.opacity(0.4), .clear, .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .blendMode(.plusLighter)
                cardShape.strokeBorder(.white.opacity(0.55), lineWidth: 1.5)
            }
        }
    }

    private func pill(_ symbol: String, _ text: String, _ ink: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 11, weight: .heavy))
            Text(verbatim: text).font(.system(size: 12, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(ink.opacity(0.12), in: Capsule())
    }
}

private struct StoreStreakCard: View {
    let days: Int
    let weeks: Int
    var body: some View {
        VStack(spacing: 6) {
            StreakFlameEmblem(level: 5, size: 132)
            Text(verbatim: "\(days)")
                .font(.system(size: 50, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(LinearGradient(colors: [TR.Palette.gold, TR.Palette.tangerine], startPoint: .top, endPoint: .bottom))
                .padding(.top, 2)
            StoreKicker(text: gLoc("ach.share.stat.dayStreak", "day streak"), color: TR.Palette.textPrimary.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .frame(width: 190)
        .storeCard(tint: TR.Palette.gold)
    }
}

private struct StoreBadgeMedal: View {
    let def: BadgeDef
    var body: some View {
        VStack(spacing: 10) {
            BadgeMedallion(systemImage: def.symbol, tier: def.tier, status: .unlocked, size: 150, discColors: def.discColors)
            Text(verbatim: def.title)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(TR.Palette.textPrimary)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(TR.Palette.surface.opacity(0.95), in: Capsule())
                .overlay(Capsule().strokeBorder(def.tier.glowColor.opacity(0.6), lineWidth: 1.2))
        }
    }
}

private struct StoreScoreCard: View {
    let score: Double
    let week: [Double]
    var body: some View {
        HStack(spacing: 16) {
            TRRing(progress: score / 100, lineWidth: 12) {
                VStack(spacing: 0) {
                    Text(verbatim: "\(Int(score.rounded()))")
                        .font(.system(size: 34, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(TR.Palette.textPrimary)
                    Text(verbatim: "/ 100").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(TR.Palette.textSecondary)
                }
            }
            .frame(width: 112, height: 112)
            VStack(alignment: .leading, spacing: 8) {
                StoreKicker(text: NSLocalizedString("dashboard.protocolScore", comment: ""), color: TR.Palette.coralLight)
                Text(verbatim: NSLocalizedString("common.today", comment: "")).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(TR.Palette.textPrimary)
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(Array(week.enumerated()), id: \.offset) { index, value in
                        Capsule()
                            .fill(index == week.count - 1 ? AnyShapeStyle(TR.Gradients.cta) : AnyShapeStyle(Color.white.opacity(0.22)))
                            .frame(width: 9, height: max(8, CGFloat(value) / 100 * 44))
                    }
                }
                .frame(height: 44, alignment: .bottom)
                Text(verbatim: gLoc("store.selfRated7d", "Self-rated · last 7 days")).font(.system(size: 11, weight: .semibold)).foregroundStyle(TR.Palette.textTertiary)
            }
        }
        .frame(width: 320, alignment: .leading)
        .storeCard(tint: TR.Palette.coral)
    }
}

private struct StoreNextInjectionCard: View {
    let name: String
    let next: Date
    let site: String
    var body: some View {
        let days = max(0, Calendar.current.dateComponents([.day], from: Date.now.startOfDay, to: next.startOfDay).day ?? 0)
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(TR.Gradients.cta)
                Image(systemName: "syringe.fill").font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
            }
            .frame(width: 62, height: 62)
            .shadow(color: TR.Palette.coral.opacity(0.6), radius: 12)
            VStack(alignment: .leading, spacing: 3) {
                StoreKicker(text: gLoc("dash.today.nextShot", "Next injection"), color: TR.Palette.coralLight)
                Text(verbatim: days == 0 ? NSLocalizedString("common.today", comment: "")
                     : days == 1 ? gLoc("store.tomorrow", "Tomorrow")
                     : String(format: gLoc("store.inDays", "In %d days"), days))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(TR.Palette.textPrimary)
                Text(verbatim: String(format: gLoc("store.siteSuggested", "%1$@ · %2$@ suggested"),
                                     next.formatted(.dateTime.weekday(.wide)), InjectionSite.localizedName(site)))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TR.Palette.textSecondary)
            }
        }
        .frame(width: 320, alignment: .leading)
        .storeCard(tint: TR.Palette.coral)
    }
}

private struct StoreMarkerCard: View {
    let panels: [SDBloodwork]
    private let markers: [(String, String, Color)] = [
        ("Total Testosterone", "Total T", TR.Palette.coral),
        ("Estradiol (E2)", "E2", TR.Palette.gold),
        ("Hematocrit", "HCT", TR.Palette.teal),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StoreKicker(text: NSLocalizedString("bloodwork.title", comment: ""), color: TR.Palette.sky)
                Spacer()
                Text(verbatim: String(format: gLoc("store.panels", "%d panels"), panels.count)).font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(TR.Palette.textSecondary)
            }
            ForEach(markers, id: \.0) { name, short, color in
                let series = panels.compactMap { $0.markers.first { $0.markerName == name } }
                if let last = series.last {
                    HStack(spacing: 10) {
                        Text(verbatim: short).font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundStyle(color)
                            .frame(width: 54, alignment: .leading)
                        Sparkline(values: series.map(\.value), color: color).frame(height: 26)
                        Text(verbatim: "\(last.value.formatted(.number.precision(.fractionLength(last.value < 100 ? 1 : 0)))) \(last.unit)")
                            .font(.system(size: 14, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(TR.Palette.textPrimary)
                            .frame(width: 96, alignment: .trailing)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(TR.Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            Text(verbatim: String(format: gLoc("store.latest", "Latest: %@"), (panels.last?.drawnAt ?? .now).formatted(.dateTime.month(.abbreviated).day())))
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(TR.Palette.textTertiary)
        }
        .frame(width: 330)
        .storeCard(tint: TR.Palette.sky)
    }
}

private struct Sparkline: View {
    let values: [Double]
    let color: Color
    var body: some View {
        GeometryReader { geo in
            let lo = values.min() ?? 0, hi = values.max() ?? 1
            let span = max(hi - lo, 0.0001)
            let points = values.enumerated().map { i, v in
                CGPoint(x: values.count > 1 ? geo.size.width * CGFloat(i) / CGFloat(values.count - 1) : geo.size.width / 2,
                        y: geo.size.height * (1 - CGFloat((v - lo) / span)) * 0.8 + geo.size.height * 0.1)
            }
            ZStack {
                Path { p in p.addLines(points) }
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                    Circle().fill(color).frame(width: 6, height: 6).position(pt)
                }
            }
        }
    }
}

private struct StoreXPChip: View {
    let xp: Int
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").font(.system(size: 22, weight: .heavy))
            Text(verbatim: "+\(xp) XP").font(.system(size: 30, weight: .black, design: .rounded))
        }
        .foregroundStyle(Color(trHex: 0x3A2600))
        .padding(.horizontal, 22).padding(.vertical, 12)
        .background(Capsule().fill(TR.Gradients.xp))
        .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
        .shadow(color: TR.Palette.gold.opacity(0.6), radius: 14)
    }
}
#endif
