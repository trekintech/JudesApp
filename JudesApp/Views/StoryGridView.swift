import SwiftUI
import SwiftData

struct StoryGridView: View {
    @Query(sort: \StoryBook.creationDate, order: .reverse) private var books: [StoryBook]
    @State private var selectedBook: StoryBook?

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 32)
    ]

    var body: some View {
        Group {
            if books.isEmpty {
                emptyState
            } else {
                bookGrid
            }
        }
        .navigationTitle("Jude's Stories")
        .fullScreenCover(item: $selectedBook) { book in
            PlaybackView(book: book)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tertiary)
            Text("No Stories Yet")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.secondary)
            Text("Ask a grown-up to add your first book!")
                .font(.title2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Book Grid

    private var bookGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 32) {
                ForEach(books) { book in
                    BookCoverButton(book: book) {
                        selectedBook = book
                    }
                }
            }
            .padding(32)
        }
    }
}

// MARK: - Book Cover Button

struct BookCoverButton: View {
    let book: StoryBook
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                coverImage
                    .frame(width: 220, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

                Text(book.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
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
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.8))
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
