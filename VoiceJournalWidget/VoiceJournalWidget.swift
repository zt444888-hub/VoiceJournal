import WidgetKit
import SwiftUI

struct JournalEntryWidget: Widget {
    let kind = "com.a1111.VoiceJournal.widget"
    
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

struct SimpleEntry: TimelineEntry {
    let date: Date
    let latestEntry: JournalEntrySummary?
}

struct JournalEntrySummary: Codable {
    let title: String
    let transcriptText: String
    let sentimentScore: Double
    let createdAt: Date
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), latestEntry: nil)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date(), latestEntry: Self.loadLatestEntry()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: Date(), latestEntry: Self.loadLatestEntry())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
    }
    
    private static func loadLatestEntry() -> JournalEntrySummary? {
        guard let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.a1111.VoiceJournal") else { return nil }
        let fileURL = groupURL.appendingPathComponent("journal_entries.json")
        guard let data = try? Data(contentsOf: fileURL),
              let all = try? JSONDecoder().decode([JournalEntrySummary].self, from: data) else { return nil }
        return all.sorted { $0.createdAt > $1.createdAt }.first
    }
}

struct WidgetView: View {
    var entry: SimpleEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mic.circle.fill").foregroundColor(.accentColor)
                Text("Voice Journal").font(.caption).fontWeight(.semibold)
            }
            if let latest = entry.latestEntry {
                let emoji: String = latest.sentimentScore > 0.3 ? "😊" : latest.sentimentScore > -0.3 ? "😐" : "😔"
                Text(emoji).font(.largeTitle)
                Text(latest.title).font(.caption).lineLimit(2)
                let f = DateFormatter(); f.dateFormat = "MMM d"
                Text(f.string(from: latest.createdAt)).font(.caption2).foregroundColor(.secondary)
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "waveform").font(.title2).foregroundColor(.secondary)
                    Text("No entries yet").font(.caption).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
