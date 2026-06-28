import Foundation

@Observable
final class JournalEntry: Identifiable, Codable {
    var id: String
    var title: String
    var transcriptText: String
    var audioFileName: String?
    var sentimentScore: Double
    var duration: Double
    var createdAt: Date
    var updatedAt: Date
    
    init(id: String = UUID().uuidString, title: String = "", transcriptText: String = "",
         audioFileName: String? = nil, sentimentScore: Double = 0, duration: Double = 0,
         createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id; self.title = title; self.transcriptText = transcriptText
        self.audioFileName = audioFileName; self.sentimentScore = sentimentScore
        self.duration = duration; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
    
    var safeTitle: String { title.isEmpty ? "Untitled" : title }
    var safeTranscript: String { transcriptText.isEmpty ? "No transcription" : transcriptText }
    var safeDate: Date { createdAt }
    var formattedDate: String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: createdAt)
    }
    var dayIdentifier: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: createdAt)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    var weekIdentifier: String {
        let cal = Calendar.current
        return "\(cal.component(.yearForWeekOfYear, from: createdAt))-W\(String(format: "%02d", cal.component(.weekOfYear, from: createdAt)))"
    }
    var sentimentEmoji: String { sentimentScore > 0.3 ? "\u{1F60A}" : sentimentScore > -0.3 ? "\u{1F610}" : "\u{1F614}" }
    var formattedDuration: String {
        let m = Int(duration) / 60; let s = Int(duration) % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}
