import SwiftUI
import SwiftData
import VisionKit
import Vision

struct AddBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var coverImageData: Data?
    @State private var showScanner = false
    @State private var audioManager = AudioManager()
    @State private var recordingURL: URL?
    @State private var audioFileName: String?
    @State private var transcriptionStatus: TranscriptionStatus = .idle
    @State private var transcribedWords: [TimedWord] = []
    @State private var errorMessage: String?
    @State private var showError = false

    enum TranscriptionStatus {
        case idle, transcribing, completed, failed
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
        && audioFileName != nil
        && transcriptionStatus == .completed
    }

    var body: some View {
        Form {
            coverSection
            titleSection
            recordingSection
            transcriptionSection
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.gridBackground.ignoresSafeArea())
        .navigationTitle("Add New Book")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    cleanupAndDismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveBook()
                }
                .fontWeight(.semibold)
                .disabled(!canSave)
            }
        }
        .sheet(isPresented: $showScanner) {
            DocumentScannerView { image in
                processCoverImage(image)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Cover Section

    private var coverSection: some View {
        Section {
            HStack(spacing: 20) {
                if let data = coverImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.pale)
                        .frame(width: 150, height: 200)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.largeTitle)
                                Text("No Cover")
                                    .font(.system(.caption, design: .rounded))
                            }
                            .foregroundStyle(AppTheme.ocean.opacity(0.4))
                        }
                }

                VStack(spacing: 12) {
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan Cover", systemImage: "doc.viewfinder")
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.ocean)

                    if coverImageData != nil {
                        Button(role: .destructive) {
                            coverImageData = nil
                        } label: {
                            Label("Remove", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Book Cover")
                .foregroundStyle(AppTheme.ocean)
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        Section {
            TextField("Book Title", text: $title)
                .font(.system(.title3, design: .rounded))
        } header: {
            Text("Title")
                .foregroundStyle(AppTheme.ocean)
        }
    }

    // MARK: - Recording Section

    private var recordingSection: some View {
        Section {
            switch audioManager.recordingState {
            case .idle:
                if audioFileName != nil {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Recording saved")
                            .font(.system(.body, design: .rounded))
                        Spacer()
                        Button("Re-record", role: .destructive) {
                            if let name = audioFileName {
                                audioManager.deleteRecording(fileName: name)
                            }
                            audioFileName = nil
                            recordingURL = nil
                            transcriptionStatus = .idle
                            transcribedWords = []
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button {
                        recordingURL = audioManager.startRecording()
                    } label: {
                        Label("Start Recording", systemImage: "mic.circle.fill")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.red)
                    }
                }

            case .recording:
                VStack(spacing: 12) {
                    HStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 12, height: 12)
                        Text("Recording...")
                            .font(.system(.headline, design: .rounded))
                        Spacer()
                        Text(formatDuration(audioManager.recordingDuration))
                            .font(.system(.body, design: .monospaced))
                    }
                    HStack(spacing: 16) {
                        Button {
                            audioManager.pauseRecording()
                        } label: {
                            Label("Pause", systemImage: "pause.circle.fill")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            finishRecording()
                        } label: {
                            Label("Stop", systemImage: "stop.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding(.vertical, 4)

            case .paused:
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "pause.circle")
                            .foregroundStyle(.orange)
                        Text("Paused")
                            .font(.system(.headline, design: .rounded))
                        Spacer()
                        Text(formatDuration(audioManager.recordingDuration))
                            .font(.system(.body, design: .monospaced))
                    }
                    HStack(spacing: 16) {
                        Button {
                            audioManager.resumeRecording()
                        } label: {
                            Label("Resume", systemImage: "mic.circle.fill")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            finishRecording()
                        } label: {
                            Label("Stop", systemImage: "stop.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Audio Recording")
                .foregroundStyle(AppTheme.ocean)
        }
    }

    // MARK: - Transcription Section

    private var transcriptionSection: some View {
        Section {
            switch transcriptionStatus {
            case .idle:
                if audioFileName != nil {
                    Text("Recording ready. Tap Save to begin.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Record audio first to enable transcription.")
                        .foregroundStyle(.secondary)
                }
            case .transcribing:
                HStack {
                    ProgressView()
                        .tint(AppTheme.ocean)
                    Text("Transcribing offline...")
                        .padding(.leading, 8)
                }
            case .completed:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("\(transcribedWords.count) words transcribed")
                }
            case .failed:
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Transcription failed. You can still save without karaoke text.")
                }
            }
        } header: {
            Text("Transcription")
                .foregroundStyle(AppTheme.ocean)
        }
    }

    // MARK: - Actions

    private func finishRecording() {
        guard let url = audioManager.stopRecording() else { return }
        audioFileName = url.lastPathComponent
        recordingURL = url
        startTranscription(url: url)
    }

    private func startTranscription(url: URL) {
        transcriptionStatus = .transcribing
        audioManager.transcribeAudio(at: url) { result in
            switch result {
            case .success(let words):
                transcribedWords = words
                transcriptionStatus = .completed
            case .failure(let error):
                errorMessage = error.localizedDescription
                transcriptionStatus = .failed
            }
        }
    }

    private func saveBook() {
        let book = StoryBook(
            title: title.trimmingCharacters(in: .whitespaces),
            coverImageData: coverImageData,
            audioFileName: audioFileName
        )

        modelContext.insert(book)

        for word in transcribedWords {
            word.book = book
            modelContext.insert(word)
        }

        dismiss()
    }

    private func cleanupAndDismiss() {
        if let name = audioFileName {
            audioManager.deleteRecording(fileName: name)
        }
        dismiss()
    }

    private func processCoverImage(_ image: UIImage) {
        coverImageData = image.jpegData(compressionQuality: 0.8)
        extractTitleFromImage(image)
    }

    private func extractTitleFromImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }

        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else { return }

            let recognizedStrings = observations
                .compactMap { $0.topCandidates(1).first?.string }

            let suggestedTitle = recognizedStrings.prefix(3).joined(separator: " ")

            DispatchQueue.main.async {
                if title.isEmpty && !suggestedTitle.isEmpty {
                    title = suggestedTitle
                }
            }
        }
        request.recognitionLevel = .accurate

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Document Scanner Wrapper

struct DocumentScannerView: UIViewControllerRepresentable {
    let onScan: (UIImage) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (UIImage) -> Void

        init(onScan: @escaping (UIImage) -> Void) {
            self.onScan = onScan
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            if scan.pageCount > 0 {
                let image = scan.imageOfPage(at: 0)
                onScan(image)
            }
            controller.dismiss(animated: true)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            controller.dismiss(animated: true)
        }
    }
}
