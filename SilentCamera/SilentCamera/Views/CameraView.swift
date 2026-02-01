import SwiftUI

struct CameraView: View {
    @StateObject private var camera = CameraService()
    @State private var showPreview = false
    @State private var focusLocation: CGPoint?
    @State private var showFocusRing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Camera preview
            CameraPreview(session: camera.session)
                .ignoresSafeArea()
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            camera.setZoom(camera.zoomFactor * value)
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onEnded { value in
                            // Ignore drags, only taps
                        }
                )
                .onTapGesture { location in
                    focusLocation = location
                    showFocusRing = true
                    camera.focus(at: location, in: UIScreen.main.bounds.size)

                    withAnimation(.easeOut(duration: 0.8)) {
                        showFocusRing = false
                    }
                }

            // Focus ring indicator
            if showFocusRing, let loc = focusLocation {
                FocusRing()
                    .position(loc)
                    .transition(.opacity)
            }

            // Saved feedback
            if camera.showSavedFeedback {
                SavedBanner()
                    .transition(.opacity)
            }

            // Controls overlay
            VStack(spacing: 0) {
                // Top bar
                TopBar(camera: camera)

                Spacer()

                // Bottom controls
                BottomControls(camera: camera, showPreview: $showPreview)
            }

            // Error overlay
            if let error = camera.errorMessage {
                ErrorBanner(message: error) {
                    camera.errorMessage = nil
                }
            }
        }
        .onAppear {
            camera.checkPermissionsAndSetup()
        }
        .sheet(isPresented: $showPreview) {
            if let image = camera.lastCapturedImage {
                PhotoPreviewView(image: image, camera: camera)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: camera.showSavedFeedback)
    }
}

// MARK: - Top Bar

private struct TopBar: View {
    @ObservedObject var camera: CameraService

    var body: some View {
        HStack {
            Button {
                camera.toggleFlash()
            } label: {
                Image(systemName: camera.flashMode.icon)
                    .font(.system(size: 20))
                    .foregroundColor(camera.flashMode == .on ? .yellow : .white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Silent indicator
            HStack(spacing: 4) {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: 12))
                Text("サイレント")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.15)))

            Spacer()

            // Zoom indicator
            if camera.zoomFactor > 1.05 {
                Text(String(format: "%.1fx", camera.zoomFactor))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

// MARK: - Bottom Controls

private struct BottomControls: View {
    @ObservedObject var camera: CameraService
    @Binding var showPreview: Bool

    var body: some View {
        HStack(alignment: .center) {
            // Thumbnail / last photo
            Button {
                if camera.lastCapturedImage != nil {
                    showPreview = true
                }
            } label: {
                if let img = camera.lastCapturedImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 52, height: 52)
                }
            }
            .frame(maxWidth: .infinity)

            // Shutter button
            Button {
                camera.capturePhoto()
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 62, height: 62)
                }
            }
            .frame(maxWidth: .infinity)

            // Switch camera
            Button {
                camera.switchCamera()
            } label: {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.white.opacity(0.15)))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
}

// MARK: - Photo Preview

struct PhotoPreviewView: View {
    let image: UIImage
    @ObservedObject var camera: CameraService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                VStack {
                    Spacer()
                    HStack(spacing: 40) {
                        Button {
                            UIPasteboard.general.image = image
                        } label: {
                            Label("コピー", systemImage: "doc.on.doc")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.white.opacity(0.2)))
                        }

                        Button {
                            camera.saveToLibrary()
                        } label: {
                            Label(camera.isSaving ? "保存中…" : "保存",
                                  systemImage: "square.and.arrow.down")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.white.opacity(0.2)))
                        }
                        .disabled(camera.isSaving)

                        ShareLink(item: Image(uiImage: image),
                                  preview: SharePreview("写真", image: Image(uiImage: image))) {
                            Label("共有", systemImage: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.white.opacity(0.2)))
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Focus Ring

private struct FocusRing: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .stroke(Color.yellow, lineWidth: 1.5)
            .frame(width: 70, height: 70)
    }
}

// MARK: - Saved Banner

private struct SavedBanner: View {
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("保存しました")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.green.opacity(0.8)))
            .padding(.bottom, 120)
        }
    }
}

// MARK: - Error Banner

private struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.85)))
            .padding()

            Spacer()
        }
    }
}
