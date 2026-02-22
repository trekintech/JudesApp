import SwiftUI

struct SelfieSetupView: View {
    var onComplete: () -> Void

    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var bounceWave = false

    var body: some View {
        ZStack {
            AppTheme.gridBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Waving hand emoji to set the mood
                Text("\u{1F44B}")
                    .font(.system(size: 80))
                    .rotationEffect(.degrees(bounceWave ? 20 : -10))
                    .animation(
                        .easeInOut(duration: 0.4).repeatForever(autoreverses: true),
                        value: bounceWave
                    )
                    .onAppear { bounceWave = true }

                Text("Say Cheese!")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ocean)

                Text("Take a quick selfie so we can\nmake your reading buddy!")
                    .font(.title3)
                    .foregroundStyle(AppTheme.ocean.opacity(0.6))
                    .multilineTextAlignment(.center)

                if let image = capturedImage {
                    // Preview the captured selfie
                    VStack(spacing: 20) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 180, height: 180)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppTheme.ocean, lineWidth: 4))
                            .shadow(color: AppTheme.cardShadow, radius: 12, y: 6)

                        HStack(spacing: 16) {
                            Button {
                                capturedImage = nil
                                showCamera = true
                            } label: {
                                Label("Retake", systemImage: "camera.rotate")
                                    .font(.system(.body, design: .rounded, weight: .medium))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.bordered)
                            .tint(AppTheme.ocean)

                            Button {
                                SelfieManager.shared.saveSelfie(image)
                                SelfieManager.shared.markSetupComplete()
                                onComplete()
                            } label: {
                                Label("Looks Great!", systemImage: "checkmark.circle.fill")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.ocean)
                        }
                    }
                } else {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take a Selfie", systemImage: "camera.fill")
                            .font(.title2.weight(.semibold))
                            .padding(.horizontal, 36)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.ocean)
                }

                Spacer()

                Button {
                    // Skip selfie setup
                    SelfieManager.shared.markSetupComplete()
                    onComplete()
                } label: {
                    Text("Skip for now")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(AppTheme.ocean.opacity(0.4))
                }
                .padding(.bottom, 40)
            }
            .padding(40)
        }
        .sheet(isPresented: $showCamera) {
            SelfieCameraView { image in
                capturedImage = image
            }
        }
    }
}

// MARK: - Camera Wrapper (Front-facing)

struct SelfieCameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void

        init(onCapture: @escaping (UIImage) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
