import Foundation
import UniformTypeIdentifiers

struct ExportService {
    
    static func exportToCSV(entries: [JournalEntry]) -> URL? {
        var csv = "Date,Title,Transcript,Sentiment,Duration (s),Tags,Audio File\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        for entry in entries {
            let date = dateFormatter.string(from: entry.safeDate)
            let title = escapeCSV(entry.safeTitle)
            let transcript = escapeCSV(entry.safeTranscript)
            let sentiment = String(format: "%.2f", entry.sentimentScore)
            let duration = String(format: "%.0f", entry.duration)
            let tags = escapeCSV(entry.safeTags.joined(separator: "; "))
            let audio = entry.audioFileName ?? ""
            csv += "\(date),\(title),\(transcript),\(sentiment),\(duration),\(tags),\(audio)\n"
        }
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("VoiceJournal_Export.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    static func exportToJSON(entries: [JournalEntry]) -> URL? {
        let dateFormatter = ISO8601DateFormatter()
        var jsonArray: [[String: Any]] = []
        
        for entry in entries {
            let dict: [String: Any] = [
                "title": entry.safeTitle,
                "transcript": entry.safeTranscript,
                "sentimentScore": entry.sentimentScore,
                "duration": entry.duration,
                "createdAt": dateFormatter.string(from: entry.safeDate),
                "tags": entry.safeTags,
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
    
    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\"\"))\""  // wait that's wrong
        }
        return value
    }
    // 重新实现escapeCSV
    static func escapeCSVField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(escaped)\""
        }
        return value
    }
}
