import Foundation
import UniformTypeIdentifiers

struct ExportService {
    
    static func exportToCSV(entries: [JournalEntry]) -> URL? {
        var csv = "Date,Title,Transcript,Sentiment,Duration (s),Audio File\n"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        
        for entry in entries {
            let date = df.string(from: entry.safeDate)
            let title = escapeCSVField(entry.safeTitle)
            let transcript = escapeCSVField(entry.safeTranscript)
            let sentiment = String(format: "%.2f", entry.sentimentScore)
            let duration = String(format: "%.0f", entry.duration)
            let audio = entry.audioFileName ?? ""
            csv += "\(date),\(title),\(transcript),\(sentiment),\(duration),\(audio)\n"
        }
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("VoiceJournal_Export.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    static func exportToJSON(entries: [JournalEntry]) -> URL? {
        let df = ISO8601DateFormatter()
        var jsonArray: [[String: Any]] = []
        
        for entry in entries {
            let dict: [String: Any] = [
                "title": entry.safeTitle,
                "transcript": entry.safeTranscript,
                "sentimentScore": entry.sentimentScore,
                "duration": entry.duration,
                "createdAt": df.string(from: entry.safeDate),
                "audioFileName": entry.audioFileName ?? ""
            ]
            jsonArray.append(dict)
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: jsonArray, options: .prettyPrinted) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("VoiceJournal_Export.json")
            try? data.write(to: url)
            return url
        }
        return nil
    }
    
    static func escapeCSVField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(escaped)\""
        }
        return value
    }
}
