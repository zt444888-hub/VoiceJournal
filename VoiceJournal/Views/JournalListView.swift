 import SwiftUI
 
 /// Displays journal entries grouped by date with pull-to-refresh.
 struct JournalListView: View {
     @Environment(JournalViewModel.self) private var journalVM
     @State private var searchText = ""
     @State private var selectedEntry: JournalEntry?
     
     var body: some View {
         NavigationStack {
             List {
                 if journalVM.entries.isEmpty {
                     emptyState
                 } else {
                     entriesSection
                 }
             }
             .navigationTitle("Journal")
             .searchable(text: $searchText, prompt: "Search entries")
             .toolbar {
                 ToolbarItem(placement: .navigationBarTrailing) {
                     EditButton()
                 }
             }
             .refreshable { journalVM.refreshEntries() }
             .onAppear { journalVM.refreshEntries() }
         }
     }
     
     private var emptyState: some View {
         VStack(spacing: 16) {
             Image(systemName: "book.and.pencil")
                 .font(.system(size: 48)).foregroundColor(.secondary)
             Text("No entries yet").font(.title3).foregroundColor(.secondary)
             Text("Start by recording your first voice journal")
                 .font(.subheadline).foregroundColor(.tertiary)
         }
         .frame(maxWidth: .infinity).padding(.vertical, 60)
         .listRowBackground(Color.clear)
     }
     
     private var entriesSection: some View {
         let filtered = filteredEntries
         let grouped = Dictionary(grouping: filtered) { entry in
             Calendar.current.isDateInToday(entry.safeDate) ? "Today" :
             Calendar.current.isDateInYesterday(entry.safeDate) ? "Yesterday" :
             entry.dayIdentifier
         }
         let sortedKeys = grouped.keys.sorted { a, b in
             if a == "Today" { return true }
             if b == "Today" { return false }
             if a == "Yesterday" { return true }
             if b == "Yesterday" { return false }
             return a > b
         }
         
         return ForEach(sortedKeys, id: \.self) { key in
             Section {
                 ForEach(grouped[key]!.sorted(by: { $0.safeDate > $1.safeDate })) { entry in
                     NavigationLink(destination: JournalDetailView(entry: entry)) {
                         JournalRow(entry: entry)
                     }
                     .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                         Button(role: .destructive) {
                             withAnimation { journalVM.deleteEntry(entry) }
                         } label: {
                             Label("Delete", systemImage: "trash")
                         }
                     }
                 }
             } header: {
                 if key == "Today" || key == "Yesterday" {
                     Text(key).font(.headline)
                 } else {
                     Text(formattedDateHeader(key)).font(.headline)
                 }
             }
         }
     }
     
     private var filteredEntries: [JournalEntry] {
         if searchText.isEmpty { return journalVM.entries }
         return journalVM.entries.filter {
             $0.safeTitle.localizedCaseInsensitiveContains(searchText) ||
             $0.safeTranscript.localizedCaseInsensitiveContains(searchText)
         }
     }
     
     private func formattedDateHeader(_ dayId: String) -> String {
         let f = DateFormatter()
         f.dateFormat = "yyyy-MM-dd"
         guard let date = f.date(from: dayId) else { return dayId }
         let df = DateFormatter()
         df.dateFormat = "EEEE, MMM d"
         return df.string(from: date)
     }
 }
 
 // MARK: - Journal Row
 struct JournalRow: View {
     let entry: JournalEntry
     
     var body: some View {
         HStack(spacing: 12) {
             Text(entry.sentimentEmoji).font(.title2)
             VStack(alignment: .leading, spacing: 4) {
                 Text(entry.safeTitle).font(.body).fontWeight(.medium).lineLimit(1)
                 Text(entry.formattedDate).font(.caption).foregroundColor(.secondary)
             }
             Spacer()
             Text(entry.formattedDuration)
                 .font(.caption2).foregroundColor(.secondary)
                 .padding(.horizontal, 8).padding(.vertical, 3)
                 .background(Color(.systemGray6)).clipShape(Capsule())
         }
         .padding(.vertical, 4)
     }
 }
 
 // MARK: - Preview
 #Preview("List with entries") {
     let preview = PersistenceController.preview
     let vm = JournalViewModel(storage: StorageService(context: preview.container.viewContext))
     NavigationStack {
         JournalListView()
             .environment(vm)
     }
 }
