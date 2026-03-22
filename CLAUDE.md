# Trough — TRT & Hormone Tracking App

## What This Is
iOS app (SwiftUI, iOS 17+) for tracking TRT protocols, daily wellness,
HealthKit data, bloodwork, and peptides. Offline-first architecture.

## Architecture Rules
- SwiftData is the PRIMARY data store. All reads from SwiftData.
- All writes go to SwiftData first, then sync to Supabase in background.
- The app MUST work fully offline.
- MVVM pattern. Views never call Supabase directly.

## Naming Conventions
- SwiftData models prefixed with SD: SDCheckin, SDInjection, SDProtocol, etc.
- Services are singletons: HealthKitService.shared, SyncEngine.shared, etc.
- Features organized by folder: Features/DailyCheckin/, Features/Dashboard/, etc.

## Key Technical Decisions
- Protocol Score formula: ((raw - 1.0) / 4.0) * 100 where raw is weighted avg of 5 metrics (1-5).
- PK curve uses Bateman function with absorption delay (default ON).
- Sync conflict resolution: last-write-wins + log both versions to SDSyncConflict.
- Schema versioning: SwiftData VersionedSchema. Never delete/rename fields.
- All synced records have updated_at, set on every local write.

## Color Scheme
- Background: #1A1A2E
- Accent: #E94560
- Cards: #16213E
- Secondary: #0F3460

## Do NOT
- Store computed values (cycle day, days since injection). Always derive at read time.
- Sync sample data to Supabase (is_sample_data == true records stay local).
- Make health claims. Use DisclaimerService on every PK/insight/score/bloodwork screen.
- Use HealthKit on simulator for real testing. Always test on device.
