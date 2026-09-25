import SwiftUI
import SwiftData

// MARK: - InjectionsView

struct InjectionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("userIDString") private var userIDString = UUID().uuidString
    @EnvironmentObject private var gamificationVM: GamificationViewModel
    @StateObject private var vm = InjectionsViewModel()
    @State private var injectionPendingDelete: SDInjection?
    @State private var slamShown: SDInjection?
    @State private var slamHolds = false
    #if DEBUG
    @State private var didHandleScreenshotHook = false
    #endif

    private var isScreenshotMode: Bool { ProcessInfo.processInfo.arguments.contains("-TRScreenshotMode") }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                TRBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        streakHeader
                            .trRevealOnAppear()
                        InjectionCalendarView(vm: vm)
                            .trRevealOnAppear(delay: 0.05)
                        if !vm.injections.isEmpty {
                            nextSiteCard
                                .trRevealOnAppear(delay: 0.08)
                        }

                        if vm.injections.isEmpty {
                            emptyState
                        } else {
                            stampLog
                        }

                        DisclaimerBanner(type: .standard)
                            .padding(.bottom, 90)
                    }
                    .padding(.horizontal, TR.Metrics.gutter)
                }

                fab
            }
            .navigationTitle(NSLocalizedString("injections.title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(TR.Palette.abyss.opacity(0.94), for: .navigationBar)
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $vm.showingLogSheet, onDismiss: { vm.load() }) {
                LogInjectionSheet(vm: vm)
            }
            .confirmationDialog(
                NSLocalizedString("injections.deleteConfirm", comment: ""),
                isPresented: Binding(
                    get: { injectionPendingDelete != nil },
                    set: { if !$0 { injectionPendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("common.delete", comment: ""), role: .destructive) {
                    if let inj = injectionPendingDelete { vm.delete(inj) }
                    injectionPendingDelete = nil
                }
                Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) { injectionPendingDelete = nil }
            } message: {
                Text(NSLocalizedString("injections.cantUndo", comment: ""))
            }
            .onAppear {
                let uid = UUID(uuidString: userIDString) ?? UUID()
                vm.setup(context: modelContext, userID: uid)
                vm.gamificationVM = gamificationVM
                #if DEBUG
                if !didHandleScreenshotHook, ProcessInfo.processInfo.arguments.contains("-TRStampSlam"), let latest = vm.injections.first {
                    didHandleScreenshotHook = true
                    slamHolds = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.6))
                        slamShown = latest
                    }
                }
                #endif
            }
            .onChange(of: vm.slamInjection) { _, new in
                guard let new else { return }
                vm.slamInjection = nil
                slamHolds = false
                Task { @MainActor in
                    // Let the log sheet finish sliding away first.
                    try? await Task.sleep(for: .seconds(0.45))
                    slamShown = new
                }
            }
            .alert(NSLocalizedString("common.error", comment: ""), isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button(NSLocalizedString("common.ok", comment: ""), role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
        .overlay {
            if let inj = slamShown {
                InjectionStampSlamOverlay(injection: inj, streakWeeks: gamificationVM.injectionStreakWeeks, holds: slamHolds) {
                    withAnimation(TR.Motion.gentle) { slamShown = nil }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(TR.Motion.gentle, value: slamShown?.id)
    }

    // MARK: Streak header

    private var streakHeader: some View {
        HStack(spacing: 16) {
            TRRing(progress: min(1, Double(gamificationVM.injectionStreakWeeks) / 12), lineWidth: 10,
                   colors: [TR.Palette.coral, TR.Palette.tangerine, TR.Palette.gold]) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [TR.Palette.gold, TR.Palette.coral], startPoint: .top, endPoint: .bottom))
            }
            .frame(width: 84, height: 84)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                TRKicker(Text(NSLocalizedString("inj14.streakKicker", value: "On-schedule streak", comment: "")), color: TR.Palette.gold)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    CountUp(gamificationVM.injectionStreakWeeks)
                        .font(TR.Font.number(40))
                        .foregroundStyle(TR.Palette.textPrimary)
                    Text(gamificationVM.injectionStreakWeeks == 1
                         ? NSLocalizedString("inj14.week", value: "week", comment: "streak unit, singular")
                         : NSLocalizedString("inj14.weeks", value: "weeks", comment: "streak unit, plural"))
                        .font(TR.Font.display(.title3, weight: .bold))
                        .foregroundStyle(TR.Palette.textSecondary)
                }
                Text(String(format: NSLocalizedString("inj14.stampsCollected", value: "%d stamps collected", comment: "Total injection stamps"), vm.injections.count))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TR.Palette.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .trCard(tint: TR.Palette.gold)
        .accessibilityElement(children: .combine)
    }

    // MARK: Next site

    private var nextSiteCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(TR.Palette.teal)
                .frame(width: 36, height: 36)
                .background(TR.Palette.teal.opacity(0.18), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                TRKicker(Text(NSLocalizedString("inj14.nextSite", value: "Next site in rotation", comment: "")))
                Text(InjectionSite.localizedName(vm.suggestedSite))
                    .font(TR.Font.display(.headline, weight: .heavy))
                    .foregroundStyle(TR.Palette.textPrimary)
            }
            Spacer(minLength: 0)
            Image(systemName: "star.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color(trHex: 0x3A2600))
                .frame(width: 28, height: 28)
                .background(TR.Gradients.xp, in: Circle())
                .shadow(color: TR.Palette.gold.opacity(0.7), radius: 8)
                .accessibilityHidden(true)
        }
        .trCard(tint: TR.Palette.teal, padding: 14)
        .accessibilityElement(children: .combine)
    }

    // MARK: FAB

    private var fab: some View {
        Button {
            vm.prepareLogForm()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "seal.fill")
                    .font(.system(size: 18, weight: .bold))
                Text(NSLocalizedString("inj14.fab", value: "Log", comment: "Log injection floating button"))
                    .font(TR.Font.display(.headline, weight: .heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background {
                ZStack {
                    Capsule().fill(TR.Gradients.cta)
                    Capsule().fill(LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .center)).padding(1.5)
                }
                .shadow(color: TR.Palette.coral.opacity(0.55), radius: 16, y: 8)
            }
            .overlay(Capsule().strokeBorder(.white.opacity(0.2)))
        }
        .buttonStyle(.trPressable)
        .padding(20)
        .accessibilityLabel(NSLocalizedString("injections.logNew", comment: ""))
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "seal",
            title: NSLocalizedString("injections.logFirst", comment: ""),
            subtitle: NSLocalizedString("injections.logFirstSubtitle", comment: ""),
            ctaLabel: NSLocalizedString("injections.logInjection", comment: ""),
            onCTA: { vm.prepareLogForm() }
        )
        .trCard()
    }

    // MARK: Stamp log

    private struct WeekGroup: Identifiable {
        let id: Date          // ISO week start
        let week: Int
        let year: Int
        let items: [SDInjection]
        let onSchedule: Bool
        let isCurrent: Bool
    }

    private var weekGroups: [WeekGroup] {
        let iso = InjectionWeekStreak.isoCalendar()
        let freq = (vm.activeProtocols.first(where: { $0.isPrimary }) ?? vm.activeProtocols.first)?.frequencyDays ?? 7
        let cadence = InjectionWeekStreak.cadenceWeeks(frequencyDays: freq)
        let grouped = Dictionary(grouping: vm.injections) { iso.dateInterval(of: .weekOfYear, for: $0.injectedAt)?.start ?? $0.injectedAt.startOfDay }
        let starts = grouped.keys.sorted()      // oldest → newest
        let thisWeek = iso.dateInterval(of: .weekOfYear, for: .now)?.start
        var result: [WeekGroup] = []
        for (i, start) in starts.enumerated() {
            let gap = i == 0 ? 1 : (iso.dateComponents([.weekOfYear], from: starts[i - 1], to: start).weekOfYear ?? .max)
            result.append(WeekGroup(
                id: start,
                week: iso.component(.weekOfYear, from: start),
                year: iso.component(.yearForWeekOfYear, from: start),
                items: (grouped[start] ?? []).sorted { $0.injectedAt > $1.injectedAt },
                onSchedule: gap <= cadence,
                isCurrent: start == thisWeek
            ))
        }
        return result.reversed()
    }

    private var stampLog: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                TRSectionHeader(Text(NSLocalizedString("inj14.logTitle", value: "Stamp log", comment: "Injection log section title")))
            }
            if !isScreenshotMode && vm.injections.count <= 4 {
                TRPill(Text(NSLocalizedString("inj14.tip", value: "Tap a stamp to edit · hold for more", comment: "Transient tip")),
                       systemImage: "hand.tap.fill", tint: TR.Palette.sky)
            }
            let columns = [GridItem(.adaptive(minimum: 100, maximum: 130), spacing: 14)]
            ForEach(weekGroups) { group in
                VStack(alignment: .leading, spacing: 12) {
                    weekHeader(group)
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(group.items, id: \.id) { inj in
                            InjectionStampSticker(injection: inj)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture { vm.prepareEditForm(injection: inj) }
                                .contextMenu {
                                    Button {
                                        vm.prepareEditForm(injection: inj)
                                    } label: {
                                        Label(NSLocalizedString("injections.editInjection", comment: ""), systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        injectionPendingDelete = inj
                                    } label: {
                                        Label(NSLocalizedString("common.delete", comment: ""), systemImage: "trash")
                                    }
                                }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityHint(Text(NSLocalizedString("inj14.stampHint", value: "Opens the injection to edit", comment: "")))
                        }
                    }
                }
            }
        }
    }

    private func weekHeader(_ group: WeekGroup) -> some View {
        HStack(spacing: 8) {
            Text(group.isCurrent
                 ? NSLocalizedString("inj14.thisWeek", value: "This week", comment: "")
                 : String(format: NSLocalizedString("inj14.weekN", value: "Week %d", comment: "ISO week number header"), group.week))
                .font(TR.Font.display(.subheadline, weight: .heavy))
                .foregroundStyle(TR.Palette.textPrimary)
            if group.onSchedule {
                HStack(spacing: 4) {
                    Text(verbatim: "·").foregroundStyle(TR.Palette.textTertiary)
                    Text(NSLocalizedString("inj14.onSchedule", value: "on schedule", comment: "Week header status"))
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.black))
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(TR.Palette.teal)
            }
            Spacer()
            Text(verbatim: "\(group.items.count)")
                .font(TR.Font.number(.caption, weight: .heavy))
                .foregroundStyle(TR.Palette.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(TR.Palette.surfaceRaised, in: Capsule())
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - InjectionCalendarView

private struct InjectionCalendarView: View {
    @ObservedObject var vm: InjectionsViewModel
    @State private var displayedMonth: Date = Date.now.startOfDay

    private var monthDays: [Date?] {
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: displayedMonth)!
        // Leading blanks relative to the locale's first weekday (e.g. Monday in de/fr/sv).
        let firstWeekday = (cal.component(.weekday, from: firstOfMonth) - cal.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for d in range {
            days.append(cal.date(byAdding: .day, value: d - 1, to: firstOfMonth))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private var firstOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: displayedMonth))!
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    /// Locale-aware single-letter weekday symbols, rotated so the row starts on
    /// the calendar's first weekday (Sunday in en-US, Monday in most of Europe).
    private var weekdaySymbols: [String] {
        let cal = Calendar.current
        let symbols = cal.veryShortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    var body: some View {
        let byDay = vm.injectionsByDay
        VStack(spacing: 10) {
            HStack {
                monthButton("chevron.left", delta: -1)
                Spacer()
                Text(monthTitle)
                    .font(TR.Font.display(.headline, weight: .heavy))
                    .foregroundStyle(TR.Palette.textPrimary)
                Spacer()
                monthButton("chevron.right", delta: 1)
            }

            HStack(spacing: 0) {
                ForEach(weekdaySymbols.indices, id: \.self) { i in
                    Text(weekdaySymbols[i])
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(TR.Palette.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(monthDays.indices, id: \.self) { i in
                    if let day = monthDays[i] {
                        InjectionDayMarker(
                            dayNumber: Calendar.current.component(.day, from: day),
                            injections: byDay[day] ?? [],
                            isToday: Calendar.current.isDateInToday(day)
                        )
                        .frame(height: 38)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(day.formatted(date: .complete, time: .omitted)))
                        .accessibilityValue(Text((byDay[day] ?? []).map(\.compoundName).joined(separator: ", ")))
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
        }
        .trCard(tint: TR.Palette.coral)
    }

    private func monthButton(_ symbol: String, delta: Int) -> some View {
        Button {
            withAnimation(TR.Motion.snappy) {
                displayedMonth = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(TR.Palette.textSecondary)
                .frame(width: 34, height: 34)
                .background(TR.Palette.surfaceRaised, in: Circle())
                .overlay(Circle().strokeBorder(TR.Palette.hairline))
                .frame(minWidth: TR.Metrics.minTap, minHeight: TR.Metrics.minTap)
        }
        .accessibilityLabel(Text(delta < 0
                                 ? NSLocalizedString("inj14.prevMonth", value: "Previous month", comment: "")
                                 : NSLocalizedString("inj14.nextMonth", value: "Next month", comment: "")))
    }
}

// MARK: - LogInjectionSheet

struct LogInjectionSheet: View {
    @ObservedObject var vm: InjectionsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                TRBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        compoundSection
                        dateSection
                        siteSection
                        notesSection
                        Button { vm.saveForm() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "seal.fill")
                                Text(vm.editingInjection != nil
                                     ? NSLocalizedString("common.save", comment: "")
                                     : NSLocalizedString("inj14.stampIt", value: "Stamp it", comment: "Save a new injection"))
                            }
                        }
                        .buttonStyle(.trPrimary)
                        .padding(.top, 4)
                        if vm.editingInjection != nil {
                            deleteButton
                        }
                    }
                    .padding(TR.Metrics.gutter)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .confirmationDialog(
                NSLocalizedString("injections.deleteConfirm", comment: ""),
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("common.delete", comment: ""), role: .destructive) { vm.deleteEditingInjection() }
                Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("injections.cantUndo", comment: ""))
            }
            .navigationTitle(vm.editingInjection != nil
                             ? NSLocalizedString("injections.editInjection", comment: "")
                             : NSLocalizedString("injections.logInjection", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TR.Palette.abyss.opacity(0.94), for: .navigationBar)
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
                        .foregroundStyle(TR.Palette.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("common.save", comment: "")) { vm.saveForm() }
                        .foregroundStyle(TR.Palette.coral)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(TR.Palette.abyss)
        .preferredColorScheme(.dark)
    }

    private var compoundSection: some View {
        SectionCard(title: NSLocalizedString("common.compound", comment: ""), systemImage: "drop.fill", tint: TR.Palette.coral) {
            if !vm.activeProtocols.isEmpty {
                Picker(NSLocalizedString("common.compound", comment: ""), selection: $vm.formCompoundName) {
                    ForEach(vm.activeProtocols, id: \.compoundName) { p in
                        Text(p.compoundName).tag(p.compoundName)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: vm.formCompoundName) { _, newVal in
                    if let proto = vm.activeProtocols.first(where: { $0.compoundName == newVal }) {
                        vm.formDoseMg = String(format: "%.0f", proto.doseAmountMg)
                    }
                }
            } else {
                Picker(NSLocalizedString("common.compound", comment: ""), selection: $vm.formCompoundName) {
                    ForEach(["Testosterone Cypionate", "Testosterone Enanthate",
                             "Testosterone Propionate", "HCG"], id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .pickerStyle(.menu)
                .tint(TR.Palette.coral)
            }

            HStack {
                Text(NSLocalizedString("common.dose", comment: ""))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TR.Palette.textSecondary)
                Spacer()
                TextField(NSLocalizedString("common.mg", comment: ""), text: $vm.formDoseMg)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(TR.Font.number(.title3, weight: .bold))
                    .foregroundStyle(TR.Palette.textPrimary)
                    .frame(width: 90)
                Text(NSLocalizedString("common.mg", comment: ""))
                    .foregroundStyle(TR.Palette.textSecondary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(TR.Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous))
        }
    }

    private var dateSection: some View {
        SectionCard(title: NSLocalizedString("injections.dateTime", comment: ""), systemImage: "calendar", tint: TR.Palette.sky) {
            DatePicker(NSLocalizedString("injections.when", comment: ""), selection: $vm.formDate, in: ...Date.now)
                .tint(TR.Palette.coral)
                .foregroundStyle(TR.Palette.textPrimary)
        }
    }

    private var siteSection: some View {
        SectionCard(title: NSLocalizedString("injections.injectionSite", comment: ""), systemImage: "arrow.triangle.2.circlepath", tint: TR.Palette.gold) {
            InjectionSitePicker(
                selectedSite: $vm.formSite,
                recentInjections: vm.recentInjectionsForSiteRotation
            )
        }
    }

    private var notesSection: some View {
        SectionCard(title: NSLocalizedString("injections.notesOptional", comment: ""), systemImage: "note.text", tint: TR.Palette.lilac) {
            TextField(NSLocalizedString("injections.notesPlaceholder", comment: ""), text: $vm.formNotes, axis: .vertical)
                .lineLimit(3...6)
                .foregroundStyle(TR.Palette.textPrimary)
                .padding(12)
                .background(TR.Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous))
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label(NSLocalizedString("injections.deleteInjection", comment: ""), systemImage: "trash")
        }
        .buttonStyle(TRSecondaryButtonStyle(tint: TR.Palette.coral))
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    var systemImage: String
    var tint: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 26, height: 26)
                    .background(tint.opacity(0.18), in: Circle())
                    .accessibilityHidden(true)
                TRKicker(Text(title))
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trCard(tint: tint, padding: 14)
    }
}
