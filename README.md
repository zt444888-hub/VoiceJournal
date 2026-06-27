 # Voice Journal — On-Device AI Voice Diary
 
 Privacy-first voice journal app. **All processing on-device — zero server costs.**
 
 **Price:** $4.99 one-time purchase. **Cost to run:** $0/yr (Apple dev account $99 is a fixed cost, 24 sales covers it).
 
 ## What Changed (Code Review Round)
 
 | Issue | Fix |
 |---|---|
 | `@Observable` + `NSObject` conflict | Services: plain NSObject, no Observable macro. ViewModel: `@Observable`, single source of truth |
 | AVAudioSession conflict between SpeechService & AudioRecorder | Centralized in `JournalViewModel.startRecording()` — one config call |
 | NLTagger thread safety | Create fresh tagger per method call instead of reusing |
 | Widget can't read Core Data | App Groups shared container + widget reads it directly |
 | StatsView not reactive | `.onChange(of: journalVM.entries.count)` triggers auto-refresh |
 | `formatWeekLabel("2026-W27")` always returned raw string | Now correctly matches `W` prefix in second component |
 | FlowLayout crash on empty subviews | Early `.zero` return in `sizeThatFits` + `placeSubviews` |
 | Notifications scheduled without permission check | Check authorization before `add()` |
 | `@EnvironmentObject` with `@Observable` VM | Changed to `@Environment(JournalViewModel.self)` (iOS 17+ native) |
 | Core Data save swallows errors | `@discardableResult save() -> Bool` returns success state, logs on failure |
 
 ## Project Structure
 
 ```
 VoiceJournal/
 ├── VoiceJournalApp.swift               # @State JournalViewModel, .environment() injection
 ├── Models/
 │   ├── PersistenceController.swift      # Core Data + CloudKit + App Groups shared container
 │   ├── JournalEntry+CoreDataClass.swift
 │   └── JournalEntry+CoreDataProperties.swift  # + Identifiable conformance
 ├── Services/
 │   ├── SpeechService.swift             # SFSpeechRecognizer (NSObject, no @Observable)
 │   ├── AudioRecorder.swift             # AVAudioRecorder (NSObject, no @Observable)
 │   ├── SentimentAnalyzer.swift         # NaturalLanguage (fresh taggers per call)
 │   ├── StorageService.swift            # Core Data CRUD + stats queries
 │   ├── SummaryGenerator.swift          # Daily/weekly extractive summaries
 │   └── NotificationService.swift       # Local push reminders (checks authorization)
 ├── ViewModels/
 │   ├── JournalViewModel.swift           # @Observable, bridges service state, owns AVAudioSession
 │   └── StatsViewModel.swift            # @Observable, recalculates on demand
 ├── Views/
 │   ├── RecordView.swift                # Mic button + live transcription + recent entries
 │   ├── JournalListView.swift           # Entries grouped by date, searchable, swipe-to-delete
 │   ├── JournalDetailView.swift         # Edit, play audio, AI insight card, mood bar
 │   └── StatsView.swift                 # Charts, weekly summaries, keyword tags + FlowLayout
 ├── VoiceJournal.xcdatamodeld/           # Core Data model (contains `contents`)
 ├── Resources/Info.plist                 # Microphone + Speech permissions
 └── PreviewContent/
 VoiceJournalWidget/                       # iOS Widget reading shared Core Data via App Groups
 ├── VoiceJournalWidget.swift
 └── Info.plist
 ```
 
 ## Requirements
 
 - Xcode 15.0+
 - iOS 17.0+ (required by `@Observable`, Swift Charts, Layout protocol)
 - Apple Developer account ($99/year)
 
 ## Setup Instructions (on your Mac)
 
 ### 1. Create Xcode project
 
 1. Xcode > File > New > Project > iOS > App
 2. **Product Name:** `VoiceJournal` — **Interface:** SwiftUI — **Language:** Swift
 3. Check **Use Core Data**, **Include Widget**
 4. **Organization Identifier:** `com.yourname` (change `yourname` to your identifier)
 
 ### 2. Add source files
 
 Drag the entire `work/voice-journal/VoiceJournal/` folder into the Xcode project navigator. Check **Copy if needed**.
 
 ### 3. Core Data model
 
 The project already includes `VoiceJournal.xcdatamodeld/contents`. If Xcode created a default model, delete it and drag in this one. Verify the `JournalEntry` entity has exactly these attributes:
 
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
 
 ### 4. Configure Capabilities (two targets)
 
 **Main app target:**
 - `Signing & Capabilities` > `+` > **iCloud** > check **CloudKit**
 - `+` > **App Groups** > add `group.com.yourname.VoiceJournal`
 - `+` > **Background Modes** > check **Audio, AirPlay, and Picture in Picture**
 
 **Widget extension target:**
 - `Signing & Capabilities` > `+` > **App Groups** > add **same** `group.com.yourname.VoiceJournal`
 
 ### 5. Update identifiers
 
 All files use placeholder `com.yourname`. Replace with your actual bundle ID:
 
 | File | Replace |
 |---|---|
 | `PersistenceController.swift` | `group.com.yourname.VoiceJournal` |
 | `PersistenceController.swift` | `iCloud.com.yourname.VoiceJournal` |
 | `Resources/Info.plist` | `com.yourname.VoiceJournal` |
 | `VoiceJournalWidget.swift` | `group.com.yourname.VoiceJournal` |
 | `VoiceJournalWidget/Info.plist` | `com.yourname.VoiceJournal.widget` |
 
 ### 6. Sign & Run
 
 Select your team in Signing & Capabilities. Select an iOS 17+ simulator (or device). Press **Cmd+R**.
 
 ## Architecture
 
 ```
 User taps record
 ├─► JournalViewModel.startRecording()
 │   ├─► configures AVAudioSession ONCE (category: .record, mode: .measurement)
 │   ├─► AudioRecorder.startRecording()  ──  saves .m4a
 │   └─► SpeechService.startRecording()  ──  streams transcript via closure
 │
 User taps stop
 ├─► JournalViewModel.stopRecording()
 │   ├─► SpeechService.stopRecording()          (no session toggle)
 │   ├─► AudioRecorder.stopRecording()          (returns .m4a URL)
 │   ├─► deactivates AVAudioSession once
 │   ├─► SentimentAnalyzer.analyzeSentiment()
 │   ├─► StorageService.createEntry()
 │   └─► refreshEntries()
 │
 StatsView
 └─► onAppear / onChange of entries.count ──► StatsViewModel.refresh()
 ```
 
 **Observation chain:**
 - `JournalViewModel` — `@Observable` in SwiftUI 17+ style
 - Services — plain `NSObject` subclasses, communicate via closures
 - Views — `@Environment(JournalViewModel.self)` reads state
 
 ## ASO Keywords (for App Store)
 
 `voice journal, diary, daily journal, mood tracker, AI journal, voice diary, speech to text, private journal, mood tracker`
 
 App Store category: **Health & Fitness > Journaling**
 
 ## V2 Ideas (no additional cost)
 
 - Widget with live entry preview (already scaffolded)
 - Apple Watch companion for on-the-go recording
 - iPad support with Scribble annotations
 - MLX integration for AI-generated weekly summaries (see `SentimentAnalyzer.swift` V2 note)
 - Export to PDF / JSON
