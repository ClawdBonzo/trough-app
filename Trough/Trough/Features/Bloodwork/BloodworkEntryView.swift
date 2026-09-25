import SwiftUI
import PhotosUI

// MARK: - BloodworkEntryView

struct BloodworkEntryView: View {
    @ObservedObject var vm: BloodworkViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var photoImage: UIImage? = nil
    @State private var showCamera = false
    @State private var showPhotoSourcePicker = false
    @State private var editingRangeMarkerIndex: Int? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                TRBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: TR.Metrics.sectionSpacing) {
                        panelInfoSection
                        ForEach(vm.formSections(), id: \.title) { section in
                            markerSection(title: section.title, entries: section.entries)
                        }
                        photoSection
                        notesSection
                        doctorNotesSection
                        DisclaimerBanner(type: .bloodwork)
                    }
                    .padding(.horizontal, TR.Metrics.gutter)
                    .padding(.vertical, 12)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .sheet(isPresented: Binding(
                get: { editingRangeMarkerIndex != nil },
                set: { if !$0 { editingRangeMarkerIndex = nil } }
            )) {
                if let idx = editingRangeMarkerIndex, idx < vm.formMarkers.count {
                    RangeEditSheet(entry: $vm.formMarkers[idx])
                }
            }
            .navigationTitle(vm.editingResult == nil ? "Add Bloodwork" : "Edit Bloodwork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(TR.Palette.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.pendingPhotoData = photoImage?.jpegData(compressionQuality: 0.8)
                        vm.saveForm()
                        if vm.errorMessage == nil { dismiss() }
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(TR.Palette.coral)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView(image: $photoImage)
            }
            .onChange(of: pickerItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        photoImage = img
                    }
                }
            }
            .onAppear {
                // When editing a panel that already has a photo, load it so it
                // displays and can be replaced or removed.
                if photoImage == nil,
                   let data = BloodworkViewModel.loadPhoto(vm.editingResult?.photoURL),
                   let img = UIImage(data: data) {
                    photoImage = img
                }
            }
        }
    }

    // MARK: Panel Info

    private var panelInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TRKicker(Text("Panel Info")).padding(.leading, 6)
            VStack(alignment: .leading, spacing: 14) {
                GlassField(label: NSLocalizedString("Draw Date", comment: ""), systemImage: "calendar") {
                    DatePicker("Draw Date", selection: $vm.formDrawnAt, displayedComponents: .date)
                        .labelsHidden()
                        .tint(TR.Palette.coral)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GlassField(label: NSLocalizedString("bloodwork.entry.lab", value: "Lab", comment: "Lab name field label"), systemImage: "building.2") {
                    TextField("Lab Name (optional)", text: $vm.formLabName)
                }
            }
            .trCard(tint: TR.Palette.coral)
        }
    }

    // MARK: Marker section

    private func markerSection(title: String, entries: [BloodworkViewModel.MarkerEntry]) -> some View {
        GlassSection(title) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                if i > 0 { GlassDivider(leadingInset: 14) }
                markerRow(for: entry)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
        }
    }

    private func markerRow(for entry: BloodworkViewModel.MarkerEntry) -> some View {
        let idx = vm.formMarkers.firstIndex(where: { $0.id == entry.id })

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // In-range indicator (neutral tints)
                Circle()
                    .fill(rangeColor(for: entry))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TR.Palette.textPrimary)
                    HStack(spacing: 4) {
                        Text(verbatim: String(format: gLoc("bloodwork.refRangeShort", "Ref: %.1f–%.1f"), locale: Locale.current,
                                             entry.rangeLow, entry.rangeHigh))
                            .font(.caption2)
                            .foregroundStyle(entry.hasCustomRange ? TR.Palette.teal : TR.Palette.textTertiary)
                        if entry.hasCustomRange {
                            Image(systemName: "pencil.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(TR.Palette.teal)
                        }
                    }
                }

                Spacer(minLength: 8)

                if let i = idx {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        TextField("–", text: $vm.formMarkers[i].value)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(TR.Font.number(.title3, weight: .heavy))
                            .foregroundStyle(TR.Palette.textPrimary)
                            .frame(width: 76)
                        Text(entry.unit)
                            .font(.caption)
                            .foregroundStyle(TR.Palette.textTertiary)
                            .frame(width: 46, alignment: .leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: 48)
                    .background(TR.Palette.surfaceRaised,
                                in: RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous)
                        .strokeBorder(entry.valueDouble == nil ? TR.Palette.hairline : rangeColor(for: entry).opacity(0.4), lineWidth: 1))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(entry.name), \(entry.unit)")
                }
            }

            // Edit reference range button
            if let i = idx {
                Button {
                    editingRangeMarkerIndex = i
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption2)
                        Text("Edit reference range")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(TR.Palette.coralLight.opacity(0.85))
                    .frame(minHeight: 28)
                }
                .buttonStyle(.plain)
                .padding(.leading, 18)
            }
        }
    }

    private func rangeColor(for entry: BloodworkViewModel.MarkerEntry) -> Color {
        guard let v = entry.valueDouble else { return TR.Palette.textTertiary.opacity(0.5) }
        return MarkerRangeStatus(value: v, low: entry.rangeLow, high: entry.rangeHigh).tint
    }

    // MARK: Photo section

    private var photoSection: some View {
        GlassSection("Photo") {
            VStack(alignment: .leading, spacing: 12) {
                if let img = photoImage {
                    HStack(spacing: 12) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 88, height: 66)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))
                        Spacer()
                        Button(role: .destructive) {
                            photoImage = nil
                            pickerItem = nil
                        } label: {
                            Label("Remove", systemImage: "trash")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(TRSecondaryButtonStyle(tint: TR.Palette.textSecondary, fullWidth: false))
                    }
                }

                HStack(spacing: 10) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(TR.Palette.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(TR.Palette.surfaceRaised, in: Capsule())
                            .overlay(Capsule().strokeBorder(TR.Palette.hairline, lineWidth: 1))
                    }

                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .buttonStyle(TRSecondaryButtonStyle())
                }
            }
            .padding(14)
        }
    }

    // MARK: Notes section

    private var notesSection: some View {
        GlassSection("Notes") {
            TextField("Optional notes about this panel...", text: $vm.formNotes, axis: .vertical)
                .lineLimit(3...6)
                .foregroundStyle(TR.Palette.textPrimary)
                .padding(14)
        }
    }

    // MARK: Doctor Notes section

    private var doctorNotesSection: some View {
        GlassSection(NSLocalizedString("Notes for Doctor", comment: ""),
                     footer: NSLocalizedString("Included in your exported report for doctor visits.", comment: ""),
                     tint: TR.Palette.sky) {
            HStack(alignment: .top, spacing: 12) {
                GlassIconTile(systemImage: "stethoscope", tint: TR.Palette.sky)
                TextField("Notes for your doctor about this panel...", text: $vm.formDoctorNotes, axis: .vertical)
                    .lineLimit(3...8)
                    .foregroundStyle(TR.Palette.textPrimary)
                    .padding(.top, 5)
            }
            .padding(14)
        }
    }
}

// MARK: - RangeEditSheet

struct RangeEditSheet: View {
    @Binding var entry: BloodworkViewModel.MarkerEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                TRBackground()
                Form {
                    Section {
                        Text(entry.name)
                            .font(.headline)
                            .foregroundStyle(TR.Palette.textPrimary)
                        Text(verbatim: String(format: gLoc("bloodwork.defaultRange", "Default: %.1f–%.1f %@"), locale: Locale.current,
                                             entry.defaultRangeLow, entry.defaultRangeHigh, entry.unit))
                            .font(.caption)
                            .foregroundStyle(TR.Palette.textSecondary)
                    }
                    .listRowBackground(TR.Palette.surface)

                    Section("Your Lab's Reference Range") {
                        HStack {
                            Text("Low")
                                .foregroundStyle(TR.Palette.textSecondary)
                            Spacer()
                            TextField(String(format: "%.1f", entry.defaultRangeLow), text: $entry.customRangeLow)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .foregroundStyle(TR.Palette.textPrimary)
                            Text(entry.unit)
                                .font(.caption)
                                .foregroundStyle(TR.Palette.textSecondary)
                                .frame(width: 52, alignment: .leading)
                        }
                        HStack {
                            Text("High")
                                .foregroundStyle(TR.Palette.textSecondary)
                            Spacer()
                            TextField(String(format: "%.1f", entry.defaultRangeHigh), text: $entry.customRangeHigh)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .foregroundStyle(TR.Palette.textPrimary)
                            Text(entry.unit)
                                .font(.caption)
                                .foregroundStyle(TR.Palette.textSecondary)
                                .frame(width: 52, alignment: .leading)
                        }
                    }
                    .listRowBackground(TR.Palette.surface)

                    if entry.hasCustomRange {
                        Section {
                            Button("Reset to Default") {
                                entry.customRangeLow = ""
                                entry.customRangeHigh = ""
                            }
                            .foregroundStyle(TR.Palette.coral)
                        }
                        .listRowBackground(TR.Palette.surface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Reference Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(TR.Palette.coral)
                }
            }
        }
    }
}

// MARK: - CameraPickerView

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uvc: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
