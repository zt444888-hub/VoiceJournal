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
      
     // MARK: - Services
     private let speechService = SpeechService()
     private let audioRecorder = AudioRecorder()
     private let sentimentAnalyzer = SentimentAnalyzer()
     let storage: StorageService
     @ObservationIgnored private lazy var summaryGenerator = SummaryGenerator(storage: storage)
     private let notificationService = NotificationService()
     
     private var lastEntryCount = 0
     
     init(storage: StorageService = StorageService()) {
         self.storage = storage
         
         // Bridge updates from non-observable services

         speechService.onError = { [weak self] msg in
             self?.errorMessage = msg
         }
         audioRecorder.onUpdate = { [weak self] duration in
             self?.recordingDuration = duration
         }
         audioRecorder.onError = { [weak self] msg in
             self?.errorMessage = msg
         }
         
         
         
     }
     
     // MARK: - Permissions
     func requestPermissions() async {
         let micStatus = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            AVAudioSession.sharedInstance().requestRecordPermission { g in c.resume(returning: g) }
        }
         let speechGranted = await speechService.requestAuthorization()
         isAuthorized = micStatus && speechGranted
         notificationService.requestAuthorization()
     }
     
     // MARK: - Recording
     func startRecording() {
         guard AVAudioSession.sharedInstance().isInputAvailable else {
            errorMessage = "No microphone available"
            return
        }
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
             // speech recognition will happen after recording stops
             isRecording = true
         } catch {
             errorMessage = "Failed to start recording: \(error.localizedDescription)"
             isRecording = false
         }
     }
     
     func stopRecording() {
         // speech service no longer uses live recording
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
         // speech service no longer uses live recording
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
     func exportCSV() -> URL? {
        return ExportService.exportToCSV(entries: entries)
    }
    
    func exportJSON() -> URL? {
        return ExportService.exportToJSON(entries: entries)
    }
    
    
    func addSampleData() {
        for i in 0..<4 {
            let titles = ["Great day at work", "Meeting with friends", "Morning reflection", "Evening thoughts", "Weekend plan", "Learning Swift", "Beach walk", "Book review"]
            let texts = ["Today was really productive. I finished the main feature and got great feedback from the team.", "Had coffee with old friends. We talked about travel plans and future goals.", "Woke up early and went for a run. The weather was perfect.", "Feeling grateful for everything today. Small wins add up.", "Planning a hiking trip this weekend. Really looking forward to it.", "Spent the afternoon learning about SwiftUI animations. Amazing what you can do with iOS 17.", "Walked along the beach at sunset. The waves were calming.", "Finished reading Atomic Habits. Highly recommend it to everyone."]
            let entry = storage.createEntry(title: titles[i % titles.count], transcript: texts[i % texts.count], audioFileName: nil, sentimentScore: [-0.2, 0.8, 0.5, 0.1, 0.9, 0.6, 0.7, 0.3][i], duration: Double.random(in: 30...120))
        }
        refreshEntries()
    }
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
