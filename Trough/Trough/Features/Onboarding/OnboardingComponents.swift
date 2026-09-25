import SwiftUI

// Shared building blocks for the onboarding flow (1.4 design system restyle).
// Everything here is presentation only — step logic and validation live in
// OnboardingView.swift / OnboardingViewModel.

// MARK: - Localization

/// 1.4 onboarding/paywall string lookup. The English copy doubles as the
/// fallback so an untranslated locale shows English, never the raw key.
/// en.lproj carries the same strings under "// MARK: 1.4 onboarding-paywall".
func onbLoc(_ key: String, _ english: String) -> String {
    NSLocalizedString(key, tableName: nil, bundle: .main, value: english, comment: "")
}

// MARK: - Icon tile

/// Rounded-square gradient tile holding an SF Symbol (feature rows, step headers).
struct OnboardingIconTile: View {
    let systemImage: String
    var colors: [Color] = TR.Gradients.ctaColors
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center))
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            Image(systemName: systemImage)
                .font(.system(size: size * 0.44, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: (colors.last ?? TR.Palette.coral).opacity(0.35), radius: size * 0.2, y: size * 0.08)
        .accessibilityHidden(true)
    }
}

/// Gradient pairs for icon tiles, keyed by feature family.
enum OnboardingTint {
    static let coral: [Color] = TR.Gradients.ctaColors
    static let gold: [Color] = [TR.Palette.gold, TR.Palette.tangerine]
    static let teal: [Color] = [TR.Palette.teal, Color(trHex: 0x1A9E95)]
    static let sky: [Color] = [TR.Palette.sky, Color(trHex: 0x2D7FF9)]
    static let lilac: [Color] = [TR.Palette.lilac, Color(trHex: 0x5B4FD6)]
    static let mint: [Color] = [TR.Palette.mint, Color(trHex: 0x14A37F)]
}

// MARK: - Progress bar

/// Step progress: coral gradient capsule bar with a "Step N of M" kicker.
struct OnboardingProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TRKicker(Text(String(format: onbLoc("onb14.stepOf", "Step %1$d of %2$d"), min(current, total), total)))
            TRProgressBar(
                value: Double(current) / Double(max(total, 1)),
                height: 6,
                colors: [TR.Palette.coral, TR.Palette.tangerine, TR.Palette.gold]
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(format: onbLoc("onb14.stepOf", "Step %1$d of %2$d"), min(current, total), total)))
    }
}

// MARK: - Step container

/// Standard onboarding step: optional icon tile, rounded display title, subtitle, scrolling
/// content, and a pinned primary CTA (+ optional back link) at the bottom.
struct OnboardingStepContainer<Content: View>: View {
    let title: String
    let subtitle: String
    var systemImage: String? = nil
    var tint: [Color] = OnboardingTint.coral
    @ViewBuilder let content: () -> Content
    let primaryLabel: String
    let onPrimary: () -> Void
    var showBack: Bool = false
    var onBack: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 12) {
                    if let systemImage {
                        OnboardingIconTile(systemImage: systemImage, colors: tint, size: 48)
                            .trPopOnAppear()
                    }
                    Text(title)
                        .font(TR.Font.display(.title, weight: .black))
                        .foregroundStyle(TR.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(TR.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .trRevealOnAppear()

                content()
                    .trRevealOnAppear(delay: 0.08)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                Button(action: onPrimary) {
                    Text(primaryLabel)
                }
                .buttonStyle(.trPrimary)

                if showBack, let back = onBack {
                    Button(action: back) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.caption.weight(.bold))
                            Text(NSLocalizedString("common.back", comment: ""))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TR.Palette.textSecondary)
                        .frame(minHeight: TR.Metrics.minTap)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 6)
            .background {
                LinearGradient(
                    colors: [TR.Palette.background.opacity(0), TR.Palette.background.opacity(0.92), TR.Palette.background],
                    startPoint: .top, endPoint: .center
                )
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Option card

/// Tappable card with an icon tile, title and subtitle. `isSelected == nil` shows a chevron
/// (navigation); a Bool shows a selection check and a coral ring when selected.
struct OnboardingOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var tint: [Color] = OnboardingTint.coral
    var isSelected: Bool? = nil
    let onTap: () -> Void

    private var selected: Bool { isSelected == true }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                OnboardingIconTile(systemImage: icon, colors: (isSelected == false) ? [TR.Palette.surfaceRaised, TR.Palette.deepBlue] : tint, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(TR.Font.display(.headline, weight: .bold))
                        .foregroundStyle(TR.Palette.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(TR.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if let isSelected {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? TR.Palette.coral : TR.Palette.textTertiary)
                        .contentTransition(.symbolEffect(.replace))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(TR.Palette.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .trCard(tint: selected ? TR.Palette.coral : nil, padding: 14)
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: TR.Metrics.cardRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [TR.Palette.coralLight, TR.Palette.coral, TR.Palette.tangerine],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5
                        )
                }
            }
        }
        .buttonStyle(.trPressable)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Form card

/// Card with a kicker title for grouped form rows (pickers, dose fields, date pickers).
struct OnboardingFormCard<Content: View>: View {
    let title: String
    var systemImage: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TR.Palette.coral)
                        .accessibilityHidden(true)
                }
                TRKicker(Text(verbatim: title))
            }
            content()
                .foregroundStyle(TR.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trCard(padding: 14)
    }
}

/// Hairline divider for inside form cards.
struct OnboardingDivider: View {
    var body: some View {
        Rectangle()
            .fill(TR.Palette.hairline)
            .frame(height: 1)
    }
}

// MARK: - Chips

/// Selectable capsule chip (compounds).
struct OnboardingChip: View {
    let name: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.heavy))
                        .transition(.scale.combined(with: .opacity))
                }
                Text(name)
                    .font(.subheadline.weight(isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? .white : TR.Palette.textPrimary)
            .background {
                if isSelected {
                    Capsule().fill(LinearGradient(colors: TR.Gradients.ctaColors, startPoint: .top, endPoint: .bottom))
                } else {
                    Capsule().fill(TR.Palette.surfaceRaised)
                }
            }
            .overlay(Capsule().strokeBorder(.white.opacity(isSelected ? 0.22 : 0.08), lineWidth: 1))
            .shadow(color: isSelected ? TR.Palette.coral.opacity(0.35) : .clear, radius: 8, y: 3)
            .frame(minHeight: TR.Metrics.minTap)
            .contentShape(Capsule())
        }
        .buttonStyle(.trPressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Weekday toggle (Mon/Thu injection days, custom reminder days).
struct OnboardingDayChip: View {
    let name: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(name)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 34)
                .foregroundStyle(isSelected ? .white : TR.Palette.textSecondary)
                .background {
                    if isSelected {
                        Capsule().fill(LinearGradient(colors: TR.Gradients.ctaColors, startPoint: .top, endPoint: .bottom))
                    } else {
                        Capsule().fill(TR.Palette.background)
                    }
                }
                .overlay(Capsule().strokeBorder(.white.opacity(isSelected ? 0.2 : 0.06), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.trPressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Metric slider

/// 1–5 check-in slider row with an SF Symbol tile (no emoji).
struct OnboardingMetricSlider: View {
    let systemImage: String
    let tint: [Color]
    let label: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                OnboardingIconTile(systemImage: systemImage, colors: tint, size: 30)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TR.Palette.textPrimary)
                Spacer()
                Text("\(Int(value))")
                    .font(TR.Font.number(.title3))
                    .foregroundStyle(tint.first ?? TR.Palette.coral)
                    .contentTransition(.numericText(value: value))
                    .animation(TR.Motion.snappy, value: value)
            }
            Slider(value: $value, in: 1...5, step: 1)
                .tint(tint.first ?? TR.Palette.coral)
                .accessibilityLabel(Text(label))
        }
    }
}

// MARK: - Feature row

/// Icon tile + title + detail row (HealthKit data points, Pro features).
struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let detail: String
    var tint: [Color] = OnboardingTint.coral

    var body: some View {
        HStack(spacing: 14) {
            OnboardingIconTile(systemImage: icon, colors: tint, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TR.Palette.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Flow layout

/// Simple wrapping layout for chips.
struct OnboardingFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

// MARK: - Protocol Passport

/// The user's "Protocol Passport": a rank-cover card showing level, cover and badge count.
/// Celebrates logging/consistency only — never doses, compounds or lab values.
struct OnboardingPassportCard: View {
    var level: Int = 1
    var levelName: String = GamificationCatalog.levelName(1)
    var badgesEarned: Int = 0
    var totalBadges: Int = GamificationCatalog.badges.count

    private var cover: TR.RankCover { .forLevel(level) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: TR.Metrics.cardRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    TRKicker(Text(onbLoc("onb14.passport.kicker", "Protocol Passport")), color: cover.ink.opacity(0.7))
                    Text(verbatim: "TROUGH")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(cover.ink.opacity(0.45))
                }
                Spacer()
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(cover.ink.opacity(0.75))
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 12)

            Text(String(format: onbLoc("onb14.passport.levelCover", "Level %1$d · %2$@"), level, cover.displayName))
                .font(TR.Font.display(30, weight: .black))
                .foregroundStyle(cover.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(levelName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(cover.ink.opacity(0.65))

            Spacer(minLength: 14)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    TRKicker(Text(onbLoc("onb14.passport.badges", "Badges")), color: cover.ink.opacity(0.6))
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(badgesEarned)")
                            .font(TR.Font.number(28))
                        Text(verbatim: "/\(totalBadges)")
                            .font(TR.Font.number(16, weight: .heavy))
                            .opacity(0.55)
                    }
                    .foregroundStyle(cover.ink)
                }
                Spacer()
                // Stamp slots: the first few badge spaces, still empty.
                HStack(spacing: -6) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .strokeBorder(cover.ink.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                            .background(Circle().fill(cover.ink.opacity(0.05)))
                            .frame(width: 30, height: 30)
                            .overlay {
                                if i == 0 {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .heavy))
                                        .foregroundStyle(cover.ink.opacity(0.35))
                                }
                            }
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .aspectRatio(1.586, contentMode: .fit)
        .background {
            ZStack {
                shape.fill(cover.gradient)
                TRDotGrid(spacing: 14, dotSize: 1.6, color: cover.ink, opacity: 0.08)
                    .clipShape(shape)
                // Wave motif across the card.
                PassportWave()
                    .stroke(cover.ink.opacity(0.12), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .padding(.vertical, 40)
                    .clipShape(shape)
                shape.fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
            }
        }
        .overlay(shape.strokeBorder(.white.opacity(0.55), lineWidth: 1))
        .holoSheen()
        .shadow(color: .black.opacity(0.4), radius: 24, y: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(onbLoc("onb14.passport.kicker", "Protocol Passport")))
        .accessibilityValue(Text(String(format: onbLoc("onb14.passport.a11y", "Level %1$d, %2$@. %3$d of %4$d badges."),
                                        level, cover.displayName, badgesEarned, totalBadges)))
    }
}

/// A PK-style wave with a trough — the brand motif — drawn across the passport.
private struct PassportWave: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let steps = 60
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let x = rect.minX + rect.width * t
            let y = rect.midY + rect.height * 0.35 * sin(t * .pi * 2.6 + 0.6) * (1 - 0.3 * t)
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        return p
    }
}

/// First-value moment shown after setup, before the trial prompt: the user's new
/// Protocol Passport and their first badge (earned by the check-in onboarding just saved;
/// it unlocks and celebrates on the first app load).
struct OnboardingPassportReveal: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var confetti = 0

    private var firstBadge: BadgeDef? {
        GamificationCatalog.badges.first { $0.metric == .checkins && !$0.isSecret }
    }

    var body: some View {
        ZStack {
            TRBackground(glow: TR.Palette.gold, glowOpacity: 0.16)
            GlowBackdrop(colors: [TR.Palette.coral, TR.Palette.lilac, TR.Palette.gold], intensity: 0.22)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 22) {
                        VStack(spacing: 8) {
                            TRKicker(Text(onbLoc("onb14.passport.ready", "You're all set")), color: TR.Palette.gold)
                            Text(onbLoc("onb14.passport.title", "Your Protocol Passport"))
                                .font(TR.Font.display(.largeTitle, weight: .black))
                                .foregroundStyle(TR.Palette.textPrimary)
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)
                            Text(onbLoc("onb14.passport.subtitle", "Every check-in, injection log and streak earns XP and stamps a badge into your passport."))
                                .font(.subheadline)
                                .foregroundStyle(TR.Palette.textSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .trRevealOnAppear()

                        OnboardingPassportCard()
                            .rotation3DEffect(.degrees(reduceMotion ? 0 : -4), axis: (x: 1, y: 0, z: 0))
                            .trPopOnAppear(delay: 0.15)

                        if let badge = firstBadge {
                            HStack(spacing: 14) {
                                BadgeMedallion(systemImage: badge.symbol, tier: badge.tier, status: .locked, progress: 0, size: 58)
                                VStack(alignment: .leading, spacing: 3) {
                                    TRKicker(Text(onbLoc("onb14.passport.nextUp", "Next up")), color: TR.Palette.gold)
                                    Text(badge.title)
                                        .font(TR.Font.display(.headline, weight: .heavy))
                                        .foregroundStyle(TR.Palette.textPrimary)
                                    Text(onbLoc("onb14.passport.firstBadge", "Earned with the check-in you just logged. It's waiting for you inside."))
                                        .font(.caption)
                                        .foregroundStyle(TR.Palette.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .trCard(tint: TR.Palette.gold, padding: 14)
                            .accessibilityElement(children: .combine)
                            .trRevealOnAppear(delay: 0.35)
                        }

                        HStack(spacing: 8) {
                            TRPill(Text(onbLoc("onb14.passport.pillLevels", "11 levels")), systemImage: "chart.bar.fill", tint: TR.Palette.coral)
                            TRPill(Text(String(format: onbLoc("onb14.passport.pillBadges", "%d badges"), GamificationCatalog.badges.count)), systemImage: "rosette", tint: TR.Palette.gold)
                            TRPill(Text(onbLoc("onb14.passport.pillStreaks", "Streaks")), systemImage: "flame.fill", tint: TR.Palette.tangerine)
                        }
                        .trRevealOnAppear(delay: 0.45)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 36)
                    .padding(.bottom, 16)
                }

                Button(action: onContinue) {
                    Text(NSLocalizedString("common.continue", comment: ""))
                }
                .buttonStyle(.trPrimary)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .trRevealOnAppear(delay: 0.55)
            }
        }
        .overlay { ConfettiBurst(trigger: confetti, origin: UnitPoint(x: 0.5, y: 0.3), count: 90) }
        .sensoryFeedback(.success, trigger: confetti)
        .onAppear { confetti += 1 }
        // The reminders step may have raised the notification prompt over this screen;
        // throw one more burst once it's dismissed so the moment isn't lost behind it.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, confetti == 1 { confetti += 1 }
        }
    }
}
