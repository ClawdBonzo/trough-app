import SwiftUI
import SwiftData

// MARK: - ExportDataView

/// Sheet listing local export options. Files are generated on-device and
/// handed to the system share sheet — nothing is uploaded anywhere.
struct ExportDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var showPaywall = false
    @State private var generatingOption: ExportOption? = nil
    @State private var shareFile: ExportFile? = nil
    @State private var errorMessage: String? = nil

    private struct ExportFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    private enum ExportOption: String, Identifiable {
        case checkinsCSV, bloodworkCSV, doctorPDF
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TRBackground(glow: TR.Palette.sky)

                ScrollView {
                    VStack(spacing: 14) {
                        HStack(spacing: 14) {
                            GlassIconTile(systemImage: "square.and.arrow.up.fill", tint: TR.Palette.sky, size: 48, filled: true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("export.hero.title", value: "Your data, your files", comment: "Export screen hero title"))
                                    .font(TR.Font.display(.title3))
                                    .foregroundStyle(TR.Palette.textPrimary)
                                Text(NSLocalizedString("export.hero.subtitle", value: "Generated on this device, shared only where you choose.", comment: "Export screen hero subtitle"))
                                    .font(.subheadline)
                                    .foregroundStyle(TR.Palette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .trCard(tint: TR.Palette.sky)

                        exportRow(
                            option: .checkinsCSV,
                            icon: "checkmark.circle.fill",
                            tint: TR.Palette.teal,
                            title: NSLocalizedString("export.checkins.title", comment: ""),
                            subtitle: NSLocalizedString("export.checkins.subtitle", comment: ""),
                            locked: false
                        )

                        exportRow(
                            option: .bloodworkCSV,
                            icon: "drop.fill",
                            tint: TR.Palette.coral,
                            title: NSLocalizedString("export.bloodwork.title", comment: ""),
                            subtitle: NSLocalizedString("export.bloodwork.subtitle", comment: ""),
                            locked: false
                        )

                        exportRow(
                            option: .doctorPDF,
                            icon: "doc.richtext.fill",
                            tint: TR.Palette.gold,
                            title: NSLocalizedString("export.doctor.title", comment: ""),
                            subtitle: NSLocalizedString("export.doctor.subtitle", comment: ""),
                            locked: !subscriptionManager.isSubscribed
                        )

                        // Sensitive-data note
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "hand.raised.fill")
                                .font(.caption)
                                .foregroundStyle(TR.Palette.textTertiary)
                            Text(NSLocalizedString("export.sensitiveNote", comment: ""))
                                .font(.caption)
                                .foregroundStyle(TR.Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)

                        DisclaimerBanner(type: .bloodwork)
                    }
                    .padding(.horizontal, TR.Metrics.gutter)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle(NSLocalizedString("export.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("common.done", comment: "")) { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(TR.Palette.coral)
                }
            }
            .sheet(item: $shareFile, onDismiss: {
                // The user just generated and shared an export — a good moment
                // to ask for a review. Once-per-trigger makes this first-time only.
                ReviewPromptService.shared.requestIfAppropriate(trigger: "firstExport")
            }) { file in
                ShareSheet(items: [file.url])
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert(NSLocalizedString("export.failed", comment: ""), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(NSLocalizedString("common.ok", comment: ""), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: Row

    private func exportRow(option: ExportOption,
                           icon: String,
                           tint: Color,
                           title: String,
                           subtitle: String,
                           locked: Bool) -> some View {
        Button {
            if locked {
                showPaywall = true
            } else {
                generate(option)
            }
        } label: {
            HStack(spacing: 12) {
                GlassIconTile(systemImage: icon, tint: tint, size: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(TR.Palette.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(TR.Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                if generatingOption == option {
                    ProgressView()
                        .tint(TR.Palette.coral)
                } else if locked {
                    TRPill(Text(verbatim: "Pro"), systemImage: "lock.fill", tint: TR.Palette.gold)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(TR.Palette.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(TR.Palette.surfaceRaised, in: Circle())
                }
            }
            .trCard(tint: tint, padding: 14)
        }
        .buttonStyle(.trPressable)
        .disabled(generatingOption != nil)
        .accessibilityHint(locked
                           ? NSLocalizedString("Opens Pro free trial", comment: "")
                           : gLoc("export.hint.generate", "Generates the file, then opens the share sheet"))
    }

    // MARK: Generate

    private func generate(_ option: ExportOption) {
        generatingOption = option
        defer { generatingOption = nil }
        do {
            let url: URL
            switch option {
            case .checkinsCSV:
                url = try ExportService.shared.exportCheckinsCSV(context: modelContext)
            case .bloodworkCSV:
                url = try ExportService.shared.exportBloodworkCSV(context: modelContext)
            case .doctorPDF:
                url = try ExportService.shared.generateDoctorReport(context: modelContext)
            }
            shareFile = ExportFile(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
