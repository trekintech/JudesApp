import SwiftUI

struct MathChallengeView: View {
    let onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var challenge = MathChallenge.random()
    @State private var shakeWrong = false
    @State private var wrongAnswer: Int?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.ocean)

            Text("Grown-Up Check!")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ocean)

            Text(challenge.question)
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .modifier(ShakeModifier(shaking: shakeWrong))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(challenge.choices, id: \.self) { choice in
                    Button {
                        answerTapped(choice)
                    } label: {
                        Text("\(choice)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(buttonColor(for: choice))
                            )
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(maxWidth: 400)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.gridBackground.ignoresSafeArea())
    }

    private func buttonColor(for choice: Int) -> Color {
        if let wrong = wrongAnswer, wrong == choice {
            return .red.opacity(0.6)
        }
        return AppTheme.ocean
    }

    private func answerTapped(_ choice: Int) {
        if choice == challenge.answer {
            dismiss()
            onSuccess()
        } else {
            wrongAnswer = choice
            shakeWrong = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                shakeWrong = false
                wrongAnswer = nil
                challenge = MathChallenge.random()
            }
        }
    }
}

// MARK: - Math Challenge Model

struct MathChallenge {
    let question: String
    let answer: Int
    let choices: [Int]

    private static let pool: [(String, Int)] = [
        ("3 + 4 = ?", 7),
        ("9 - 5 = ?", 4),
        ("6 + 3 = ?", 9),
        ("8 - 2 = ?", 6),
        ("5 + 5 = ?", 10),
        ("7 - 3 = ?", 4),
        ("2 + 6 = ?", 8),
        ("10 - 7 = ?", 3),
    ]

    static func random() -> MathChallenge {
        let (question, answer) = pool.randomElement()!

        // Generate 3 wrong choices that are close but distinct
        var wrongs = Set<Int>()
        while wrongs.count < 3 {
            let offset = Int.random(in: 1...4) * (Bool.random() ? 1 : -1)
            let wrong = answer + offset
            if wrong != answer && wrong >= 0 {
                wrongs.insert(wrong)
            }
        }

        let choices = (Array(wrongs) + [answer]).shuffled()
        return MathChallenge(question: question, answer: answer, choices: choices)
    }
}

// MARK: - Shake Animation

struct ShakeModifier: ViewModifier {
    var shaking: Bool

    func body(content: Content) -> some View {
        content.offset(x: shaking ? -8 : 0)
            .animation(
                shaking
                    ? .default.repeatCount(3, autoreverses: true).speed(6)
                    : .default,
                value: shaking
            )
    }
}
