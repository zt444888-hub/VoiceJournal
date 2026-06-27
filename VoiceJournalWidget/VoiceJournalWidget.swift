 import WidgetKit
 import SwiftUI
 import CoreData
 
 // MARK: - Widget
 struct JournalEntryWidget: Widget {
     let kind = "com.yourname.VoiceJournal.widget"
     
     var body: some WidgetConfiguration {
         StaticConfiguration(kind: kind, provider: Provider()) { entry in
             WidgetView(entry: entry)
                 .containerBackground(.fill.tertiary, for: .widget)
         }
         .configurationDisplayName("Voice Journal")
         .description("Latest entry preview.")
         .supportedFamilies([.systemSmall, .systemMedium])
     }
 }
 
 // MARK: - Entry
 struct SimpleEntry: TimelineEntry {
     let date: Date
     let latestEntry: JournalEntrySummary?
 }
 
 struct JournalEntrySummary {
     let title: String
     let emoji: String
     let date: String
 }
 
 // MARK: - Provider
 struct Provider: TimelineProvider {
     func placeholder(in context: Context) -> SimpleEntry {
         SimpleEntry(date: Date(), latestEntry: nil)
     }
     
     func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
         let summary = loadLatestEntry()
         completion(SimpleEntry(date: Date(), latestEntry: summary))
     }
     
     func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
         let summary = loadLatestEntry()
         let entry = SimpleEntry(date: Date(), latestEntry: summary)
         // Refresh every hour
         let nextRefresh = Date().addingTimeInterval(3600)
         let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
         completion(timeline)
     }
     
     /// Reads the most recent JournalEntry from the shared App Groups store
     private func loadLatestEntry() -> JournalEntrySummary? {
         // Use same app group as main app to access shared Core Data
         let appGroup = "group.com.yourname.VoiceJournal"
         guard let groupURL = FileManager.default
             .containerURL(forSecurityApplicationGroupIdentifier: appGroup) else { return nil }
         
         let storeURL = groupURL.appendingPathComponent("VoiceJournal.sqlite")
         
         let container = NSPersistentContainer(name: "VoiceJournal")
         container.persistentStoreDescriptions.first?.url = storeURL
         container.loadPersistentStores { _, error in
             if error != nil { print("Widget CD load error: \(error!.localizedDescription)") }
         }
         
         let request = NSFetchRequest<NSManagedObject>(entityName: "JournalEntry")
         request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
         request.fetchLimit = 1
         
         guard let results = try? container.viewContext.fetch(request),
               let first = results.first else { return nil }
         
         let title = first.value(forKey: "title") as? String ?? "Untitled"
         let sentiment = first.value(forKey: "sentimentScore") as? Double ?? 0
         let createdAt = first.value(forKey: "createdAt") as? Date ?? Date()
         
         let emoji: String = {
             if sentiment > 0.3 { return "😊" }
             else if sentiment > -0.3 { return "😐" }
             else { return "😔" }
         }()
         
         let formatter = DateFormatter()
         formatter.dateFormat = "MMM d"
         
         return JournalEntrySummary(
             title: title,
             emoji: emoji,
             date: formatter.string(from: createdAt)
         )
     }
 }
 
 // MARK: - View
 struct WidgetView: View {
     var entry: SimpleEntry
     
     var body: some View {
         VStack(alignment: .leading, spacing: 8) {
             HStack {
                 Image(systemName: "mic.circle.fill")
                     .foregroundColor(.accentColor)
                 Text("Voice Journal")
                     .font(.caption)
                     .fontWeight(.semibold)
             }
             
             if let latest = entry.latestEntry {
                 Text(latest.emoji).font(.largeTitle)
                 Text(latest.title).font(.caption).lineLimit(2)
                 Text(latest.date).font(.caption2).foregroundColor(.secondary)
             } else {
                 VStack(spacing: 4) {
                     Image(systemName: "waveform").font(.title2).foregroundColor(.secondary)
                     Text("No entries yet").font(.caption).foregroundColor(.secondary)
                 }
                 .frame(maxWidth: .infinity, maxHeight: .infinity)
             }
         }
     }
 }
