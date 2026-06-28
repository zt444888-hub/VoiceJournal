import Foundation

final class StorageService {
    private let persistence = PersistenceController.shared
    private var allEntries: [JournalEntry] = []
    
    init() { allEntries = persistence.loadEntries() }
    
    func createEntry(title: String, transcript: String, audioFileName: String?,
                     sentimentScore: Double, duration: Double) -> JournalEntry {
        let e = JournalEntry(title: title, transcriptText: transcript, audioFileName: audioFileName,
                            sentimentScore: sentimentScore, duration: duration)
        allEntries.insert(e, at: 0); persistence.save(entries: allEntries); return e
    }
    func fetchAllEntries() -> [JournalEntry] { allEntries }
    func fetchEntries(for date: Date) -> [JournalEntry] { allEntries.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: date) } }
    func fetchEntries(for weekIdentifier: String) -> [JournalEntry] { allEntries.filter { $0.weekIdentifier == weekIdentifier } }
    
    func updateEntry(_ entry: JournalEntry, title: String? = nil, transcript: String? = nil) {
        if let t = title { entry.title = t }; if let t = transcript { entry.transcriptText = t }
        entry.updatedAt = Date(); persistence.save(entries: allEntries)
    }
    func deleteEntry(_ entry: JournalEntry) {
        allEntries.removeAll { $0.id == entry.id }
        if let n = entry.audioFileName { AudioRecorder.deleteRecording(named: n) }
        persistence.save(entries: allEntries)
    }
    func sentimentHistory(days: Int = 14) -> [(date: Date, avgSentiment: Double)] {
        (0..<days).reversed().compactMap { dayOffset -> (Date, Double)? in
            let d = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
            let de = allEntries.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: d) }
            guard !de.isEmpty else { return nil }
            return (d, de.map(\.sentimentScore).reduce(0, +) / Double(de.count))
        }
    }
    func weekSummaries() -> [(week: String, count: Int, avgSentiment: Double)] {
        Dictionary(grouping: allEntries) { $0.weekIdentifier }
            .map { ($0.key, $0.value.count, $0.value.map(\.sentimentScore).reduce(0, +) / Double($0.value.count)) }
            .sorted { $0.week > $1.week }
    }
}
