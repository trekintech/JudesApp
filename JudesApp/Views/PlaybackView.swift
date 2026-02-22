import SwiftUI

struct PlaybackView: View {
    let book: StoryBook

    @State private var audioManager = AudioManager()
    @State private var showSleepTimerPicker = false
    @State private var showCelebration = false
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

            // Celebration overlay
            if showCelebration {
                StoryCelebrationView {
                    withAnimation { showCelebration = false }
                    dismiss()
                }
                .transition(.opacity)
            }
        }
        .onAppear(perform: beginPlayback)
        .onDisappear {
            audioManager.stopPlayback()
            audioManager.cancelSleepTimer()
        }
        .onChange(of: audioManager.didFinishStory) { _, finished in
            if finished {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showCelebration = true
                }
            }
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

// MARK: - Story Celebration Overlay

struct StoryCelebrationView: View {
    var onDismiss: () -> Void

    @State private var confettiVisible = false
    @State private var overlayOpacity = 0.0

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Confetti-style stars
                if confettiVisible {
                    ConfettiStars()
                        .frame(height: 120)
                }

                AvatarView(mood: .thumbsUp, size: 120, showGreeting: true)

                Button {
                    onDismiss()
                } label: {
                    Text("Back to Stories")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.warm)
            }
            .opacity(overlayOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                overlayOpacity = 1.0
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.2)) {
                confettiVisible = true
            }
        }
    }
}

// MARK: - Confetti Stars

struct ConfettiStars: View {
    @State private var animate = false

    private let stars = (0..<12).map { _ in
        (
            x: CGFloat.random(in: -150...150),
            y: CGFloat.random(in: -60...60),
            size: CGFloat.random(in: 14...30),
            rotation: Double.random(in: 0...360),
            delay: Double.random(in: 0...0.4)
        )
    }

    var body: some View {
        ZStack {
            ForEach(0..<stars.count, id: \.self) { i in
                let star = stars[i]
                Image(systemName: "star.fill")
                    .font(.system(size: star.size))
                    .foregroundStyle(
                        [AppTheme.warm, AppTheme.sky, .yellow, .orange, .pink][i % 5]
                    )
                    .rotationEffect(.degrees(animate ? star.rotation + 180 : star.rotation))
                    .offset(x: star.x, y: animate ? star.y : star.y - 40)
                    .opacity(animate ? 1 : 0)
                    .scaleEffect(animate ? 1 : 0.3)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.5).delay(star.delay),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}
