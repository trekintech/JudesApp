import SwiftUI

struct PlaybackView: View {
    let book: StoryBook

    @State private var audioManager = AudioManager()
    @State private var showSleepTimerPicker = false
    @State private var selectedSleepMinutes = 15
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button { showSleepTimerPicker = true } label: {
                        Image(systemName: "moon.zzz.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)

                // Main content - iPad landscape optimized
                HStack(spacing: 40) {
                    // Left: Cover art
                    coverArt
                        .frame(maxWidth: 360, maxHeight: 480)

                    // Right: Words + Controls
                    VStack(spacing: 24) {
                        karaokeText
                            .frame(maxHeight: .infinity)

                        playbackControls
                        progressBar
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(32)
            }
        }
        .onAppear(perform: beginPlayback)
        .onDisappear {
            audioManager.stopPlayback()
            audioManager.cancelSleepTimer()
        }
        .alert("Sleep Timer", isPresented: $showSleepTimerPicker) {
            Button("5 minutes") { audioManager.startSleepTimer(minutes: 5) }
            Button("10 minutes") { audioManager.startSleepTimer(minutes: 10) }
            Button("15 minutes") { audioManager.startSleepTimer(minutes: 15) }
            Button("30 minutes") { audioManager.startSleepTimer(minutes: 30) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Stop playing after...")
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.15, green: 0.10, blue: 0.30),
                Color(red: 0.05, green: 0.05, blue: 0.15)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Cover Art

    private var coverArt: some View {
        Group {
            if let imageData = book.coverImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }

    // MARK: - Karaoke Text

    private var karaokeText: some View {
        ScrollViewReader { proxy in
            ScrollView {
                WrappingHStack(
                    words: audioManager.activeTimedWords,
                    currentIndex: audioManager.currentWordIndex
                )
                .padding()
            }
            .onChange(of: audioManager.currentWordIndex) { _, newIndex in
                if let newIndex {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.5))
        )
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 48) {
            // Rewind
            Button {
                audioManager.rewind(seconds: 10)
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }

            // Play / Pause
            Button {
                audioManager.togglePlayback()
            } label: {
                Image(systemName: audioManager.playbackState == .playing
                      ? "pause.circle.fill"
                      : "play.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }

            // Forward
            Button {
                audioManager.seek(to: audioManager.currentTime + 10)
            } label: {
                Image(systemName: "goforward.10")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .frame(height: 6)

                    Capsule()
                        .fill(.white)
                        .frame(
                            width: audioManager.duration > 0
                                ? geo.size.width * (audioManager.currentTime / audioManager.duration)
                                : 0,
                            height: 6
                        )
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction = value.location.x / geo.size.width
                            let time = Double(fraction) * audioManager.duration
                            audioManager.seek(to: time)
                        }
                )
            }
            .frame(height: 6)

            HStack {
                Text(formatTime(audioManager.currentTime))
                Spacer()
                Text(formatTime(audioManager.duration))
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.bottom, 16)
    }

    // MARK: - Helpers

    private func beginPlayback() {
        guard let url = book.audioRecordingURL else { return }
        audioManager.startPlayback(url: url, timedWords: book.timedWords)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
