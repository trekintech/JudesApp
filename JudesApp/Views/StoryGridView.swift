import SwiftUI
import SwiftData

struct StoryGridView: View {
    @Query(sort: \StoryBook.creationDate, order: .reverse) private var books: [StoryBook]
    @State private var selectedBook: StoryBook?
    @State private var teachBook: StoryBook?

    var onAddBook: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 28)
    ]

    var body: some View {
        ZStack {
            AppTheme.gridBackground.ignoresSafeArea()

            if books.isEmpty {
                emptyState
            } else {
                bookGrid
            }
        }
        .navigationTitle("Jude's Stories")
        .safeAreaInset(edge: .top) {
            if SelfieManager.shared.hasCompletedSetup {
                AvatarView(mood: .wave, size: 56, showGreeting: true)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .toolbarBackground(AppTheme.pale, for: .navigationBar)
        .fullScreenCover(item: $selectedBook) { book in
            PlaybackView(book: book)
        }
        .fullScreenCover(item: $teachBook) { book in
            TeachModeView(book: book)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 28) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 90))
                .foregroundStyle(AppTheme.soft)

            Text("No Stories Yet")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ocean)

            Text("Tap the button below to add your first book!")
                .font(.title3)
                .foregroundStyle(AppTheme.ocean.opacity(0.6))
                .multilineTextAlignment(.center)

            Button(action: onAddBook) {
                Label("Add a Book", systemImage: "plus.circle.fill")
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.ocean)
            .padding(.top, 8)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Book Grid

    private var bookGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 28) {
                // Add card - always first
                AddBookCard(action: onAddBook)

                ForEach(books) { book in
                    BookCoverButton(book: book) {
                        selectedBook = book
                    }
                    .contextMenu {
                        Button {
                            selectedBook = book
                        } label: {
                            Label("Listen", systemImage: "play.circle")
                        }
                        Button {
                            teachBook = book
                        } label: {
                            Label("Teach Mode", systemImage: "graduationcap")
                        }
                    }
                }
            }
            .padding(28)
        }
    }
}

// MARK: - Add Book Card

struct AddBookCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.ocean.opacity(0.08))
                    .frame(width: 200, height: 270)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                AppTheme.ocean.opacity(0.25),
                                style: StrokeStyle(lineWidth: 2.5, dash: [10, 6])
                            )
                    }
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(AppTheme.ocean.opacity(0.5))
                            Text("Add Book")
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(AppTheme.ocean.opacity(0.6))
                        }
                    }

                Text(" ")
                    .font(.subheadline)
            }
        }
        .buttonStyle(BookButtonStyle())
    }
}

// MARK: - Book Cover Button

struct BookCoverButton: View {
    let book: StoryBook
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                coverImage
                    .frame(width: 200, height: 270)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppTheme.cardShadow, radius: 10, y: 5)

                Text(book.title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.ocean)
                    .frame(height: 40)
            }
        }
        .buttonStyle(BookButtonStyle())
        .accessibilityLabel("Play \(book.title)")
    }

    @ViewBuilder
    private var coverImage: some View {
        if let imageData = book.coverImageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.sky, AppTheme.ocean],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                VStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 50))
                    Text(book.title)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .foregroundStyle(.white.opacity(0.9))
            }
        }
    }
}

// MARK: - Button Style

struct BookButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
