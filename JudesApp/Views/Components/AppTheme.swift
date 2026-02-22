import SwiftUI

enum AppTheme {
    // MARK: - Primary Blues
    static let ocean = Color(red: 0.15, green: 0.40, blue: 0.85)
    static let sky = Color(red: 0.35, green: 0.58, blue: 0.96)
    static let soft = Color(red: 0.55, green: 0.73, blue: 1.0)
    static let pale = Color(red: 0.85, green: 0.91, blue: 1.0)

    // MARK: - Backgrounds
    static let gridBackground = LinearGradient(
        colors: [
            Color(red: 0.93, green: 0.95, blue: 1.0),
            Color(red: 0.85, green: 0.90, blue: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let nightBackground = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.12, blue: 0.28),
            Color(red: 0.04, green: 0.06, blue: 0.18)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Accents
    static let highlight = Color.yellow
    static let warm = Color(red: 1.0, green: 0.78, blue: 0.30)

    // MARK: - Card
    static let cardShadow = Color(red: 0.15, green: 0.25, blue: 0.55).opacity(0.15)
}
