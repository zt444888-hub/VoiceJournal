 import SwiftUI
 
 /// Big animated mic button, live transcription preview, recent entries.
 struct RecordView: View {
     @Environment(JournalViewModel.self) private var journalVM
     @State private var showPermissionAlert = false
     @State private var showingSaved = false
     
     var body: some View {
         NavigationStack {
             VStack(spacing: 24) {
                 Spacer()
                 recordButton
                 statusText
                 
                 if journalVM.isRecording || !journalVM.liveTranscript.isEmpty {
                     transcriptPreview
                 }
                 
                 if !journalVM.entries.isEmpty {
                     recentEntriesSection
                 }
                 
                 Spacer()
             }
             .padding()
             .navigationTitle("Voice Journal")
             .navigationBarTitleDisplayMode(.large)
             .toolbar {
                 ToolbarItem(placement: .navigationBarTrailing) {
                     if journalVM.isRecording {
                         Button("Cancel") { journalVM.cancelRecording() }
                             .foregroundColor(.red)
                     }
                 }
             }
             .onAppear {
                 if !journalVM.isAuthorized {
                     Task { await journalVM.requestPermissions() }
                 }
                 journalVM.refreshEntries()
             }
             .alert("Permission Required", isPresented: $showPermissionAlert) {
                 Button("Settings") {
                     if let url = URL(string: UIApplication.openSettingsURLString) {
                         UIApplication.shared.open(url)
                     }
                 }
                 Button("Cancel", role: .cancel) {}
             } message: {
                 Text("Microphone and speech recognition access is needed.")
             }
             .overlay { if showingSaved { savedOverlay } }
         }
     }
     
     // MARK: - Record Button
     private var recordButton: some View {
         Button {
             if !journalVM.isAuthorized {
                 showPermissionAlert = true
                 return
             }
             if journalVM.isRecording {
                 withAnimation(.spring(response: 0.3)) { journalVM.stopRecording() }
                 withAnimation(.easeInOut(duration: 0.5)) { showingSaved = true }
                 DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                     withAnimation(.easeInOut(duration: 0.3)) { showingSaved = false }
                 }
             } else {
                 withAnimation(.spring(response: 0.3)) { journalVM.startRecording() }
             }
         } label: {
             ZStack {
                 Circle()
                     .fill(journalVM.isRecording ? Color.red.opacity(0.15) : Color.blue.opacity(0.1))
                     .frame(width: 200, height: 200)
                 Circle()
                     .fill(journalVM.isRecording
                         ? LinearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom)
                         : LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom))
                     .frame(width: 140, height: 140)
                 Image(systemName: journalVM.isRecording ? "stop.fill" : "mic.fill")
                     .font(.system(size: 48))
                     .foregroundColor(.white)
                     .scaleEffect(journalVM.isRecording ? 0.8 : 1.0)
             }
         }
         .buttonStyle(.plain)
         .scaleEffect(journalVM.isRecording ? 1.1 : 1.0)
         .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: journalVM.isRecording)
     }
     
     // MARK: - Status
     private var statusText: some View {
         VStack(spacing: 8) {
             if journalVM.isRecording {
                 Text("Recording...")
                     .font(.headline)
                     .foregroundColor(.red)
                 Text(formatDuration(journalVM.recordingDuration))
                     .font(.title2.monospacedDigit())
                     .foregroundColor(.secondary)
             } else if journalVM.isProcessing {
                 HStack(spacing: 8) {
                     ProgressView()
                     Text("Processing...")
                 }
                 .foregroundColor(.secondary)
             } else {
                 Text("Tap to record your thoughts")
                     .font(.headline)
                     .foregroundColor(.secondary)
                 Text("All data stays on your device")
                     .font(.caption)
                     .foregroundColor(.tertiary)
             }
         }
     }
     
     // MARK: - Transcript
     private var transcriptPreview: some View {
         VStack(alignment: .leading, spacing: 8) {
             Label("Live Transcription", systemImage: "text.quote")
                 .font(.caption)
                 .foregroundColor(.secondary)
             ScrollView {
                 Text(journalVM.liveTranscript.isEmpty ? "Speak now..." : journalVM.liveTranscript)
                     .font(.body)
                     .foregroundColor(journalVM.liveTranscript.isEmpty ? .secondary : .primary)
                     .frame(maxWidth: .infinity, alignment: .leading)
                     .padding()
             }
             .frame(height: journalVM.isRecording ? 120 : 200)
             .background(Color(.systemGray6))
             .clipShape(RoundedRectangle(cornerRadius: 12))
         }
         .padding(.horizontal)
         .transition(.move(edge: .bottom).combined(with: .opacity))
     }
     
     // MARK: - Recent
     private var recentEntriesSection: some View {
         VStack(alignment: .leading, spacing: 8) {
             Text("Recent Entries").font(.headline)
             ScrollView(.horizontal, showsIndicators: false) {
                 HStack(spacing: 12) {
                     ForEach(Array(journalVM.entries.prefix(5))) { entry in
                         NavigationLink(destination: JournalDetailView(entry: entry)) {
                             recentEntryCard(entry)
                         }
                         .buttonStyle(.plain)
                     }
                 }
                 .padding(.horizontal, 2)
             }
         }
         .padding(.horizontal)
     }
     
     private func recentEntryCard(_ entry: JournalEntry) -> some View {
         VStack(alignment: .leading, spacing: 6) {
             HStack {
                 Text(entry.sentimentEmoji).font(.title2)
                 Spacer()
                 Text(entry.formattedDuration).font(.caption2).foregroundColor(.secondary)
             }
             Text(entry.safeTitle).font(.caption).fontWeight(.medium).lineLimit(1)
             Text(entry.formattedDate).font(.caption2).foregroundColor(.secondary)
         }
         .padding(12)
         .frame(width: 130)
         .background(Color(.systemGray6))
         .clipShape(RoundedRectangle(cornerRadius: 10))
     }
     
     // MARK: - Overlay
     private var savedOverlay: some View {
         VStack {
             Image(systemName: "checkmark.circle.fill").font(.system(size: 60)).foregroundColor(.green)
             Text("Entry Saved!").font(.title3).fontWeight(.semibold)
         }
         .padding(40)
         .background(.ultraThinMaterial)
         .clipShape(RoundedRectangle(cornerRadius: 20))
     }
     
     private func formatDuration(_ seconds: TimeInterval) -> String {
         String(format: "%02d:%02d", Int(seconds) / 60, Int(seconds) % 60)
     }
 }
