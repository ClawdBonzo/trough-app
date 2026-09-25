import SwiftUI
import SwiftData

// MARK: - SupplementConfigView

struct SupplementConfigView: View {
    @ObservedObject var vm: SettingsViewModel

    var body: some View {
        ZStack {
            TRBackground()
            List {
                if vm.allSupplements.isEmpty {
                    emptySection
                } else {
                    stackSection
                }
                addSection
                disclaimerSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listRowSeparatorTint(TR.Palette.hairline)
        }
        .navigationTitle(NSLocalizedString("supplements.title", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $vm.showingAddSupplement) {
            SupplementAddSheet(vm: vm)
        }
        .onAppear { vm.load() }
    }

    // MARK: Sections

    private var emptySection: some View {
        Section {
            GlassEmptyState(
                systemImage: "pills.fill",
                title: NSLocalizedString("supplements.noSupplements", comment: ""),
                message: NSLocalizedString("supplements.addHint", comment: ""),
                tint: TR.Palette.teal
            )
            .padding(.vertical, -12)
        }
        .listRowBackground(Color.clear)
    }

    private var stackSection: some View {
        Section(NSLocalizedString("supplements.yourStack", comment: "")) {
            ForEach(vm.allSupplements, id: \.id) { s in
                HStack(spacing: 12) {
                    GlassIconTile(systemImage: "pills.fill", tint: s.isActive ? TR.Palette.teal : TR.Palette.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.supplementName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(s.isActive ? TR.Palette.textPrimary : TR.Palette.textSecondary)
                        Text(doseLabel(s))
                            .font(.caption)
                            .foregroundStyle(TR.Palette.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { s.isActive },
                        set: { _ in vm.toggleSupplementActive(s) }
                    ))
                    .tint(TR.Palette.coral)
                    .labelsHidden()
                }
                .padding(.vertical, 4)
            }
            .onDelete { offsets in
                offsets.forEach { vm.deleteSupplement(vm.allSupplements[$0]) }
            }
        }
        .listRowBackground(TR.Palette.surface)
    }

    private var addSection: some View {
        Section {
            Button {
                vm.prepareAddSupplementForm()
                vm.showingAddSupplement = true
            } label: {
                Label(NSLocalizedString("supplements.addSupplement", comment: ""), systemImage: "plus")
            }
            .buttonStyle(.trPrimary)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    private var disclaimerSection: some View {
        Section {
            DisclaimerBanner(type: .supplementAdvice)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    // MARK: Helper

    private func doseLabel(_ s: SDSupplementConfig) -> String {
        let doseStr = s.doseAmount.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", s.doseAmount)
            : String(format: "%.4g", s.doseAmount)
        let freqStr = s.frequencyDays == 1 ? NSLocalizedString("freq.daily", comment: "") : String(format: NSLocalizedString("unit.daysAgo", comment: ""), s.frequencyDays)
        return "\(doseStr) \(s.doseUnit) · \(freqStr)"
    }
}

// MARK: - SupplementAddSheet

struct SupplementAddSheet: View {
    @ObservedObject var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                TRBackground()
                Form {
                    presetSection
                    doseSection
                }
                .scrollContentBackground(.hidden)
                .tint(TR.Palette.coral)
            }
            .navigationTitle(NSLocalizedString("supplements.addSupplement", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("common.add", comment: "")) { vm.saveSupplement() }
                        .fontWeight(.bold)
                        .foregroundStyle(TR.Palette.coral)
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
    }

    private var presetSection: some View {
        Section(NSLocalizedString("supplements.title", comment: "")) {
            Picker(NSLocalizedString("supplements.preset", comment: ""), selection: $vm.formPresetName) {
                ForEach(SettingsViewModel.presetNames, id: \.self) { name in
                    Text(name == "Custom" ? NSLocalizedString("common.custom", value: "Custom", comment: "") : name)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: vm.formPresetName) { _, name in
                vm.applyPreset(name)
            }

            if vm.formPresetName == "Custom" {
                TextField(NSLocalizedString("supplements.name", comment: ""), text: $vm.formSupplName)
                    .autocorrectionDisabled()
            }
        }
        .listRowBackground(TR.Palette.surface)
    }

    private var doseSection: some View {
        Section(NSLocalizedString("supplements.doseFrequency", comment: "")) {
            HStack {
                TextField(NSLocalizedString("supplements.amount", comment: ""), text: $vm.formSupplDose)
                    .keyboardType(.decimalPad)
                Picker(NSLocalizedString("peptides.unit", comment: ""), selection: $vm.formSupplUnit) {
                    ForEach(["mg", "mcg", "g", "IU"], id: \.self) { Text($0) }
                }
                .pickerStyle(.menu)
            }
            HStack {
                TextField(NSLocalizedString("supplements.every", comment: ""), text: $vm.formSupplFreq)
                    .keyboardType(.numberPad)
                Text(NSLocalizedString("unit.days", comment: "")).foregroundStyle(TR.Palette.textSecondary)
            }
        }
        .listRowBackground(TR.Palette.surface)
    }
}
