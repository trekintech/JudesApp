import SwiftUI

struct PlaybackView: View {
    let book: StoryBook

    @State private var audioManager = AudioManager()
    @State private var showSleepTimerPicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.nightBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 32)
                    .padding(.top, 16)

                // iPad landscape: cover left, words+controls right
                HStack(spacing: 40) {
                    coverArt
                        .frame(maxWidth: 360, maxHeight: 480)

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

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppTheme.soft)
            }

            Spacer()

            Text(book.title)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Button { showSleepTimerPicker = true } label: {
                Image(systemName: "moon.zzz.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.warm)
            }
        }
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
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.sky.opacity(0.4), AppTheme.ocean.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: AppTheme.ocean.opacity(0.4), radius: 20, y: 10)
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
                .fill(.white.opacity(0.06))
        )
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 48) {
            Button {
                audioManager.rewind(seconds: 10)
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.soft)
            }

            Button {
                audioManager.togglePlayback()
            } label: {
                Image(systemName: audioManager.playbackState == .playing
                      ? "pause.circle.fill"
                      : "play.circle.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }

            Button {
                audioManager.seek(to: audioManager.currentTime + 10)
            } label: {
                Image(systemName: "goforward.10")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.soft)
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.soft.opacity(0.2))
                        .frame(height: 6)

                    Capsule()
                        .fill(AppTheme.sky)
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
            .foregroundStyle(AppTheme.soft.opacity(0.6))
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
