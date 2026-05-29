# Trough — TRT & Hormone Tracking App

## What This Is
iOS app (SwiftUI, iOS 17+) for tracking TRT protocols, daily wellness,
HealthKit data, bloodwork, and peptides. Fully on-device and private —
no account, no backend, no network sync.

## Architecture Rules
- SwiftData is the ONLY data store. All data lives on-device.
- There is no backend, no account, and no network sync. Nothing is uploaded.
- The app works fully offline by design (there is nothing online to reach).
- MVVM pattern. Views talk to ViewModels, never to the data store directly.

## Naming Conventions
- SwiftData models prefixed with SD: SDCheckin, SDInjection, SDProtocol, etc.
- Services are singletons: HealthKitService.shared, etc.
- Features organized by folder: Features/DailyCheckin/, Features/Dashboard/, etc.

## Key Technical Decisions
- Protocol Score formula: ((raw - 1.0) / 4.0) * 100 where raw is weighted avg of 5 metrics (1-5).
- PK curve uses Bateman function with absorption delay (default ON).
- Schema versioning: SwiftData VersionedSchema. Never delete/rename fields.

## Color Scheme
- Background: #1A1A2E
- Accent: #E94560
- Cards: #16213E
- Secondary: #0F3460

## Do NOT
- Store computed values (cycle day, days since injection). Always derive at read time.
- Add any network/backend/analytics/tracking. The app is strictly on-device.
- Make health claims. Use DisclaimerService on every PK/insight/score/bloodwork screen.
- Use HealthKit on simulator for real testing. Always test on device.
