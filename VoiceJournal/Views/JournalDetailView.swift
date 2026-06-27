 import SwiftUI
 import AVFoundation
 import NaturalLanguage
 
 /// Shows a single journal entry with transcript, sentiment, audio playback, and edit capabilities.
 struct JournalDetailView: View {
     @Environment(JournalViewModel.self) private var journalVM
     let entry: JournalEntry
     @State private var isEditing = false
     @State private var editedTitle = ""
     @State private var editedTranscript = ""
     @State private var audioPlayer: AVAudioPlayer?
     @State private var isPlaying = false
     @State private var playbackProgress: Double = 0
     @State private var playbackTimer: Timer?
     
     private let sentimentAnalyzer = SentimentAnalyzer()
     
     var body: some View {
         ScrollView {
             VStack(alignment: .leading, spacing: 20) {
                 // Header
                 headerSection
                 
                 // Audio playback
                 if entry.audioFileName != nil {
                     audioPlaybackSection
                 }
                 
                 // Transcript
                 transcriptSection
                 
                 // AI Insights
                 insightsSection
                 
                 // Metadata
                 metadataSection
             }
             .padding()
         }
         .navigationTitle("Entry")
         .navigationBarTitleDisplayMode(.inline)
         .toolbar {
             ToolbarItem(placement: .navigationBarTrailing) {
                 Button(isEditing ? "Done" : "Edit") {
                     if isEditing {
                         journalVM.updateEntry(entry, title: editedTitle, transcript: editedTranscript)
                     }
                     withAnimation { isEditing.toggle() }
                 }
             }
         }
         .onDisappear {
             audioPlayer?.stop()
             playbackTimer?.invalidate()
         }
     }
     
     // MARK: - Header
     private var headerSection: some View {
         VStack(alignment: .leading, spacing: 8) {
             HStack {
                 Text(entry.sentimentEmoji)
                     .font(.largeTitle)
                 
                 if isEditing {
                     TextField("Title", text: $editedTitle)
                         .textFieldStyle(.roundedBorder)
                         .font(.title2.bold())
                 } else {
                     Text(entry.safeTitle)
                         .font(.title2)
                         .fontWeight(.bold)
                 }
             }
             
             Text(entry.formattedDate)
                 .font(.subheadline)
                 .foregroundColor(.secondary)
         }
     }
     
     // MARK: - Audio Playback
     private var audioPlaybackSection: some View {
         VStack(spacing: 12) {
             // Playback progress bar
             GeometryReader { geo in
                 ZStack(alignment: .leading) {
                     Rectangle()
                         .fill(Color(.systemGray5))
                         .frame(height: 4)
                     
                     Rectangle()
                         .fill(Color.accentColor)
                         .frame(width: geo.size.width * playbackProgress, height: 4)
                 }
             }
             .frame(height: 4)
             
             HStack {
                 Button {
                     togglePlayback()
                 } label: {
                     Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                         .font(.system(size: 36))
                         .foregroundColor(.accentColor)
                 }
                 .buttonStyle(.plain)
                 
                 Text(entry.formattedDuration)
                     .font(.caption)
                     .foregroundColor(.secondary)
                 
                 Spacer()
                 
                 Image(systemName: "waveform")
                     .foregroundColor(.secondary)
             }
         }
         .padding()
         .background(Color(.systemGray6))
         .clipShape(RoundedRectangle(cornerRadius: 12))
     }
     
     // MARK: - Transcript
     private var transcriptSection: some View {
         VStack(alignment: .leading, spacing: 8) {
             Label("Transcript", systemImage: "text.quote")
                 .font(.headline)
             
             if isEditing {
                 TextEditor(text: $editedTranscript)
                     .frame(minHeight: 200)
                     .padding(8)
                     .background(Color(.systemGray6))
                     .clipShape(RoundedRectangle(cornerRadius: 8))
             } else {
                 Text(entry.safeTranscript)
                     .font(.body)
                     .lineSpacing(6)
             }
         }
     }
     
     // MARK: - AI Insights
     private var insightsSection: some View {
         VStack(alignment: .leading, spacing: 12) {
             Label("AI Insights", systemImage: "sparkles")
                 .font(.headline)
             
             let insights = sentimentAnalyzer.generateInsight(from: entry.safeTranscript)
             
             Text(insights)
                 .font(.subheadline)
                 .foregroundColor(.secondary)
             
             // Mood bar
             VStack(alignment: .leading, spacing: 4) {
                 Text("Mood")
                     .font(.caption)
                     .foregroundColor(.secondary)
                 
                 GeometryReader { geo in
                     ZStack(alignment: .leading) {
                         Rectangle()
                             .fill(
                                 LinearGradient(
                                     colors: [.red, .orange, .yellow, .green],
                                     startPoint: .leading,
                                     endPoint: .trailing
                                 )
                             )
                             .frame(height: 8)
                             .clipShape(Capsule())
                         
                         Circle()
                             .fill(.white)
                             .frame(width: 14, height: 14)
                             .shadow(radius: 1)
                             .offset(x: (CGFloat(entry.sentimentScore + 1) / 2) * (geo.size.width - 14))
                     }
                 }
                 .frame(height: 8)
             }
         }
         .padding()
         .background(Color(.systemGray6))
         .clipShape(RoundedRectangle(cornerRadius: 12))
     }
     
     // MARK: - Metadata
     private var metadataSection: some View {
         VStack(alignment: .leading, spacing: 8) {
             Label("Details", systemImage: "info.circle")
                 .font(.headline)
             
             HStack {
                 detailItem(label: "Duration", value: entry.formattedDuration)
                 Spacer()
                 detailItem(label: "Words", value: "\(entry.safeTranscript.split(separator: " ").count)")
                 Spacer()
                 detailItem(label: "Created", value: entry.formattedDate)
             }
         }
     }
     
     private func detailItem(label: String, value: String) -> some View {
         VStack(spacing: 2) {
             Text(label)
                 .font(.caption2)
                 .foregroundColor(.secondary)
             Text(value)
                 .font(.caption)
                 .fontWeight(.medium)
         }
     }
     
     // MARK: - Playback
     private func togglePlayback() {
         guard let fileName = entry.audioFileName,
               let url = AudioRecorder.playbackURL(for: fileName) else { return }
         
         if isPlaying {
             audioPlayer?.pause()
             isPlaying = false
             playbackTimer?.invalidate()
         } else {
             do {
                 if audioPlayer == nil {
                     audioPlayer = try AVAudioPlayer(contentsOf: url)
                     audioPlayer?.prepareToPlay()
                 }
                 audioPlayer?.play()
                 isPlaying = true
                 
                 playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                     guard let player = audioPlayer, player.isPlaying else {
                         isPlaying = false
                         playbackTimer?.invalidate()
                         return
                     }
                     playbackProgress = player.currentTime / player.duration
                 }
             } catch {
                 print("Playback failed: \(error)")
             }
         }
     }
 }
