import SwiftUI

struct ContentView: View {
    @State private var showParentMode = false
    @State private var parentPINEntry = ""
    @State private var showPINPrompt = false

    private let parentPIN = "1234"

    var body: some View {
        NavigationStack {
            StoryGridView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showPINPrompt = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
        }
        .alert("Parent Mode", isPresented: $showPINPrompt) {
            SecureField("Enter PIN", text: $parentPINEntry)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {
                parentPINEntry = ""
            }
            Button("Enter") {
                if parentPINEntry == parentPIN {
                    showParentMode = true
                }
                parentPINEntry = ""
            }
        } message: {
            Text("Enter the parent PIN to add or manage books.")
        }
        .fullScreenCover(isPresented: $showParentMode) {
            NavigationStack {
                ParentModeView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") {
                                showParentMode = false
                            }
                        }
                    }
            }
        }
    }
}
