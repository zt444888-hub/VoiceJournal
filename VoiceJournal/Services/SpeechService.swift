 import Foundation
 import Speech
 import AVFoundation
 
 /// Handles on-device speech-to-text transcription using Apple's Speech framework.
 /// All processing happens locally on the device - no network calls.
 /// NOT marked @Observable (inherits NSObject for delegate) — JournalViewModel bridges state.
 class SpeechService: NSObject {
     private let audioEngine = AVAudioEngine()
     private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
     private var recognitionTask: SFSpeechRecognitionTask?
     private let recognizer: SFSpeechRecognizer?
     
     var transcript = ""
     var onTranscriptUpdate: ((String) -> Void)?
     var onError: ((String) -> Void)?
     
     override init() {
         self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
         super.init()
         recognizer?.delegate = self
     }
     
     var isAuthorized: Bool { SFSpeechRecognizer.authorizationStatus() == .authorized }
     
     func requestAuthorization() async -> Bool {
         let status = await withCheckedContinuation { continuation in
             SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
         }
         return status == .authorized
     }
     
     func startRecording(audioSessionPreconfigured: Bool = false) throws {
         guard let recognizer = recognizer, recognizer.isAvailable else {
             onError?("Speech recognizer is not available")
             return
         }
         
         recognitionTask?.cancel()
         recognitionTask = nil
         
         if !audioSessionPreconfigured {
             let audioSession = AVAudioSession.sharedInstance()
             try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
             try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
         }
         
         recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
         guard let recognitionRequest = recognitionRequest else {
             onError?("Unable to create recognition request")
             return
         }
         recognitionRequest.shouldReportPartialResults = true
         
         let inputNode = audioEngine.inputNode
         let format = inputNode.outputFormat(forBus: 0)
         
         inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
             recognitionRequest.append(buffer)
         }
         
         audioEngine.prepare()
         try audioEngine.start()
         transcript = ""
         
         recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
             guard let self = self else { return }
             if let result = result {
                 let newText = result.bestTranscription.formattedString
                 self.transcript = newText
                 self.onTranscriptUpdate?(newText)
             }
             if error != nil { self.stopInternal() }
         }
     }
     
     /// Internal cleanup — does not deactivate session (AudioRecorder may still be active)
     private func stopInternal() {
         audioEngine.stop()
         audioEngine.inputNode.removeTap(onBus: 0)
         recognitionRequest?.endAudio()
         recognitionTask?.cancel()
         recognitionRequest = nil
         recognitionTask = nil
     }
     
     func stopRecording(deactivateSession: Bool = true) {
         stopInternal()
         transcript = ""
         if deactivateSession {
             try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
         }
     }
 }
 
 // MARK: - SFSpeechRecognizerDelegate
 extension SpeechService: SFSpeechRecognizerDelegate {
     func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
         if !available {
             onError?("Speech recognition is currently unavailable")
         }
     }
 }
