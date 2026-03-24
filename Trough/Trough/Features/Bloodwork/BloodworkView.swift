import SwiftUI
import SwiftData

// MARK: - BloodworkView

struct BloodworkView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userIDString") private var userIDString = UUID().uuidString
    @StateObject private var vm: BloodworkViewModel

    enum Tab { case results, trends }
    @State private var selectedTab: Tab = .results

    init() {
        let id = SupabaseService.resolvedUserUUID ?? UUID() // FIXED: use real Supabase user ID
        _vm = StateObject(wrappedValue: BloodworkViewModel(
            modelContext: ModelContext(try! ModelContainer(for: Schema(TroughSchemaV1.models))),
            userID: id
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segmented tab control
                    Picker("View", selection: $selectedTab) {
                        Text("Results").tag(Tab.results)
                        Text("Trends").tag(Tab.trends)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
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
            .navigationTitle("Bloodwork")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { vm.prepareAddForm() } label: {
                        Image(systemName: "plus")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .sheet(isPresented: $vm.showingEntrySheet, onDismiss: { vm.load() }) {
                BloodworkEntryView(vm: vm)
            }
            .onAppear { vm.load() }
        }
    }

    // MARK: Results tab

    @ViewBuilder
    private var resultContent: some View {
        if vm.results.isEmpty {
            emptyState
        } else {
            List {
                ForEach(vm.results) { bw in
                    NavigationLink(destination: BloodworkDetailView(bloodwork: bw, vm: vm)) {
                        BloodworkRowView(bloodwork: bw)
                    }
                    .listRowBackground(AppColors.card)
                }
                .onDelete { offsets in offsets.forEach { vm.delete(vm.results[$0]) } }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "drop.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.accent.opacity(0.5))
            Text("No bloodwork recorded")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Log your first panel to start tracking trends.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Add Results") { vm.prepareAddForm() }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - BloodworkRowView

struct BloodworkRowView: View {
    let bloodwork: SDBloodwork

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(bloodwork.drawnAt.mediumString)
                    .font(.subheadline.bold())
                Spacer()
                if let lab = bloodwork.labName {
                    Text(lab)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            // Key marker preview
            let keyMarkers = bloodwork.markers.filter {
                ["Total Testosterone", "Free Testosterone", "Estradiol (E2)"].contains($0.markerName)
            }
            if !keyMarkers.isEmpty {
                HStack(spacing: 8) {
                    ForEach(keyMarkers, id: \.id) { m in
                        let inRange = (m.referenceRangeLow.map { m.value >= $0 } ?? true)
                            && (m.referenceRangeHigh.map { m.value <= $0 } ?? true)
                        HStack(spacing: 3) {
                            Circle()
                                .fill(inRange ? Color(hex: "#27AE60") : AppColors.accent)
                                .frame(width: 6, height: 6)
                            Text("\(m.markerName.split(separator: " ").first ?? "") \(Int(m.value))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("\(bloodwork.markers.count) markers")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
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
            AppColors.background.ignoresSafeArea()
            List {
                // Photo (if uploaded)
                if let urlString = bloodwork.photoURL, let url = URL(string: urlString) {
                    Section {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .scaledToFit()
                                    .cornerRadius(10)
                            case .failure:
                                Label("Photo unavailable", systemImage: "photo.slash")
                                    .foregroundColor(.secondary)
                            default:
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 60)
                            }
                        }
                    }
                    .listRowBackground(AppColors.card)
                }

                // Marker sections
                ForEach(groupedMarkers, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.markers, id: \.id) { marker in
                            BloodworkMarkerRow(marker: marker)
                        }
                    }
                    .listRowBackground(AppColors.card)
                }

                // Notes
                if let notes = bloodwork.notes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(AppColors.card)
                }

                Section {
                    DisclaimerBanner(type: .bloodwork)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(bloodwork.drawnAt.mediumString)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    vm.prepareEditForm(bloodwork)
                } label: {
                    Text("Edit")
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

// MARK: - BloodworkMarkerRow

struct BloodworkMarkerRow: View {
    let marker: SDBloodworkMarker

    var inRange: Bool? {
        guard let low = marker.referenceRangeLow, let high = marker.referenceRangeHigh else { return nil }
        return marker.value >= low && marker.value <= high
    }

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                if let inRange {
                    Circle()
                        .fill(inRange ? Color(hex: "#27AE60") : AppColors.accent)
                        .frame(width: 8, height: 8)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(marker.markerName)
                        .font(.subheadline)
                    if let low = marker.referenceRangeLow, let high = marker.referenceRangeHigh {
                        Text("Ref: \(low, specifier: "%.1f")–\(high, specifier: "%.1f") \(marker.unit)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.1f", marker.value))
                    .font(.subheadline.bold())
                    .foregroundColor(inRange == false ? AppColors.accent : .white)
                Text(marker.unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
