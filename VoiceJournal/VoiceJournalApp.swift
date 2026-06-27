 import SwiftUI
 
 /// Minimum deployment: iOS 17.0 (required by @Observable, Swift Charts, Layout protocol)
 @main
 struct VoiceJournalApp: App {
     @State private var journalVM = JournalViewModel()
     
     var body: some Scene {
         WindowGroup {
             ContentView()
                 .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                 .environment(journalVM)
                 .onAppear {
                     UNUserNotificationCenter.current().requestAuthorization(
                         options: [.alert, .sound, .badge]
                     ) { _, _ in }
                 }
         }
     }
 }
 
 struct ContentView: View {
     @Environment(JournalViewModel.self) private var journalVM
     @State private var selectedTab = 0
     
     var body: some View {
         TabView(selection: $selectedTab) {
             RecordView()
                 .tabItem { Label("Record", systemImage: "mic.circle.fill") }
                 .tag(0)
             
             JournalListView()
                 .tabItem { Label("Journal", systemImage: "book.fill") }
                 .tag(1)
             
             StatsView()
                 .tabItem { Label("Insights", systemImage: "chart.xyaxis.line") }
                 .tag(2)
         }
         .tint(.accentColor)
     }
 }
