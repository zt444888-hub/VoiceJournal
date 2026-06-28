 import SwiftUI
 
 /// Minimum deployment: iOS 17.0
 @main
 struct VoiceJournalApp: App {
     @State private var journalVM = JournalViewModel()
    @State private var biometricLock = BiometricLockService()
     
     var body: some Scene {
         WindowGroup {
             ZStack {                Color(.systemBackground).ignoresSafeArea()
            ContentView()
            if biometricLock.isLocked {
                BiometricLockView()
                    .environment(biometricLock)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(.default, value: biometricLock.isLocked)
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
         .background(Color(.systemBackground))        .background(Color(.systemBackground)).tint(.accentColor)
     }
 }


// MARK: - Biometric Lock
struct BiometricLockView: View {
    @Environment(BiometricLockService.self) private var lock
    
    var body: some View {
        ZStack {                Color(.systemBackground).ignoresSafeArea()
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                Text("Voice Journal").font(.title2).fontWeight(.bold)
                Text("Locked").foregroundColor(.secondary)
                Button("Unlock") {
                    Task { await lock.authenticate() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}