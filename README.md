 # Voice Journal — On-Device AI Voice Diary
 
 Privacy-first voice journal. **All processing on-device — $0 running cost.**
 
 **Price:** $4.99 one-time purchase. **Break-even:** 24 sales covers the $99/year developer account.
 
 ## What Changed (Code Review Fixes)
 
 | # | Severity | Issue | File | Fix |
 |---|---|---|---|---|
 | 1 | **P0** | Audio playback silent | JournalDetailView | Added `AVAudioSession.setCategory(.playback)` before play |
 | 2 | **P0** | Audio player leaks across entries | JournalDetailView | `onDisappear` stops player + sets nil + deactivates session |
 | 3 | **P1** | Widget creates Core Data container every refresh | VoiceJournalWidget | Static `NSPersistentContainer` cache |
 | 4 | **P1** | StatsViewModel uses independent StorageService | StatsView, StatsViewModel | Shares `journalVM.storage` |
 | 5 | **P2** | 44100Hz sample rate overkill for speech | AudioRecorder | Reduced to 22050Hz (50% smaller files) |
 | 6 | **P2** | en-US locale hardcoded | SpeechService | Detects user's English locale, falls back to en-US |
 | 7 | **P2** | CloudKit failure invisible to user | PersistenceController | `cloudKitAvailable` publisher, queryable from UI |
 | 8 | **P2** | Audio session not cleaned after playback | JournalDetailView | `stopPlayback()` deactivates session |
 | 9 | **P3** | No xcode previews | All views | Added `#Preview` macros (5 views) |
 | 10 | **P3** | No onboarding for first-time users | RecordView | Single-sheet onboarding with 3 steps |
 | 11 | **P3** | `durationTimer` dead code | JournalViewModel | Removed unused property |
 | 12 | **P3** | `refreshEntries()` called too often | JournalViewModel | Skip on count unchanged |
 | 13 | **P3** | No app icon | README | Instructions to generate one free |
 | 14 | **P3** | FlowLayout crash on zero width | StatsView | Early `return .zero` guard |
 | 15 | **P3** | `formatWeekLabel` edge case | StatsView | Nil/empty guard + numeric extraction |
 
 ## Project Structure
 
 ```
 VoiceJournal/
 ├── VoiceJournalApp.swift
 ├── Models/
 │   ├── PersistenceController.swift      # CloudKit + cloudKitAvailable publisher
 │   ├── JournalEntry+CoreDataClass.swift
 │   └── JournalEntry+CoreDataProperties.swift  # +Identifiable
 ├── Services/
 │   ├── SpeechService.swift             # Smarter en-* locale detection
 │   ├── AudioRecorder.swift             # 22050Hz + orphan cleanup
 │   ├── SentimentAnalyzer.swift         # Thread-safe (fresh taggers per call)
 │   ├── StorageService.swift
 │   ├── SummaryGenerator.swift
 │   └── NotificationService.swift       # Authorization-checked scheduling
 ├── ViewModels/
 │   ├── JournalViewModel.swift           # @Observable, no dead code
 │   └── StatsViewModel.swift            # Shares storage with JournalVM
 ├── Views/
 │   ├── RecordView.swift                # +Onboarding, +Preview
 │   ├── JournalListView.swift           # +Preview
 │   ├── JournalDetailView.swift         # Fixed playback, +Preview
 │   └── StatsView.swift                 # FlowLayout guard, shared storage
 ├── VoiceJournal.xcdatamodeld/
 └── Resources/Info.plist
 VoiceJournalWidget/                       # Cached Core Data container
 ├── VoiceJournalWidget.swift
 └── Info.plist
 ```
 
 ## Requirements
 
 - Xcode 15.0+, iOS 17.0+
 - Apple Developer account ($99/year)
 
 ## Setup Instructions
 
 ### 1. Create Xcode project
 
 Xcode > File > New > Project > iOS > App — name `VoiceJournal`, SwiftUI, Swift, 
 check **Use Core Data** and **Include Widget**.
 
 ### 2. Add source files
 
 Drag all files from this repo's `VoiceJournal/` and `VoiceJournalWidget/` into Xcode.
 
 ### 3. Core Data model
 
 Replace the auto-generated `VoiceJournal.xcdatamodeld` with the one from this repo.
 Verify `JournalEntry` entity has these attributes:
 
 | Attribute | Type | Optional | Default |
 |---|---|---|---|
 | id | UUID | NO | – |
 | title | String | YES | – |
 | transcriptText | String | YES | – |
 | audioFileName | String | YES | – |
 | sentimentScore | Double | YES | 0.0 |
 | duration | Double | YES | 0.0 |
 | createdAt | Date | YES | – |
 | updatedAt | Date | YES | – |
 
 ### 4. Configure Capabilities
 
 **Main app target:** iCloud (CloudKit) + App Groups (`group.com.yourname.VoiceJournal`) + Background Modes (Audio)
 **Widget target:** App Groups (same identifier)
 
 ### 5. Update identifiers
 
 | File | Replace |
 |---|---|
 | `PersistenceController.swift` | `group.com.yourname.VoiceJournal` |
 | `PersistenceController.swift` | `iCloud.com.yourname.VoiceJournal` |
 | `Resources/Info.plist` | `com.yourname.VoiceJournal` |
 | `VoiceJournalWidget.swift` | `group.com.yourname.VoiceJournal` |
 | `VoiceJournalWidget/Info.plist` | `com.yourname.VoiceJournal.widget` |
 
 ### 6. App icon (free)
 
 Go to [icon.kitchen](https://icon.kitchen) — search for "microphone" or "waveform" — 
 generate a 1024x1024 icon. Download and drag into `Assets.xcassets/AppIcon`.
 
 ### 7. Sign & Run
 
 Cmd+R on an iOS 17+ simulator or device.
 
 ## Architecture
 
 ```
 User taps record
 ├─► JournalViewModel.startRecording()
 │   ├─► configures AVAudioSession ONCE (.record, .measurement)
 │   ├─► AudioRecorder.startRecording() → saves .m4a at 22050Hz
 │   └─► SpeechService.startRecording() → streams transcript via closure
 │
 User taps stop
 ├─► SpeechService.stopRecording()       (no session toggle)
 ├─► AudioRecorder.stopRecording()       (returns .m4a URL)
 ├─► deactivates AVAudioSession
 ├─► SentimentAnalyzer.analyzeSentiment()
 ├─► StorageService.createEntry()
 └─► refreshEntries()
 ```
 
 **Observation chain:**
 - `JournalViewModel` ← `@Observable`
 - Services ← plain `NSObject` (no Observable conflict)
 - Views ← `@Environment(JournalViewModel.self)`
 
 **State flow:**
 - `SpeechService` / `AudioRecorder` emit via closures → `JournalViewModel` updates `@Observable` properties → SwiftUI re-renders affected views
 
 ## ASO Keywords
 
 `voice journal, diary, daily journal, mood tracker, AI journal, voice diary, speech to text, private journal`
 App Store category: **Health & Fitness > Journaling**
 
 ## V2 Ideas
 
 - Apple Watch companion
 - MLX-powered AI weekly summaries
 - Export to PDF / JSON
 - iPad + Scribble support
