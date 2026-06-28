import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @Environment(JournalViewModel.self) private var journalVM
    @State private var store = StoreManager.shared
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var showResetAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Daily Reminder", isOn: Binding(get: { true }, set: { if $0 { UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.sound]) { _, _ in } } }))
                    VStack(spacing: 8) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 40)).foregroundStyle(.tint)
                        Text("VoiceJournal").font(.title2.weight(.bold))
                        Text("Your private voice diary").font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                
                if !store.isPro {
                    Section("VoiceJournal Pro") {
                        VStack(spacing: 12) {
                            Text("Unlock Unlimited").font(.headline)
                            Text("✓ Unlimited daily entries\n✓ Export to CSV/JSON\n✓ Priority support")
                                .font(.subheadline).foregroundColor(.secondary)
                            if let product = store.product {
                                Button {
                                    Task { await store.purchase() }
                                } label: {
                                    Text("Upgrade - \(product.displayPrice)")
                                        .font(.headline).foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(.blue, in: Capsule())
                                }
                                .disabled(store.isLoading)
                            }
                            Button("Restore Purchases") {
                                Task { await store.restore() }
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    Section("VoiceJournal Pro") {
                        HStack {
                            Image(systemName: "checkmark.seal.fill").foregroundColor(.blue)
                            Text("Pro Active").fontWeight(.semibold)
                        }
                    }
                }
                
                Section("Export Data") {
                    Button {
                        if let url = journalVM.exportCSV() {
                            exportURL = url; showExportSheet = true
                        }
                    } label: {
                        Label("Export as CSV", systemImage: "tablecells")
                    }
                    .disabled(!store.isPro)
                    
                    Button {
                        if let url = journalVM.exportJSON() {
                            exportURL = url; showExportSheet = true
                        }
                    } label: {
                        Label("Export as JSON", systemImage: "curlybraces")
                    }
                    .disabled(!store.isPro)
                }
                
                Section("Data") {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version"); Spacer(); Text("1.0").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Daily Free Limit"); Spacer(); Text("\(StoreManager.shared.freeDailyLimit)/day").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Reset All Data?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    for entry in journalVM.entries { journalVM.deleteEntry(entry) }
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .sheet(item: $exportURL) { url in
                ShareSheet(items: [url])
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ ui: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
