 import Foundation
 import SwiftUI
 import AVFoundation
 
 /// Single source of truth. Bridges non-observable services into @Observable properties.
 @MainActor
 @Observable
 class JournalViewModel {
     
     // MARK: - Observable state
     var isRecording = false
     var isProcessing = false
     var liveTranscript = ""
     var recordingDuration: TimeInterval = 0
     var errorMessage: String?
     var isAuthorized = false
     var entries: [JournalEntry] = []
     var isCloudKitAvailable = true
     
     // MARK: - Services
     private let speechService = SpeechService()
     private let audioRecorder = AudioRecorder()
     private let sentimentAnalyzer = SentimentAnalyzer()
     let storage: StorageService
     private lazy var summaryGenerator = SummaryGenerator(storage: storage)
     private let notificationService = NotificationService()
     
     private var lastEntryCount = 0
     
     init(storage: StorageService = StorageService()) {
         self.storage = storage
         
         // Bridge updates from non-observable services
         speechService.onTranscriptUpdate = { [weak self] text in
             self?.liveTranscript = text
         }
         speechService.onError = { [weak self] msg in
             self?.errorMessage = msg
         }
         audioRecorder.onUpdate = { [weak self] duration in
             self?.recordingDuration = duration
         }
         audioRecorder.onError = { [weak self] msg in
             self?.errorMessage = msg
         }
         
         // Track CloudKit availability
         isCloudKitAvailable = PersistenceController.isCloudKitAvailable()
     }
     
     // MARK: - Permissions
     func requestPermissions() async {
         let micStatus = await AVAudioSession.sharedInstance().requestRecordPermission()
         let speechGranted = await speechService.requestAuthorization()
         isAuthorized = micStatus && speechGranted
         notificationService.requestAuthorization()
     }
     
     // MARK: - Recording
     func startRecording() {
         guard isAuthorized else {
             errorMessage = "Microphone and speech recognition permissions required"
             return
         }
         
         do {
             let session = AVAudioSession.sharedInstance()
             try session.setCategory(.record, mode: .measurement, options: .duckOthers)
             try session.setActive(true, options: .notifyOthersOnDeactivation)
             
             liveTranscript = ""
             recordingDuration = 0
             errorMessage = nil
             
             try audioRecorder.startRecording()
             try speechService.startRecording(audioSessionPreconfigured: true)
             isRecording = true
         } catch {
             errorMessage = "Failed to start recording: \(error.localizedDescription)"
             isRecording = false
         }
     }
     
     func stopRecording() {
         speechService.stopRecording(deactivateSession: false)
         let audioURL = audioRecorder.stopRecording()
         isRecording = false
         
         try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
         
         guard !liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
             if let url = audioURL { try? FileManager.default.removeItem(at: url) }
             liveTranscript = ""
             return
         }
         
         isProcessing = true
         
         let sentiment = sentimentAnalyzer.analyzeSentiment(liveTranscript)
         let title = generateTitle(from: liveTranscript)
         let audioFileName = audioURL?.lastPathComponent
         
         _ = storage.createEntry(
             title: title, transcript: liveTranscript,
             audioFileName: audioFileName,
             sentimentScore: sentiment, duration: recordingDuration
         )
         
         refreshEntries()
         isProcessing = false
     }
     
     func cancelRecording() {
         speechService.stopRecording(deactivateSession: false)
         if let url = audioRecorder.currentFilePath {
             try? FileManager.default.removeItem(at: url)
         }
         audioRecorder.stopRecording()
         try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
         isRecording = false
         liveTranscript = ""
         recordingDuration = 0
     }
     
     // MARK: - Entry CRUD
     func refreshEntries() {
         let newEntries = storage.fetchAllEntries()
         if newEntries.count != lastEntryCount {
             entries = newEntries
             lastEntryCount = entries.count
         }
     }
     
     func deleteEntry(_ entry: JournalEntry) {
         storage.deleteEntry(entry)
         refreshEntries()
     }
     
     func updateEntry(_ entry: JournalEntry, title: String? = nil, transcript: String? = nil) {
         if transcript != nil {
             entry.sentimentScore = sentimentAnalyzer.analyzeSentiment(transcript ?? "")
         }
         storage.updateEntry(entry, title: title, transcript: transcript)
         refreshEntries()
     }
     
     /// Removes audio files not referenced by any entry (prevents orphan accumulation)
     func cleanOrphanedAudioFiles() {
         let activeFiles = Set(storage.fetchAllEntries().compactMap(\.audioFileName))
         AudioRecorder.cleanOrphanedAudioFiles(activeFileNames: activeFiles)
     }
     
     // MARK: - Insights
     func dailySummary(for date: Date) -> String {
         summaryGenerator.dailySummary(for: date)
     }
     
     func weeklySummary(for weekIdentifier: String) -> String {
         summaryGenerator.weeklySummary(for: weekIdentifier)
     }
     
     func sentimentHistory(days: Int = 14) -> [(date: Date, avgSentiment: Double)] {
         storage.sentimentHistory(days: days)
     }
     
     // MARK: - Reminders
     func enableReminders() {
         notificationService.scheduleDailyReminder()
         notificationService.scheduleEveningPrompt()
     }
     
     func disableReminders() {
         notificationService.cancelAll()
     }
     
     // MARK: - Helpers
     private func generateTitle(from transcript: String) -> String {
         let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
         let words = trimmed.split(separator: " ")
         if words.count <= 6 { return trimmed }
         return words.prefix(6).joined(separator: " ") + "..."
     }
 }
