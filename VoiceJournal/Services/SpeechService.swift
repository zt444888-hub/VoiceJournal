import Foundation
import Speech

/// Post-recording speech-to-text. No AVAudioEngine / installTap (crashes on simulator without mic).
class SpeechService: NSObject {
    private let recognizer: SFSpeechRecognizer?
    
    var onError: ((String) -> Void)?
    
    override init() {
        if let pref = Locale.preferredLanguages.first.map({ Locale(identifier: $0) }),
           pref.languageCode == "en", let r = SFSpeechRecognizer(locale: pref) {
            self.recognizer = r
        } else {
            self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
        super.init()
        recognizer?.delegate = self
    }
    
    var isAuthorized: Bool { SFSpeechRecognizer.authorizationStatus() == .authorized }
    
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
    }
    
    /// Transcribe a recorded audio file. Call after AudioRecorder.stopRecording().
    func transcribeAudio(at url: URL) async -> String {
        guard let recognizer = recognizer, recognizer.isAvailable else { return "" }
        let request = SFSpeechURLRecognitionRequest(url: url)
        return await withCheckedContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                continuation.resume(returning: result?.bestTranscription.formattedString ?? "")
            }
        }
    }
}

extension SpeechService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available { onError?("Speech recognition unavailable") }
    }
}
