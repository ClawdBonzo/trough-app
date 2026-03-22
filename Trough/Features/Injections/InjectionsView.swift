import SwiftUI
import SwiftData

// MARK: - InjectionsView

struct InjectionsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm: InjectionsViewModel

    init() {
        let id = UUID(uuidString: UserDefaults.standard.string(forKey: "userIDString") ?? "") ?? UUID()
        _vm = StateObject(wrappedValue: InjectionsViewModel(
            modelContext: ModelContext(try! ModelContainer(for: Schema(TroughSchemaV1.models))),
            userID: id
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        InjectionCalendarView(vm: vm)
                            .padding(.bottom, 8)

                        if vm.injections.isEmpty {
                            emptyState
                        } else {
                            injectionList
                        }
                    }
                }

                // FAB
                Button {
                    vm.prepareLogForm()
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(AppColors.accent)
                        .clipShape(Circle())
                        .shadow(color: AppColors.accent.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(20)
            }
            .navigationTitle("Injections")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $vm.showingLogSheet, onDismiss: { vm.load() }) {
                LogInjectionSheet(vm: vm)
            }
            .onAppear { vm.load() }
            .alert("Error", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "syringe",
            title: "Log your first injection",
            subtitle: "Tap + to record a dose. Trough tracks your cycle and suggests injection sites.",
            ctaLabel: "Log Injection",
            onCTA: { vm.prepareLogForm() }
        )
    }

    private var injectionList: some View {
        LazyVStack(spacing: 0) {
            ForEach(groupedSections, id: \.0) { (header, items) in
                Section {
                    ForEach(items, id: \.id) { inj in
                        InjectionRow(injection: inj, color: vm.color(for: inj.compoundName))
                            .onTapGesture { vm.prepareEditForm(injection: inj) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { vm.delete(inj) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        Divider()
                            .background(Color.white.opacity(0.05))
                            .padding(.leading, 56)
                    }
                } header: {
                    Text(header)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 6)
                        .background(AppColors.background)
                }
            }
        }
        .padding(.bottom, 80) // FAB clearance
    }

    private var groupedSections: [(String, [SDInjection])] {
        let cal = Calendar.current
        var groups: [(String, [SDInjection])] = []
        var processed = Set<Date>()

        for inj in vm.injections {
            let day = inj.injectedAt.startOfDay
            guard !processed.contains(day) else { continue }
            processed.insert(day)

            let items = vm.injections.filter { $0.injectedAt.startOfDay == day }
            let header: String
            if cal.isDateInToday(day)     { header = "Today" }
            else if cal.isDateInYesterday(day) { header = "Yesterday" }
            else { header = day.mediumString }
            groups.append((header, items))
        }
        return groups
    }
}

// MARK: - InjectionRow

private struct InjectionRow: View {
    let injection: SDInjection
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(injection.compoundName)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                HStack(spacing: 8) {
                    Text(String(format: "%.0f mg", injection.doseAmountMg))
                        .font(.caption)
                        .foregroundColor(color.opacity(0.9))
                    if let site = injection.injectionSite {
                        Text("·").foregroundColor(.secondary)
                        Text(site)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Text(timeString(injection.injectedAt))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.trailing, 16)
        }
        .padding(.vertical, 12)
        .background(AppColors.card.opacity(0.5))
    }

    private func timeString(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
}

// MARK: - InjectionCalendarView

private struct InjectionCalendarView: View {
    @ObservedObject var vm: InjectionsViewModel
    @State private var displayedMonth: Date = Date.now.startOfDay

    private var monthDays: [Date?] {
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: displayedMonth)!
        let firstWeekday = cal.component(.weekday, from: firstOfMonth) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for d in range {
            days.append(cal.date(byAdding: .day, value: d - 1, to: firstOfMonth))
        }
        // Pad to complete grid
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private var firstOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: displayedMonth))!
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header row
            HStack {
                Button {
                    displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.left").foregroundColor(.secondary)
                }

                Spacer()
                Text(monthTitle)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()

                Button {
                    displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)

            // Day-of-week labels
            HStack(spacing: 0) {
                ForEach(["S","M","T","W","T","F","S"], id: \.self) { d in
                    Text(d)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)

            // Grid
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(monthDays.indices, id: \.self) { i in
                    if let day = monthDays[i] {
                        DayCell(
                            day: day,
                            injections: vm.injectionsByDay[day] ?? [],
                            colorFor: vm.color(for:)
                        )
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 12)
        .background(AppColors.card)
    }
}

private struct DayCell: View {
    let day: Date
    let injections: [SDInjection]
    let colorFor: (String) -> Color

    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private var dayNum: Int { Calendar.current.component(.day, from: day) }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(AppColors.accent.opacity(0.25))
                        .frame(width: 28, height: 28)
                }
                Text("\(dayNum)")
                    .font(.system(size: 13, weight: isToday ? .bold : .regular))
                    .foregroundColor(isToday ? AppColors.accent : .white)
            }
            // Injection dots (up to 3)
            HStack(spacing: 2) {
                ForEach(injections.prefix(3), id: \.id) { inj in
                    Circle()
                        .fill(colorFor(inj.compoundName))
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 6)
        }
        .frame(height: 40)
    }
}

// MARK: - LogInjectionSheet

struct LogInjectionSheet: View {
    @ObservedObject var vm: InjectionsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        compoundSection
                        dateSection
                        siteSection
                        notesSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle(vm.editingInjection != nil ? "Edit Injection" : "Log Injection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { vm.saveForm() }
                        .foregroundColor(AppColors.accent)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var compoundSection: some View {
        SectionCard(title: "Compound") {
            if !vm.activeProtocols.isEmpty {
                Picker("Compound", selection: $vm.formCompoundName) {
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
                Picker("Compound", selection: $vm.formCompoundName) {
                    ForEach(["Testosterone Cypionate", "Testosterone Enanthate",
                             "Testosterone Propionate", "HCG"], id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppColors.accent)
            }

            Divider().background(Color.white.opacity(0.07))

            HStack {
                Text("Dose")
                Spacer()
                TextField("mg", text: $vm.formDoseMg)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("mg").foregroundColor(.secondary)
            }
        }
    }

    private var dateSection: some View {
        SectionCard(title: "Date & Time") {
            DatePicker("When", selection: $vm.formDate, in: ...Date.now)
                .tint(AppColors.accent)
        }
    }

    private var siteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Injection Site")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            InjectionSitePicker(
                selectedSite: $vm.formSite,
                recentInjections: vm.recentInjectionsForSiteRotation
            )
        }
    }

    private var notesSection: some View {
        SectionCard(title: "Notes (optional)") {
            TextField("Any notes about this injection…", text: $vm.formNotes, axis: .vertical)
                .lineLimit(3...6)
        }
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            content()
        }
        .padding(14)
        .background(AppColors.card)
        .cornerRadius(12)
    }
}
