 import Foundation
 
 /// Generates daily and weekly summaries using on-device analysis.
 /// V2: Replace extractive logic with MLX-powered generative summaries.
 struct SummaryGenerator {
     private let sentimentAnalyzer = SentimentAnalyzer()
     private let storage: StorageService
     
     init(storage: StorageService) {
         self.storage = storage
     }
     
     /// Generates a brief daily summary for a given date
     func dailySummary(for date: Date) -> String {
         let entries = storage.fetchEntries(for: date)
         guard !entries.isEmpty else { return "No entries for this day." }
         
         let totalDuration = entries.map(\.duration).reduce(0, +)
         let avgSentiment = entries.map(\.sentimentScore).reduce(0, +) / Double(entries.count)
         let totalWords = entries.map { $0.safeTranscript.split(separator: " ").count }.reduce(0, +)
         
         let sentimentLabel: String
         if avgSentiment > 0.3 { sentimentLabel = "positive" }
         else if avgSentiment > -0.3 { sentimentLabel = "mixed" }
         else { sentimentLabel = "reflective" }
         
         return "\(entries.count) entries · \(formatDuration(totalDuration)) · \(totalWords) words · \(sentimentLabel) mood"
     }
     
     /// Generates a weekly summary with trends and insights
     func weeklySummary(for weekIdentifier: String) -> String {
         let entries = storage.fetchEntries(for: weekIdentifier)
         guard !entries.isEmpty else { return "No entries this week." }
         
         let avgSentiment = entries.map(\.sentimentScore).reduce(0, +) / Double(entries.count)
         let totalDuration = entries.map(\.duration).reduce(0, +)
         let totalEntries = entries.count
         
         // Collect all keywords for the week
         let allText = entries.map(\.safeTranscript).joined(separator: " ")
         let keywords = sentimentAnalyzer.extractKeywords(allText)
         
         let sentimentTrend = generateTrendLine(entries: entries)
         
         var lines: [String] = []
         lines.append("Week Summary")
         lines.append(String(repeating: "─", count: 20))
         lines.append("\(totalEntries) entries · \(formatDuration(totalDuration)) total")
         lines.append("Average mood: \(emoji(for: avgSentiment))")
         lines.append("Trend: \(sentimentTrend)")
         if !keywords.isEmpty {
             let top = keywords.prefix(5).joined(separator: ", ")
             lines.append("Key topics: \(top)")
         }
         return lines.joined(separator: "\n")
     }
     
     private func generateTrendLine(entries: [JournalEntry]) -> String {
         let sorted = entries.sorted { $0.safeDate < $1.safeDate }
         guard sorted.count >= 2 else {
             return "Not enough data to detect trend"
         }
         let first = sorted.first!.sentimentScore
         let last = sorted.last!.sentimentScore
         let diff = last - first
         if diff > 0.3 { return "Improving ↗" }
         else if diff > 0.1 { return "Slightly improving ↗" }
         else if diff > -0.1 { return "Stable →" }
         else if diff > -0.3 { return "Slightly declining ↘" }
         else { return "Declining ↘" }
     }
     
     private func emoji(for sentiment: Double) -> String {
         if sentiment > 0.5 { return "😊" }
         else if sentiment > 0.2 { return "🙂" }
         else if sentiment > -0.2 { return "😐" }
         else if sentiment > -0.5 { return "😕" }
         else { return "😔" }
     }
     
     private func formatDuration(_ seconds: TimeInterval) -> String {
         let minutes = Int(seconds) / 60
         if minutes >= 60 {
             return "\(minutes / 60)h \(minutes % 60)m"
         }
         return "\(minutes)m"
     }
 }
