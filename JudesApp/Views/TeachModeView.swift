import SwiftUI

struct TeachModeView: View {
    let book: StoryBook

    @State private var manager = ReadAloudManager()
    @State private var words: [TimedWord] = []
    @State private var currentIndex = 0
    @State private var score = 0
    @State private var streak = 0
    @State private var showStarBurst = false
    @State private var showMilestone = false
    @State private var wordResult: WordResult = .waiting
    @State private var isFinished = false
    @Environment(\.dismiss) private var dismiss

    enum WordResult {
        case waiting, correct, helped
    }

    private var currentWord: TimedWord? {
        guard currentIndex < words.count else { return nil }
        return words[currentIndex]
    }

    private var progress: Double {
        guard !words.isEmpty else { return 0 }
        return Double(currentIndex) / Double(words.count)
    }

    var body: some View {
        ZStack {
            AppTheme.nightBackground.ignoresSafeArea()

            if words.isEmpty {
                noWordsState
            } else if isFinished {
                finishedState
            } else {
                teachContent
            }
        }
        .onAppear {
            words = book.timedWords.sorted { $0.index < $1.index }
            if !words.isEmpty {
                listenForCurrentWord()
            }
        }
        .onDisappear {
            manager.stopListening()
        }
    }

    // MARK: - No Words State

    private var noWordsState: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.soft)
            Text("No words to practice")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
            Text("This book needs a recording with transcription first.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button("Go Back") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.ocean)
        }
        .padding(40)
    }

    // MARK: - Main Teaching Content

    private var teachContent: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar
                .padding(.horizontal, 32)
                .padding(.top, 16)

            Spacer()

            // Context line (surrounding words, dimmed)
            contextLine
                .padding(.bottom, 12)

            // Current word - big and centered
            currentWordDisplay
                .padding(.bottom, 24)

            // Listening indicator
            listeningIndicator
                .padding(.bottom, 32)

            // Help button
            helpButton
                .padding(.bottom, 16)

            Spacer()

            // Progress bar
            progressSection
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
        }

        // Star burst overlay
        .overlay {
            if showStarBurst {
                StarBurstView()
                    .allowsHitTesting(false)
            }
        }
        // Milestone celebration
        .overlay {
            if showMilestone {
                milestoneOverlay
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                manager.stopListening()
                dismiss()
            } label: {
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

            // Score
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundStyle(AppTheme.warm)
                Text("\(score)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Context Line

    private var contextLine: some View {
        HStack(spacing: 8) {
            // Show a few previous words
            ForEach(contextRange, id: \.self) { i in
                let word = words[i]
                Text(word.word)
                    .font(.system(size: 22, design: .rounded))
                    .foregroundStyle(i < currentIndex ? AppTheme.soft.opacity(0.4) : .clear)
            }
        }
        .frame(height: 30)
    }

    private var contextRange: Range<Int> {
        let start = max(0, currentIndex - 3)
        let end = min(words.count, currentIndex + 4)
        return start..<end
    }

    // MARK: - Current Word Display

    private var currentWordDisplay: some View {
        Text(currentWord?.word ?? "")
            .font(.system(size: 72, weight: .bold, design: .rounded))
            .foregroundStyle(wordColor)
            .scaleEffect(wordResult == .correct ? 1.15 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: wordResult)
            .id(currentIndex) // Force new view on word change for transition
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
    }

    private var wordColor: Color {
        switch wordResult {
        case .waiting: return .white
        case .correct: return .green
        case .helped: return AppTheme.warm
        }
    }

    // MARK: - Listening Indicator

    private var listeningIndicator: some View {
        VStack(spacing: 12) {
            if manager.listenState == .listening {
                PulsingMicView()
                if !manager.lastHeardText.isEmpty {
                    let recentWords = manager.lastHeardText
                        .components(separatedBy: " ").suffix(3).joined(separator: " ")
                    Text(recentWords)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(AppTheme.soft.opacity(0.5))
                        .lineLimit(1)
                }
            } else if manager.isSpeakingHelp {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.warm)
                        .symbolEffect(.variableColor.iterative)
                    Text("Listen...")
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(AppTheme.warm)
                }
            } else {
                Image(systemName: "mic.slash")
                    .font(.title2)
                    .foregroundStyle(AppTheme.soft.opacity(0.3))
            }
        }
        .frame(height: 60)
    }

    // MARK: - Help Button

    private var helpButton: some View {
        Button {
            requestHelp()
        } label: {
            Label("Help Me", systemImage: "speaker.wave.2.circle.fill")
                .font(.system(.title3, design: .rounded, weight: .medium))
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(AppTheme.warm)
        .disabled(manager.isSpeakingHelp)
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.soft.opacity(0.2))
                        .frame(height: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.sky, AppTheme.warm],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 8)

            HStack {
                Text("Word \(currentIndex + 1) of \(words.count)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.soft.opacity(0.5))

                Spacer()

                if streak >= 3 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(streak) streak!")
                            .foregroundStyle(.orange)
                    }
                    .font(.system(.caption, design: .rounded, weight: .bold))
                }
            }
        }
    }

    // MARK: - Milestone Overlay

    private var milestoneOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 24) {
                AvatarView(mood: .thumbsUp, size: 100, showGreeting: false)

                Text("\(score) Stars!")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.warm)

                Text(milestoneMessage)
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))

                Button {
                    withAnimation { showMilestone = false }
                    listenForCurrentWord()
                } label: {
                    Text("Keep Reading!")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.warm)
            }
        }
        .transition(.opacity)
    }

    private var milestoneMessage: String {
        switch score {
        case 5: return "Great start!"
        case 10: return "You're a reading star!"
        case 15: return "Amazing reader!"
        case 20: return "Super reader!"
        default: return "Keep it up!"
        }
    }

    // MARK: - Finished State

    private var finishedState: some View {
        ZStack {
            StarBurstView()

            VStack(spacing: 28) {
                AvatarView(mood: .thumbsUp, size: 130, showGreeting: false)

                Text("You Did It!")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(AppTheme.warm)
                    Text("\(score) Stars")
                        .foregroundStyle(AppTheme.warm)
                }
                .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("You read the whole story!")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))

                Button {
                    dismiss()
                } label: {
                    Text("Back to Stories")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.warm)
            }
        }
    }

    // MARK: - Actions

    private func listenForCurrentWord() {
        guard let word = currentWord else { return }
        wordResult = .waiting

        manager.startListening(for: word.word) {
            handleCorrectWord()
        }
    }

    private func handleCorrectWord() {
        wordResult = .correct
        score += 1
        streak += 1

        // Star burst animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
            showStarBurst = true
        }

        // Check for milestone (every 5 correct)
        let isMilestone = score > 0 && score % 5 == 0

        // Advance to next word after a brief celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showStarBurst = false
                currentIndex += 1
            }

            if currentIndex >= words.count {
                isFinished = true
            } else if isMilestone {
                withAnimation { showMilestone = true }
            } else {
                listenForCurrentWord()
            }
        }
    }

    private func requestHelp() {
        streak = 0 // Reset streak on help

        guard let word = currentWord else { return }

        // Try to play the parent's recording of this word
        if let audioURL = book.audioRecordingURL, word.duration > 0 {
            manager.playWordFromRecording(
                audioURL: audioURL,
                startTime: word.startTime,
                duration: word.duration
            )
        } else {
            manager.speakWord(word.word)
        }

        wordResult = .helped

        // Resume listening after help finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if !manager.isSpeakingHelp {
                listenForCurrentWord()
            } else {
                // Wait a bit more for TTS to finish
                waitForHelpToFinish()
            }
        }
    }

    private func waitForHelpToFinish() {
        guard manager.isSpeakingHelp else {
            listenForCurrentWord()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            waitForHelpToFinish()
        }
    }
}

// MARK: - Pulsing Mic View

struct PulsingMicView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.sky.opacity(0.2))
                .frame(width: 56, height: 56)
                .scaleEffect(pulse ? 1.4 : 1.0)
                .opacity(pulse ? 0 : 0.6)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false), value: pulse)

            Circle()
                .fill(AppTheme.sky.opacity(0.15))
                .frame(width: 56, height: 56)

            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.sky)
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Star Burst View

struct StarBurstView: View {
    @State private var animate = false

    private let particles = (0..<8).map { _ in
        (
            angle: Double.random(in: 0...360),
            distance: CGFloat.random(in: 60...140),
            size: CGFloat.random(in: 16...28),
            delay: Double.random(in: 0...0.15)
        )
    }

    var body: some View {
        ZStack {
            ForEach(0..<particles.count, id: \.self) { i in
                let p = particles[i]
                Image(systemName: "star.fill")
                    .font(.system(size: p.size))
                    .foregroundStyle(
                        [AppTheme.warm, .yellow, .orange][i % 3]
                    )
                    .offset(
                        x: animate ? cos(p.angle * .pi / 180) * p.distance : 0,
                        y: animate ? sin(p.angle * .pi / 180) * p.distance : 0
                    )
                    .opacity(animate ? 0 : 1)
                    .scaleEffect(animate ? 0.3 : 1.2)
                    .animation(
                        .easeOut(duration: 0.6).delay(p.delay),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}
