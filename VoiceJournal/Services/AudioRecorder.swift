 import Foundation
 import AVFoundation
 
 /// Manages audio file recording (.m4a). 22050Hz sample rate (optimal for speech).
 class AudioRecorder: NSObject {
     private var recorder: AVAudioRecorder?
     private(set) var isRecording = false
     private(set) var currentFilePath: URL?
     private(set) var recordingDuration: TimeInterval = 0
     
     private var timer: Timer?
     private let fileManager = FileManager.default
     
     var onUpdate: ((TimeInterval) -> Void)?
     var onError: ((String) -> Void)?
     
     // MARK: - Paths
     private var audioDirectory: URL {
         let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
         let audioDir = docs.appendingPathComponent("AudioRecordings", isDirectory: true)
         if !fileManager.fileExists(atPath: audioDir.path) {
             try? fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true)
         }
         return audioDir
     }
     
     static func playbackURL(for fileName: String) -> URL? {
         let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
         let url = docs.appendingPathComponent("AudioRecordings").appendingPathComponent(fileName)
         return FileManager.default.fileExists(atPath: url.path) ? url : nil
     }
     
     // MARK: - Recording
     func startRecording() throws {
         let fileName = "journal_\(UUID().uuidString).m4a"
         let fileURL = audioDirectory.appendingPathComponent(fileName)
         currentFilePath = fileURL
         
         let settings: [String: Any] = [
             AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
             AVSampleRateKey: 22050.0,
             AVNumberOfChannelsKey: 1,
             AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
         ]
         
         recorder = try AVAudioRecorder(url: fileURL, settings: settings)
         recorder?.delegate = self
         recorder?.isMeteringEnabled = true
         recorder?.record()
         isRecording = true
         
         recordingDuration = 0
         timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
             guard let self = self, let recorder = self.recorder, recorder.isRecording else { return }
             self.recordingDuration = recorder.currentTime
             self.onUpdate?(recorder.currentTime)
         }
     }
     
     func stopRecording() -> URL? {
         recorder?.stop()
         isRecording = false
         timer?.invalidate()
         timer = nil
         let url = currentFilePath
         currentFilePath = nil
         recorder = nil
         return url
     }
     
     func deleteRecording(at url: URL) {
         try? fileManager.removeItem(at: url)
     }
     
     static func deleteRecording(named fileName: String) {
         if let url = playbackURL(for: fileName) {
             try? FileManager.default.removeItem(at: url)
         }
     }
     
     // MARK: - Cleanup
     /// Removes orphaned audio files not referenced by any current journal entry
     static func cleanOrphanedAudioFiles(activeFileNames: Set<String>) {
         let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
         let audioDir = docs.appendingPathComponent("AudioRecordings", isDirectory: true)
         guard let files = try? FileManager.default.contentsOfDirectory(atPath: audioDir.path) else { return }
         for file in files {
             if !activeFileNames.contains(file) {
                 try? FileManager.default.removeItem(at: audioDir.appendingPathComponent(file))
             }
         }
     }
 }
 
 // MARK: - AVAudioRecorderDelegate
 extension AudioRecorder: AVAudioRecorderDelegate {
     func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
         isRecording = false
         if !flag { onError?("Recording failed to complete") }
     }
     
     func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
         isRecording = false
         onError?(error?.localizedDescription ?? "Audio encode error")
     }
 }
