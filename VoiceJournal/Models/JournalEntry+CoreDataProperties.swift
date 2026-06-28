import Foundation
import CoreData

extension JournalEntry: Identifiable {}

extension JournalEntry {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<JournalEntry> {
        NSFetchRequest<JournalEntry>(entityName: "JournalEntry")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var transcriptText: String?
    @NSManaged public var audioFileName: String?
    @NSManaged public var sentimentScore: Double
    @NSManaged public var duration: Double
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var tags: String?

    var safeTags: [String] {
        guard let t = tags, !t.isEmpty else { return [] }
        return t.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    func addTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return }
        var current = safeTags
        if !current.contains(trimmed) {
            current.append(trimmed)
            tags = current.joined(separator: ",")
        }
    }

    var safeTitle: String {
        guard let t = title, !t.isEmpty else { return "Untitled" }
        return t
    }

    var safeTranscript: String {
        guard let t = transcriptText, !t.isEmpty else { return "No transcription" }
        return t
    }

    var safeDate: Date { createdAt ?? Date() }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: safeDate)
    }

    var dayIdentifier: String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: safeDate)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    var weekIdentifier: String {
        let cal = Calendar.current
        let woy = cal.component(.weekOfYear, from: safeDate)
        let year = cal.component(.yearForWeekOfYear, from: safeDate)
        return "\(year)-W\(String(format: "%02d", woy))"
    }

    var sentimentEmoji: String {
        if sentimentScore > 0.3 { return "😊" }
        else if sentimentScore > -0.3 { return "😐" }
        else { return "😔" }
    }

    var formattedDuration: String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}
