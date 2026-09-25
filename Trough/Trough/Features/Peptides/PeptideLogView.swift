import SwiftUI

// MARK: - PeptideLogView

struct PeptideLogView: View {
    @ObservedObject var vm: PeptidesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                TRBackground()
                Form {
                    compoundSection
                    doseSection
                    if vm.formRoute == "subcutaneous" || vm.formRoute == "intramuscular" {
                        siteSection
                    }
                    detailsSection
                    notesSection
                }
                .scrollContentBackground(.hidden)
                .tint(TR.Palette.coral)
            }
            .navigationTitle(vm.editingLog != nil ? NSLocalizedString("peptides.editLog", comment: "") : NSLocalizedString("peptides.logDose", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("common.save", comment: "")) { vm.saveForm() }
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

    // MARK: - Sections

    private var compoundSection: some View {
        Section(NSLocalizedString("peptides.adjunctPeptide", comment: "")) {
            Picker(NSLocalizedString("common.compound", comment: ""), selection: $vm.formCompoundSelection) {
                ForEach(PeptidesViewModel.presetCompounds, id: \.self) { name in
                    Text(name == "Custom" ? NSLocalizedString("common.custom", value: "Custom", comment: "") : name)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: vm.formCompoundSelection) { _, _ in vm.onCompoundChanged() }

            if vm.formCompoundSelection == "Custom" {
                TextField(NSLocalizedString("peptides.compoundName", comment: ""), text: $vm.formCustomName)
                    .autocorrectionDisabled()
            }

            let category = PeptideCategory.of(vm.effectiveCompoundName)
            HStack(spacing: 10) {
                GlassIconTile(systemImage: category.symbol, tint: category.tint, size: 28)
                TRKicker(Text(category.title), color: category.tint)
            }
            .accessibilityElement(children: .combine)
        }
        .listRowBackground(TR.Palette.surface)
    }

    private var doseSection: some View {
        Section(NSLocalizedString("common.dose", comment: "")) {
            HStack {
                TextField(NSLocalizedString("peptides.amount", comment: ""), text: $vm.formDoseAmount)
                    .keyboardType(.decimalPad)
                Spacer()
                Picker(NSLocalizedString("peptides.unit", comment: ""), selection: $vm.formDoseUnit) {
                    ForEach(PeptidesViewModel.doseUnits, id: \.self) { Text(PeptidesViewModel.unitLabel($0)) }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            Picker(NSLocalizedString("peptides.route", comment: ""), selection: $vm.formRoute) {
                ForEach(PeptidesViewModel.routes, id: \.self) { Text(PeptidesViewModel.routeLabel($0)) }
            }
            .pickerStyle(.menu)
            DatePicker(NSLocalizedString("peptides.dateTime", comment: ""), selection: $vm.formDate)
        }
        .listRowBackground(TR.Palette.surface)
    }

    private var siteSection: some View {
        Section(NSLocalizedString("peptides.injectionSite", comment: "")) {
            InjectionSitePicker(selectedSite: $vm.formSite, recentInjections: [])
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    private var detailsSection: some View {
        Section(NSLocalizedString("peptides.details", comment: "")) {
            TextField(NSLocalizedString("peptides.batchLot", comment: ""), text: $vm.formBatch)
                .autocorrectionDisabled()
        }
        .listRowBackground(TR.Palette.surface)
    }

    private var notesSection: some View {
        Section(NSLocalizedString("common.notes", comment: "")) {
            TextEditor(text: $vm.formNotes)
                .frame(minHeight: 60)
                .scrollContentBackground(.hidden)
        }
        .listRowBackground(TR.Palette.surface)
    }
}
