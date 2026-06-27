 import Foundation
 import SwiftUI
 
 /// Statistics derived from Core Data entries. Call `refresh()` when entries change.
 @MainActor
 @Observable
 class StatsViewModel {
     private let storage: StorageService
     let sentimentAnalyzer = SentimentAnalyzer()
     
     var weeklyData: [(week: String, count: Int, avgSentiment: Double)] = []
     var sentimentHistory: [(date: Date, avgSentiment: Double)] = []
     var totalEntries: Int = 0
     var totalDuration: TimeInterval = 0
     var totalWords: Int = 0
     var averageSentiment: Double = 0
     var streakDays: Int = 0
     var topKeywords: [String] = []
     
     init(storage: StorageService = StorageService()) {
         self.storage = storage
     }
     
     /// Recalculates all stats from scratch. Call after any entry mutation.
     func refresh() {
         let allEntries = storage.fetchAllEntries()
         
         totalEntries = allEntries.count
         totalDuration = allEntries.map(\.duration).reduce(0, +)
         totalWords = allEntries.map { $0.safeTranscript.split(separator: " ").count }.reduce(0, +)
         averageSentiment = allEntries.isEmpty ? 0 : allEntries.map(\.sentimentScore).reduce(0, +) / Double(allEntries.count)
         
         sentimentHistory = storage.sentimentHistory(days: 30)
         weeklyData = storage.weekSummaries()
         streakDays = calculateStreak(entries: allEntries)
         topKeywords = extractTopKeywords(from: allEntries)
     }
     
     // MARK: - Private
     private func calculateStreak(entries: [JournalEntry]) -> Int {
         let cal = Calendar.current
         let dates = Set(entries.map { cal.startOfDay(for: $0.safeDate) })
         var streak = 0
         var currentDate = cal.startOfDay(for: Date())
         
         for _ in 0..<365 {
             if dates.contains(currentDate) {
                 streak += 1
                 currentDate = cal.date(byAdding: .day, value: -1, to: currentDate)!
             } else { break }
         }
         return streak
     }
     
     private func extractTopKeywords(from entries: [JournalEntry]) -> [String] {
         guard !entries.isEmpty else { return [] }
         let allText = entries.prefix(50).map(\.safeTranscript).joined(separator: " ")
         return Array(sentimentAnalyzer.extractKeywords(allText).prefix(10))
     }
 }
