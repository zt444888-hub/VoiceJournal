import SwiftUI
import AVFoundation

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
                headerSection
                if entry.audioFileName != nil { audioPlaybackSection }
                transcriptSection
                insightsSection
                metadataSection
            }.padding()
        }
        .navigationTitle("Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing { journalVM.updateEntry(entry, title: editedTitle, transcript: editedTranscript) }
                    withAnimation { isEditing.toggle() }
                }
            }
        }
        .onAppear { editedTitle = entry.safeTitle; editedTranscript = entry.safeTranscript }
        .onDisappear { stopPlayback() }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.sentimentEmoji).font(.largeTitle)
                if isEditing {
                    TextField("Title", text: $editedTitle).textFieldStyle(.roundedBorder).font(.title2.bold())
                } else { Text(entry.safeTitle).font(.title2).fontWeight(.bold) }
            }
            Text(entry.formattedDate).font(.subheadline).foregroundColor(.secondary)
        }
    }
    
    // MARK: - Audio
    private var audioPlaybackSection: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color(.systemGray5)).frame(height: 4)
                    Rectangle().fill(Color.accentColor).frame(width: geo.size.width * playbackProgress, height: 4)
                }
            }.frame(height: 4)
            HStack {
                Button { togglePlayback() } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 36)).foregroundColor(.accentColor)
                }.buttonStyle(.plain)
                Text(entry.formattedDuration).font(.caption).foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { speed in
                        Button(speed == 1.0 ? "1x" : "\(speed, specifier: "%.1f")x") {
                            audioPlayer?.enableRate = true
                            audioPlayer?.rate = Float(speed)
                        }
                        .font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(.systemGray5)).clipShape(Capsule())
                    }
                }
                Image(systemName: "waveform").foregroundColor(.secondary)
            }
        }.padding().background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Transcript
    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Transcript", systemImage: "text.quote").font(.headline)
            if isEditing {
                TextEditor(text: $editedTranscript).frame(minHeight: 200).padding(8).background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 8))
            } else { Text(entry.safeTranscript).font(.body).lineSpacing(6) }
        }
    }
    
    // MARK: - Insights
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI Insights", systemImage: "sparkles").font(.headline)
            Text(sentimentAnalyzer.generateInsight(from: entry.safeTranscript)).font(.subheadline).foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("Mood").font(.caption).foregroundColor(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(LinearGradient(colors: [.red, .orange, .yellow, .green], startPoint: .leading, endPoint: .trailing)).frame(height: 8).clipShape(Capsule())
                        Circle().fill(.white).frame(width: 14, height: 14).shadow(radius: 1).offset(x: (CGFloat(entry.sentimentScore + 1) / 2) * (geo.size.width - 14))
                    }
                }.frame(height: 8)
            }
        }.padding().background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Metadata
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Details", systemImage: "info.circle").font(.headline)
            HStack {
                VStack(spacing: 2) { Text("Duration").font(.caption2).foregroundColor(.secondary); Text(entry.formattedDuration).font(.caption).fontWeight(.medium) }
                Spacer()
                VStack(spacing: 2) { Text("Words").font(.caption2).foregroundColor(.secondary); Text("\(entry.safeTranscript.split(separator: " ").count)").font(.caption).fontWeight(.medium) }
                Spacer()
                VStack(spacing: 2) { Text("Created").font(.caption2).foregroundColor(.secondary); Text(entry.formattedDate).font(.caption).fontWeight(.medium) }
            }
        }
    }
    
    // MARK: - Playback
    private func togglePlayback() {
        guard let fileName = entry.audioFileName, let url = AudioRecorder.playbackURL(for: fileName) else { return }
        if isPlaying { pausePlayback(); return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            if audioPlayer == nil { audioPlayer = try AVAudioPlayer(contentsOf: url); audioPlayer?.prepareToPlay() }
            audioPlayer?.play()
            isPlaying = true
            playbackTimer?.invalidate()
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                guard let p = audioPlayer, p.isPlaying else { stopPlayback(); return }
                playbackProgress = p.currentTime / p.duration
            }
        } catch { print("Playback failed: \(error)") }
    }
    
    private func pausePlayback() { audioPlayer?.pause(); isPlaying = false; playbackTimer?.invalidate(); playbackTimer = nil }
    private func stopPlayback() { audioPlayer?.stop(); audioPlayer = nil; isPlaying = false; playbackTimer?.invalidate(); playbackTimer = nil; playbackProgress = 0; try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
}
