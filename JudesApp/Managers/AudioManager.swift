import AVFoundation
import Speech
import SwiftData
import Observation

@Observable
final class AudioManager: NSObject {

    // MARK: - State

    enum RecordingState {
        case idle, recording, paused
    }

    enum PlaybackState {
        case idle, playing, paused
    }

    private(set) var recordingState: RecordingState = .idle
    private(set) var playbackState: PlaybackState = .idle
    private(set) var didFinishStory = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var recordingDuration: TimeInterval = 0

    var currentWordIndex: Int? {
        guard playbackState == .playing || playbackState == .paused,
              !activeTimedWords.isEmpty else { return nil }
        let time = currentTime
        return activeTimedWords.firstIndex { word in
            time >= word.startTime && time < word.startTime + word.duration
        }
    }

    private(set) var activeTimedWords: [TimedWord] = []

    // MARK: - Private Properties

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    private var recordingTimer: Timer?
    private var currentRecordingURL: URL?

    /// Persistent recognizer — avoids cold-start model loading on each transcription
    private lazy var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()

    // MARK: - Audio Session

    private func configureAudioSession(for category: AVAudioSession.Category) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(category, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Recording

    func startRecording() -> URL? {
        configureAudioSession(for: .record)

        let documentsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first!

        let fileName = "recording_\(UUID().uuidString).m4a"
        let fileURL = documentsURL.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            currentRecordingURL = fileURL
            recordingState = .recording
            recordingDuration = 0
            startRecordingTimer()
            return fileURL
        } catch {
            print("Recording failed to start: \(error.localizedDescription)")
            return nil
        }
    }

    func pauseRecording() {
        audioRecorder?.pause()
        recordingState = .paused
        stopRecordingTimer()
    }

    func resumeRecording() {
        audioRecorder?.record()
        recordingState = .recording
        startRecordingTimer()
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        recordingState = .idle
        stopRecordingTimer()
        let url = currentRecordingURL
        audioRecorder = nil
        return url
    }

    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.audioRecorder else { return }
            self.recordingDuration = recorder.currentTime
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    // MARK: - Playback

    func startPlayback(url: URL, timedWords: [TimedWord]) {
        stopPlayback()
        didFinishStory = false
        configureAudioSession(for: .playback)

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            activeTimedWords = timedWords.sorted { $0.index < $1.index }
            audioPlayer?.play()
            playbackState = .playing
            startDisplayLink()
        } catch {
            print("Playback failed: \(error.localizedDescription)")
        }
    }

    func togglePlayback() {
        guard let player = audioPlayer else { return }
        if player.isPlaying {
            player.pause()
            playbackState = .paused
            stopDisplayLink()
        } else {
            player.play()
            playbackState = .playing
            startDisplayLink()
        }
    }

    func rewind(seconds: TimeInterval = 10) {
        guard let player = audioPlayer else { return }
        player.currentTime = max(0, player.currentTime - seconds)
        currentTime = player.currentTime
    }

    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        player.currentTime = min(max(0, time), player.duration)
        currentTime = player.currentTime
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackState = .idle
        currentTime = 0
        duration = 0
        activeTimedWords = []
        stopDisplayLink()
    }

    // MARK: - Display Link (sync currentTime to audio)

    private func startDisplayLink() {
        stopDisplayLink()
        displayLink = CADisplayLink(target: self, selector: #selector(updatePlaybackTime))
        displayLink?.preferredFrameRateRange = .init(minimum: 15, maximum: 30, preferred: 30)
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updatePlaybackTime() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
    }

    // MARK: - Speech Transcription

    /// Pre-warms the speech recognizer so the on-device model is loaded before
    /// the user finishes recording. Call from AddBookView.onAppear.
    func warmUpRecognizer() {
        SFSpeechRecognizer.requestAuthorization { [weak self] _ in
            // Access the lazy recognizer to trigger model loading
            _ = self?.speechRecognizer?.isAvailable
        }
    }

    func transcribeAudio(
        at url: URL,
        completion: @escaping (Result<[TimedWord], Error>) -> Void
    ) {
        guard let recognizer = speechRecognizer,
              recognizer.isAvailable else {
            completion(.failure(TranscriptionError.recognizerUnavailable))
            return
        }

        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                completion(.failure(TranscriptionError.notAuthorized))
                return
            }

            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            request.addsPunctuation = false

            // Prefer on-device but don't require it — server is faster and
            // avoids the cold-start gap that drops the first ~20s of audio
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }

            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }

                guard let result, result.isFinal else { return }

                let segments = result.bestTranscription.segments
                let timedWords: [TimedWord] = segments.enumerated().map { index, segment in
                    TimedWord(
                        word: segment.substring,
                        startTime: segment.timestamp,
                        duration: segment.duration,
                        index: index
                    )
                }

                DispatchQueue.main.async {
                    completion(.success(timedWords))
                }
            }
        }
    }

    // MARK: - Sleep Timer

    private var sleepTimer: Timer?

    func startSleepTimer(minutes: Int) {
        cancelSleepTimer()
        sleepTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(minutes * 60),
            repeats: false
        ) { [weak self] _ in
            self?.stopPlayback()
        }
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
    }

    // MARK: - Cleanup

    func deleteRecording(fileName: String) {
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first!
        let fileURL = documentsURL.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            recordingState = .idle
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playbackState = .idle
        currentTime = 0
        stopDisplayLink()
        if flag {
            didFinishStory = true
        }
    }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case recognizerUnavailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is not available on this device."
        case .notAuthorized:
            return "Speech recognition permission was not granted."
        }
    }
}
