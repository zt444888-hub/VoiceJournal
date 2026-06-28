import Foundation

struct PersistenceController {
    static var preview: PersistenceController = { PersistenceController() }()
    static let shared = PersistenceController()
    static let appGroup = "group.com.a1111.VoiceJournal"
    private let fileURL: URL = {
        if let g = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            return g.appendingPathComponent("journal_entries.json")
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("journal_entries.json")
    }()
    
    func loadEntries() -> [JournalEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder().decode([JournalEntry].self, from: data) else { return [] }
        return entries.sorted { $0.createdAt > $1.createdAt }
    }
    
    @discardableResult
    func save(entries: [JournalEntry]) -> Bool {
        guard let data = try? JSONEncoder().encode(entries) else { return false }
        do { try data.write(to: fileURL, options: .atomic); return true }
        catch { print("Save: \(error)"); return false }
    }
}
