# Trough 1.4 — Design & Gamification Spec

Reference quality bar: /Users/robgoldstein/Desktop/PlacesIveVisited (READ-ONLY; never modify the four reference folders: PlacesIveVisited, PlacesKit, WishLock, PlacesIveHadSex).

## Brand concept
"Night lab, coral pulse." Dark-first. The app is named after the *trough* — the low point of a PK curve. Visual motifs: glowing wave curves, a white-hot dot at the trough, coral→gold gradients on deep navy.

## Tokens (implemented in `Trough/Trough/DesignSystem/TroughTheme.swift` as `enum TR`)
Keep `AppColors` working (it forwards to these) — never break existing call sites.

Palette (hex):
- abyss        #0B0C1E   deepest background (top of screen gradient)
- background   #1A1A2E   existing
- surface      #16213E   existing card
- surfaceRaised #1E2B52  raised card / pills
- deepBlue     #0F3460   existing secondary
- hairline     white @ 8%
- coral        #E94560   primary accent (existing)
- coralLight   #FF7A6B   CTA gradient top stop
- coralDeep    #C2304F
- tangerine    #FF9A4D
- gold         #FFB547   XP, streaks, medals, highlight
- teal         #2EC4B6   on-track / healthy logging
- sky          #5AA9FF
- lilac        #9B8CFF
- mint         #34D399   success
- textPrimary  #F4F5FB
- textSecondary #A0A0C0
- textTertiary  #6E739B

Gradients:
- `cta`: coralLight → coral (top → bottom)
- `sunset` (hero/share): #0F3460 → #5B2A6E → #E94560 → #FF9A4D (top → bottom)
- `screen`: abyss → background (top → bottom), used as app-wide background with a faint radial coral glow at top
- `xp`: gold → tangerine
- Rank covers (derived from level; 11 levels):
  - L1–2 Paper    #E8E1D3 → #CFC6B4 (ink #3A3326)
  - L3–4 Bronze   #D9955B → #8C5A2E (ink #2B1A0C)
  - L5–6 Silver   #E7ECF2 → #9AA4B2 (ink #1E2530)
  - L7–8 Gold     #FFD27A → #E0A23F (ink #3A2600)
  - L9–10 Platinum #C9F1FF → #7FB6D9 (ink #0D2A3A)
  - L11 Diamond   #7CF3FF → #9B8CFF → #FF7AC6 (ink #120A2E)

Typography:
- Display & numbers: SF Pro Rounded (`.system(..., design: .rounded)`), weights .heavy/.black; numbers `.monospacedDigit()`.
- Kicker: caption, .heavy, uppercase, tracking 1.2, textSecondary or tint.
- Body: system default with Dynamic Type (use text styles, not fixed sizes, for body text).

Metrics: gutter 16, cardRadius 22 (continuous), controlRadius 14, sectionSpacing 24, minTap 44.

Motion (`TR.Motion`): pop = spring(response 0.42, damping 0.52); press = spring(0.22, 0.6); snappy = .snappy(0.28); gentle = easeInOut(0.35). Always respect Reduce Motion.

## Components (`Trough/Trough/DesignSystem/*.swift`)
- `TRBackground` — screen gradient + radial coral glow at top + subtle dot grid (very low alpha).
- `.trCard(tint:)` — surface fill, continuous radius 22, hairline stroke, radial tint glow in top-leading corner (tint @0.22, radius 260).
- `TRPrimaryButtonStyle` (gradient capsule, min height 54, heavy rounded, press scale 0.98) and `TRSecondaryButtonStyle`.
- `TRKicker`, `TRPill`/`TRChip` (icon + text capsule on surfaceRaised), `TRSectionHeader`.
- `TRRing` — progress ring with AngularGradient stroke + glow, center content slot.
- `CountUp` numeric text, `Reveal` appear animation.
- `ConfettiBurst` (seeded, deterministic, Canvas) + `SplitMix64`.
- `HoloSheen` modifier, `GlowBackdrop`.
- `BadgeMedallion` (progress ring + gradient disc + SF Symbol; locked = dashed ring; secret = "?").
- `TRToast` center.

## Gamification rules (health-app safe)
Celebrate LOGGING, CONSISTENCY and ADHERENCE. Never celebrate or rank lab values, hormone levels, weight changes or symptom outcomes. No health claims in any copy. Share cards show counts/ranks/streaks only — never doses, compounds, lab values, or scores tied to health outcomes.
