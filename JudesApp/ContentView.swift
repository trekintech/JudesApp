import SwiftUI

struct ContentView: View {
    @State private var showAddBook = false
    @State private var showManageLibrary = false
    @State private var showMathChallenge = false

    var body: some View {
        NavigationStack {
            StoryGridView(onAddBook: { showAddBook = true })
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showMathChallenge = true
                        } label: {
                            Image(systemName: "trash.circle")
                                .font(.title2)
                                .foregroundStyle(AppTheme.ocean.opacity(0.5))
                        }
                        .accessibilityLabel("Manage Library")
                    }
                }
        }
        .tint(AppTheme.ocean)
        .sheet(isPresented: $showAddBook) {
            NavigationStack {
                AddBookView()
            }
            .tint(AppTheme.ocean)
        }
        .fullScreenCover(isPresented: $showMathChallenge) {
            MathChallengeView {
                showManageLibrary = true
            }
        }
        .fullScreenCover(isPresented: $showManageLibrary) {
            NavigationStack {
                ManageLibraryView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") {
                                showManageLibrary = false
                            }
                            .fontWeight(.semibold)
                        }
                    }
            }
            .tint(AppTheme.ocean)
        }
    }
}
