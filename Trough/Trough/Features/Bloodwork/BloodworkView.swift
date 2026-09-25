import SwiftUI
import SwiftData

// MARK: - BloodworkView

struct BloodworkView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userIDString") private var userIDString = UUID().uuidString
    @StateObject private var vm = BloodworkViewModel()
    @EnvironmentObject private var gamificationVM: GamificationViewModel

    enum Tab: Hashable { case results, trends }
    @State private var selectedTab: Tab = .results
    @State private var showingExportSheet = false
    @State private var pendingDelete: SDBloodwork? = nil

    var body: some View {
        // Always pushed onto a parent NavigationStack (More tab / Dashboard);
        // a nested stack here swallows value-based pushes.
        Group {
            ZStack {
                TRBackground()

                VStack(spacing: 0) {
                    GlassPillPicker(
                        items: [Tab.results, Tab.trends],
                        selection: $selectedTab,
                        title: { $0 == .results ? NSLocalizedString("Results", comment: "") : NSLocalizedString("Trends", comment: "") },
                        scrolls: false
                    )
                    .padding(.vertical, 10)

                    Group {
                        if selectedTab == .results {
                            resultContent
                        } else {
                            BloodworkTrendsView(vm: vm)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("bloodwork.title", comment: ""))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingExportSheet = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(TR.Palette.coral)
                    }
                    .accessibilityLabel("Export data")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { vm.prepareAddForm() } label: {
                        Image(systemName: "plus")
                            .fontWeight(.bold)
                            .foregroundStyle(TR.Palette.coral)
                    }
                    .accessibilityLabel(NSLocalizedString("bloodwork.addPanel", value: "Add panel", comment: "Add a bloodwork panel"))
                }
            }
            .sheet(isPresented: $vm.showingEntrySheet, onDismiss: { vm.load() }) {
                BloodworkEntryView(vm: vm)
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportDataView()
            }
            .confirmationDialog(
                NSLocalizedString("bloodwork.deleteConfirm", value: "Delete this panel?", comment: "Confirm deleting a bloodwork panel"),
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("bloodwork.delete", value: "Delete Panel", comment: "Delete a bloodwork panel"), role: .destructive) {
                    if let bw = pendingDelete { vm.delete(bw) }
                    pendingDelete = nil
                }
            }
            .onAppear {
                let uid = UUID(uuidString: userIDString) ?? UUID()
                vm.setup(context: modelContext, userID: uid)
                vm.gamificationVM = gamificationVM
                vm.load()
            }
        }
    }

    // MARK: Results tab

    @ViewBuilder
    private var resultContent: some View {
        if vm.results.isEmpty {
            ScrollView {
                GlassEmptyState(
                    systemImage: "drop.fill",
                    title: NSLocalizedString("No bloodwork recorded", comment: ""),
                    message: NSLocalizedString("Log your first panel to start tracking trends.", comment: ""),
                    buttonTitle: NSLocalizedString("Add Results", comment: ""),
                    action: { vm.prepareAddForm() }
                )
                .padding(.top, 40)
                DisclaimerBanner(type: .bloodwork)
                    .padding(.horizontal, TR.Metrics.gutter)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    summaryCard
                    ForEach(vm.results) { bw in
                        NavigationLink(destination: BloodworkDetailView(bloodwork: bw, vm: vm)) {
                            BloodworkRowView(bloodwork: bw)
                        }
                        .buttonStyle(.trPressable)
                        .contextMenu {
                            Button {
                                vm.prepareEditForm(bw)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                pendingDelete = bw
                            } label: {
                                Label(NSLocalizedString("bloodwork.delete", value: "Delete Panel", comment: "Delete a bloodwork panel"), systemImage: "trash")
                            }
                        }
                    }
                    DisclaimerBanner(type: .bloodwork)
                        .padding(.top, 4)
                }
                .padding(.horizontal, TR.Metrics.gutter)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: Summary

    private var summaryCard: some View {
        let count = vm.results.count
        let last = vm.results.map(\.drawnAt).max()
        let markerKinds = Set(vm.results.flatMap(\.markers).map(\.markerName)).count
        let photos = vm.results.filter { $0.photoURL != nil }.count
        let panelsText = count == 1
            ? NSLocalizedString("bloodwork.summary.onePanel", value: "1 panel logged", comment: "Bloodwork header, singular")
            : String(format: NSLocalizedString("bloodwork.summary.panels", value: "%d panels logged", comment: "Bloodwork header, plural"), count)
        let lastText = last.map {
            String(format: NSLocalizedString("bloodwork.summary.lastDrawn", value: "last drawn %@", comment: "Bloodwork header: date of last draw"),
                   $0.formatted(.dateTime.month(.abbreviated).day()))
        }

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    TRKicker(Text(NSLocalizedString("bloodwork.summary.kicker", value: "Lab log", comment: "Bloodwork header kicker")),
                             color: TR.Palette.coralLight)
                    Text([panelsText, lastText].compactMap { $0 }.joined(separator: " · "))
                        .font(TR.Font.display(.title3))
                        .foregroundStyle(TR.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                GlassIconTile(systemImage: "drop.fill", tint: TR.Palette.coral, size: 44, filled: true)
            }
            HStack(spacing: 12) {
                GlassStat(value: "\(count)", label: NSLocalizedString("bloodwork.stat.panels", value: "Panels", comment: ""))
                GlassStat(value: "\(markerKinds)", label: NSLocalizedString("bloodwork.stat.markers", value: "Markers tracked", comment: ""))
                GlassStat(value: "\(photos)", label: NSLocalizedString("bloodwork.stat.photos", value: "Lab photos", comment: ""))
            }
        }
        .trCard(tint: TR.Palette.coral)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - BloodworkRowView

/// Panel card: date + lab, photo thumbnail, doctor-notes indicator and a marker chip grid.
struct BloodworkRowView: View {
    let bloodwork: SDBloodwork

    private static let maxChips = 6

    /// Markers in section order (Core first), so the key markers lead.
    private var orderedMarkers: [SDBloodworkMarker] {
        let order = BloodworkViewModel.sections.flatMap(\.defs).map(\.name)
        return bloodwork.markers.sorted {
            (order.firstIndex(of: $0.markerName) ?? Int.max, $0.markerName)
                < (order.firstIndex(of: $1.markerName) ?? Int.max, $1.markerName)
        }
    }

    private var hasDoctorNotes: Bool { !(bloodwork.doctorNotes ?? "").isEmpty }
    private var hasNotes: Bool { !(bloodwork.notes ?? "").isEmpty }

    var body: some View {
        let markers = orderedMarkers
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bloodwork.drawnAt.mediumString)
                        .font(TR.Font.display(.headline))
                        .foregroundStyle(TR.Palette.textPrimary)
                    HStack(spacing: 6) {
                        if let lab = bloodwork.labName, !lab.isEmpty {
                            Label(lab, systemImage: "building.2")
                                .labelStyle(.titleAndIcon)
                        }
                        Text(String(format: NSLocalizedString("bloodwork.markerCount", value: "%d markers", comment: "Number of markers in a panel"), markers.count))
                    }
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textSecondary)
                    .lineLimit(1)

                    if hasDoctorNotes || hasNotes {
                        HStack(spacing: 6) {
                            if hasDoctorNotes {
                                TRPill(Text(NSLocalizedString("bloodwork.doctorNotes", value: "Doctor notes", comment: "Indicator: panel has notes for doctor")),
                                       systemImage: "stethoscope", tint: TR.Palette.sky)
                            }
                            if hasNotes {
                                TRPill(Text(NSLocalizedString("bloodwork.notes", value: "Notes", comment: "Indicator: panel has notes")),
                                       systemImage: "note.text", tint: TR.Palette.textSecondary)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                Spacer(minLength: 8)
                PanelPhotoThumbnail(stored: bloodwork.photoURL)
            }

            if markers.isEmpty {
                Text(String(format: NSLocalizedString("bloodwork.markerCount", value: "%d markers", comment: ""), 0))
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textTertiary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(markers.prefix(Self.maxChips), id: \.id) { m in
                        BloodworkMarkerChip(name: m.markerName, value: m.value, unit: m.unit,
                                            low: m.referenceRangeLow, high: m.referenceRangeHigh)
                    }
                }
            }

            HStack {
                if markers.count > Self.maxChips {
                    Text(String(format: NSLocalizedString("bloodwork.moreMarkers", value: "+%d more", comment: "More markers not shown"), markers.count - Self.maxChips))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TR.Palette.textSecondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text(NSLocalizedString("bloodwork.viewPanel", value: "View panel", comment: "Open bloodwork panel detail"))
                    Image(systemName: "chevron.right").font(.caption2.weight(.heavy))
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(TR.Palette.coralLight)
            }
        }
        .trCard()
        .contentShape(RoundedRectangle(cornerRadius: TR.Metrics.cardRadius, style: .continuous))
    }
}

/// Small rounded thumbnail of the lab-sheet photo (local file only).
private struct PanelPhotoThumbnail: View {
    let stored: String?
    var size: CGFloat = 52

    var body: some View {
        if let url = BloodworkViewModel.photoFileURL(stored) {
            let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    ZStack {
                        TR.Palette.surfaceRaised
                        Image(systemName: "doc.text.image").foregroundStyle(TR.Palette.textTertiary)
                    }
                }
            }
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
            .accessibilityLabel(NSLocalizedString("bloodwork.labPhoto", value: "Lab photo attached", comment: ""))
        }
    }
}

// MARK: - BloodworkDetailView

struct BloodworkDetailView: View {
    let bloodwork: SDBloodwork
    @ObservedObject var vm: BloodworkViewModel

    // Group markers by section order
    private var groupedMarkers: [(title: String, markers: [SDBloodworkMarker])] {
        let sectionTitles = BloodworkViewModel.sections.map(\.title)
        let defNames = BloodworkViewModel.sections.reduce(into: [String: String]()) { dict, sec in
            sec.defs.forEach { dict[$0.name] = sec.title }
        }
        var groups: [String: [SDBloodworkMarker]] = [:]
        for m in bloodwork.markers {
            let section = defNames[m.markerName] ?? "Other"
            groups[section, default: []].append(m)
        }
        return sectionTitles.compactMap { title -> (String, [SDBloodworkMarker])? in
            guard let markers = groups[title], !markers.isEmpty else { return nil }
            return (title, markers)
        }
    }

    var body: some View {
        ZStack {
            TRBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: TR.Metrics.sectionSpacing - 6) {
                    // Header
                    HStack(spacing: 14) {
                        GlassIconTile(systemImage: "drop.fill", tint: TR.Palette.coral, size: 48, filled: true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bloodwork.drawnAt.mediumString)
                                .font(TR.Font.display(.title2))
                                .foregroundStyle(TR.Palette.textPrimary)
                            Text([bloodwork.labName,
                                  String(format: NSLocalizedString("bloodwork.markerCount", value: "%d markers", comment: ""), bloodwork.markers.count)]
                                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundStyle(TR.Palette.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .trCard(tint: TR.Palette.coral)

                    // Photo (if uploaded)
                    if let url = BloodworkViewModel.photoFileURL(bloodwork.photoURL) {
                        GlassSection(NSLocalizedString("bloodwork.labPhotoTitle", value: "Lab photo", comment: "")) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous))
                                case .failure:
                                    Label("Photo unavailable", systemImage: "photo.slash")
                                        .foregroundStyle(TR.Palette.textSecondary)
                                default:
                                    ProgressView()
                                        .frame(maxWidth: .infinity, minHeight: 60)
                                }
                            }
                            .padding(10)
                        }
                    }

                    // Marker sections
                    ForEach(groupedMarkers, id: \.title) { group in
                        GlassSection(group.title) {
                            ForEach(Array(group.markers.enumerated()), id: \.element.id) { idx, marker in
                                if idx > 0 { GlassDivider(leadingInset: 14) }
                                BloodworkMarkerRow(marker: marker)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                            }
                        }
                    }

                    // Notes
                    if let notes = bloodwork.notes, !notes.isEmpty {
                        GlassSection("Notes") {
                            Text(notes)
                                .font(.subheadline)
                                .foregroundStyle(TR.Palette.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                        }
                    }

                    if let doc = bloodwork.doctorNotes, !doc.isEmpty {
                        GlassSection(NSLocalizedString("Notes for Doctor", comment: ""), tint: TR.Palette.sky) {
                            HStack(alignment: .top, spacing: 12) {
                                GlassIconTile(systemImage: "stethoscope", tint: TR.Palette.sky)
                                Text(doc)
                                    .font(.subheadline)
                                    .foregroundStyle(TR.Palette.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(14)
                        }
                    }

                    DisclaimerBanner(type: .bloodwork)
                }
                .padding(.horizontal, TR.Metrics.gutter)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle(bloodwork.drawnAt.mediumString)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    vm.prepareEditForm(bloodwork)
                } label: {
                    Text("Edit")
                        .fontWeight(.semibold)
                        .foregroundStyle(TR.Palette.coral)
                }
            }
        }
    }
}

// MARK: - BloodworkMarkerRow

struct BloodworkMarkerRow: View {
    let marker: SDBloodworkMarker

    private var status: MarkerRangeStatus {
        MarkerRangeStatus(value: marker.value, low: marker.referenceRangeLow, high: marker.referenceRangeHigh)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(marker.markerName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TR.Palette.textPrimary)
                if let low = marker.referenceRangeLow, let high = marker.referenceRangeHigh {
                    Text("Ref: \(low, specifier: "%.1f")–\(high, specifier: "%.1f") \(marker.unit)")
                        .font(.caption2)
                        .foregroundStyle(TR.Palette.textTertiary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.1f", marker.value))
                        .font(TR.Font.number(.headline, weight: .heavy))
                        .foregroundStyle(TR.Palette.textPrimary)
                    Text(marker.unit)
                        .font(.caption2)
                        .foregroundStyle(TR.Palette.textTertiary)
                }
                if status != .unknown {
                    HStack(spacing: 3) {
                        Image(systemName: status.symbol)
                            .font(.system(size: status == .inRange ? 5 : 8, weight: .heavy))
                        Text(status.label)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(status.tint)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
