import SwiftUI
import SwiftData

struct ParentModeView: View {
    @Query(sort: \StoryBook.creationDate, order: .reverse) private var books: [StoryBook]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddBook = false
    @State private var bookToDelete: StoryBook?

    var body: some View {
        List {
            Section {
                Button {
                    showAddBook = true
                } label: {
                    Label("Add New Book", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
            }

            Section("Library (\(books.count) books)") {
                ForEach(books) { book in
                    HStack(spacing: 16) {
                        bookThumbnail(book)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.headline)
                            Text("\(book.timedWords.count) words transcribed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(book.creationDate, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if book.audioRecordingURL != nil {
                            Image(systemName: "waveform.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            bookToDelete = book
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Parent Mode")
        .sheet(isPresented: $showAddBook) {
            NavigationStack {
                AddBookView()
            }
        }
        .alert("Delete Book?", isPresented: .init(
            get: { bookToDelete != nil },
            set: { if !$0 { bookToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { bookToDelete = nil }
            Button("Delete", role: .destructive) {
                if let book = bookToDelete {
                    if let fileName = book.audioFileName {
                        AudioManager().deleteRecording(fileName: fileName)
                    }
                    modelContext.delete(book)
                    bookToDelete = nil
                }
            }
        } message: {
            if let book = bookToDelete {
                Text("This will permanently delete \"\(book.title)\" and its recording.")
            }
        }
    }

    @ViewBuilder
    private func bookThumbnail(_ book: StoryBook) -> some View {
        if let data = book.coverImageData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 65)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 50, height: 65)
                .overlay {
                    Image(systemName: "book.closed")
                        .foregroundStyle(.secondary)
                }
        }
    }
}
