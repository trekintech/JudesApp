import AVFoundation
import Speech
import Observation

@Observable
final class ReadAloudManager: NSObject {

    enum ListenState {
        case idle
        case listening
        case matched
        case wrong
    }

    // MARK: - Public State

    private(set) var listenState: ListenState = .idle
    private(set) var lastHeardText = ""
    private(set) var isSpeakingHelp = false

    // MARK: - Private Properties

    private let speechRecognizer = SFSpeechRecognizer()
    private let synthesizer = AVSpeechSynthesizer()
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var wordAudioPlayer: AVAudioPlayer?

    private var targetWord = ""
    private var onMatch: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Listening

    /// Starts listening for a specific target word. Calls `onMatch` when the child says it.
    func startListening(for word: String, onMatch: @escaping () -> Void) {
        stopListening()
        targetWord = word.lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
        self.onMatch = onMatch
        lastHeardText = ""
        listenState = .listening

        guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }

        configureAudioSession(for: .record)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        request.addsPunctuation = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
            listenState = .idle
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let spoken = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.lastHeardText = spoken
                    self.checkForMatch(in: spoken)
                }
            }

            if error != nil || (result?.isFinal == true) {
                // Recognition ended — restart if we're still supposed to be listening
                DispatchQueue.main.async {
                    if self.listenState == .listening {
                        self.restartListening()
                    }
                }
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        listenState = .idle
        onMatch = nil
    }

    private func restartListening() {
        let word = targetWord
        let callback = onMatch
        stopListening()
        if let callback {
            startListening(for: word, onMatch: callback)
        }
    }

    // MARK: - Word Matching

    private func checkForMatch(in spokenText: String) {
        guard listenState == .listening else { return }
        let words = spokenText.lowercased()
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }

        // Check if any recently spoken word matches the target
        // Use the last few words to avoid requiring exact sequential order
        let recentWords = words.suffix(5)
        if recentWords.contains(where: { fuzzyMatch($0, target: targetWord) }) {
            listenState = .matched
            let callback = onMatch
            stopListening()
            callback?()
        }
    }

    /// Fuzzy match: exact match, or phonetically close for common child speech patterns
    private func fuzzyMatch(_ spoken: String, target: String) -> Bool {
        if spoken == target { return true }

        // Handle common young reader patterns:
        // "da" for "the", dropped endings, etc.
        // Use a simple edit-distance threshold for short words
        if target.count <= 3 {
            return spoken == target
        }

        // For longer words, allow the spoken word to be a close prefix
        // (child might not finish the word clearly)
        if spoken.count >= 3 && target.hasPrefix(spoken) && spoken.count >= target.count - 2 {
            return true
        }

        return false
    }

    // MARK: - Help: Play Parent's Recording of the Word

    /// Plays the segment of the parent's recording that corresponds to this word
    func playWordFromRecording(audioURL: URL, startTime: TimeInterval, duration: TimeInterval) {
        stopListening()
        isSpeakingHelp = true
        configureAudioSession(for: .playback)

        do {
            wordAudioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            wordAudioPlayer?.delegate = self
            wordAudioPlayer?.currentTime = startTime
            wordAudioPlayer?.prepareToPlay()
            wordAudioPlayer?.play()

            // Stop after the word's duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.3) { [weak self] in
                self?.wordAudioPlayer?.stop()
                self?.wordAudioPlayer = nil
                self?.isSpeakingHelp = false
            }
        } catch {
            // Fallback to TTS if audio segment fails
            isSpeakingHelp = false
        }
    }

    /// Fallback: use text-to-speech to say the word
    func speakWord(_ word: String) {
        stopListening()
        isSpeakingHelp = true
        configureAudioSession(for: .playback)

        let utterance = AVSpeechUtterance(string: word)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.7
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    // MARK: - Audio Session

    private func configureAudioSession(for category: AVAudioSession.Category) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(category, mode: .default, options: [])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session error: \(error)")
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension ReadAloudManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeakingHelp = false
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension ReadAloudManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isSpeakingHelp = false
        }
    }
}
