import SwiftUI

@main
struct SilentCameraApp: App {
    var body: some Scene {
        WindowGroup {
            CameraView()
                .preferredColorScheme(.dark)
        }
    }
}
