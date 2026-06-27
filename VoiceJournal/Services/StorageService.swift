 import Foundation
 import CoreData
 
 /// Handles all Core Data operations for journal entries.
 struct StorageService {
     private let context: NSManagedObjectContext
     
     init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
         self.context = context
     }
     
     // MARK: - Create
     func createEntry(title: String, transcript: String, audioFileName: String?,
                      sentimentScore: Double, duration: Double) -> JournalEntry {
         let entry = JournalEntry(context: context)
         entry.id = UUID()
         entry.title = title
         entry.transcriptText = transcript
         entry.audioFileName = audioFileName
         entry.sentimentScore = sentimentScore
         entry.duration = duration
         entry.createdAt = Date()
         entry.updatedAt = Date()
         save()
         return entry
     }
     
     // MARK: - Read
     func fetchAllEntries() -> [JournalEntry] {
         let request = JournalEntry.fetchRequest()
         request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)]
         return (try? context.fetch(request)) ?? []
     }
     
     func fetchEntries(for date: Date) -> [JournalEntry] {
         let cal = Calendar.current
         let startOfDay = cal.startOfDay(for: date)
         let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
         
         let request = JournalEntry.fetchRequest()
         request.predicate = NSPredicate(format: "createdAt >= %@ AND createdAt < %@", startOfDay as NSDate, endOfDay as NSDate)
         request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)]
         return (try? context.fetch(request)) ?? []
     }
     
     func fetchEntries(for weekIdentifier: String) -> [JournalEntry] {
         let all = fetchAllEntries()
         return all.filter { $0.weekIdentifier == weekIdentifier }
     }
     
     func fetchEntry(by id: UUID) -> JournalEntry? {
         let request = JournalEntry.fetchRequest()
         request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
         request.fetchLimit = 1
         return (try? context.fetch(request))?.first
     }
     
     // MARK: - Update
     func updateEntry(_ entry: JournalEntry, title: String? = nil, transcript: String? = nil) {
         if let title = title { entry.title = title }
         if let transcript = transcript { entry.transcriptText = transcript }
         entry.updatedAt = Date()
         save()
     }
     
     // MARK: - Delete
     func deleteEntry(_ entry: JournalEntry) {
         // Also delete audio file if exists
         if let fileName = entry.audioFileName {
             AudioRecorder.playbackURL(for: fileName).map { try? FileManager.default.removeItem(at: $0) }
         }
         context.delete(entry)
         save()
     }
     
     // MARK: - Stats
     func sentimentHistory(days: Int = 14) -> [(date: Date, avgSentiment: Double)] {
         let entries = fetchAllEntries()
         let cal = Calendar.current
         var result: [(Date, Double)] = []
         
         for dayOffset in (0..<days).reversed() {
             let date = cal.date(byAdding: .day, value: -dayOffset, to: Date())!
             let dayEntries = entries.filter { cal.isDate($0.safeDate, inSameDayAs: date) }
             if !dayEntries.isEmpty {
                 let avg = dayEntries.map(\.sentimentScore).reduce(0, +) / Double(dayEntries.count)
                 result.append((date, avg))
             }
         }
         return result
     }
     
     func weekSummaries() -> [(week: String, count: Int, avgSentiment: Double)] {
         let entries = fetchAllEntries()
         let grouped = Dictionary(grouping: entries) { $0.weekIdentifier }
         return grouped.map { week, entries in
             (week, entries.count, entries.map(\.sentimentScore).reduce(0, +) / Double(entries.count))
         }.sorted { $0.week > $1.week }
     }
     
     // MARK: - Private
     private func save() {
         PersistenceController.shared.save()
     }
 }
