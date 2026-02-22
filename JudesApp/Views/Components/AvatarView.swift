import SwiftUI

struct AvatarView: View {
    enum Mood {
        case wave
        case thumbsUp
    }

    let mood: Mood
    var size: CGFloat = 100
    var showGreeting: Bool = true

    @State private var selfieImage: UIImage?
    @State private var emojiRotation: Double = 0
    @State private var emojiScale: Double = 0
    @State private var avatarBounce: Double = 0
    @State private var showEmoji = false

    var body: some View {
        HStack(spacing: 16) {
            // Avatar circle with selfie
            ZStack(alignment: .bottomTrailing) {
                selfieCircle
                    .offset(y: avatarBounce)

                // Animated emoji overlay
                if showEmoji {
                    Text(mood == .wave ? "\u{1F44B}" : "\u{1F44D}")
                        .font(.system(size: size * 0.38))
                        .rotationEffect(.degrees(emojiRotation))
                        .scaleEffect(emojiScale)
                        .offset(x: size * 0.15, y: size * 0.05)
                }
            }

            if showGreeting {
                greetingText
            }
        }
        .onAppear {
            selfieImage = SelfieManager.shared.loadSelfie()
            startAnimations()
        }
    }

    // MARK: - Selfie Circle

    private var selfieCircle: some View {
        Group {
            if let image = selfieImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Fallback: friendly face icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.sky, AppTheme.ocean],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "face.smiling.inverse")
                        .font(.system(size: size * 0.5))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [AppTheme.warm, AppTheme.sky],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
        )
        .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
    }

    // MARK: - Greeting Text

    private var greetingText: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch mood {
            case .wave:
                Text("Hi Jude!")
                    .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ocean)
                Text("Ready to read?")
                    .font(.system(size: size * 0.16, design: .rounded))
                    .foregroundStyle(AppTheme.ocean.opacity(0.6))
            case .thumbsUp:
                Text("Great job!")
                    .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("You finished the story!")
                    .font(.system(size: size * 0.16, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Emoji entrance
        withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.3)) {
            showEmoji = true
            emojiScale = 1.0
        }

        // Emoji wiggle based on mood
        switch mood {
        case .wave:
            startWaveAnimation()
        case .thumbsUp:
            startThumbsUpAnimation()
        }

        // Gentle avatar bounce
        withAnimation(
            .easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.2)
        ) {
            avatarBounce = -6
        }
    }

    private func startWaveAnimation() {
        withAnimation(
            .easeInOut(duration: 0.35).repeatCount(6, autoreverses: true).delay(0.5)
        ) {
            emojiRotation = 25
        }
    }

    private func startThumbsUpAnimation() {
        withAnimation(
            .spring(response: 0.4, dampingFraction: 0.4).repeatCount(3, autoreverses: true).delay(0.5)
        ) {
            emojiScale = 1.3
        }
    }
}
