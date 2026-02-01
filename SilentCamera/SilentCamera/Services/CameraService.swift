import AVFoundation
import UIKit
import Photos

/// Camera service that captures photos silently by grabbing frames
/// from AVCaptureVideoDataOutput instead of using AVCapturePhotoOutput.
/// This avoids triggering the system shutter sound.
final class CameraService: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isSessionRunning = false
    @Published var currentPosition: AVCaptureDevice.Position = .back
    @Published var lastCapturedImage: UIImage?
    @Published var flashMode: FlashMode = .off
    @Published var isSaving = false
    @Published var showSavedFeedback = false
    @Published var zoomFactor: CGFloat = 1.0
    @Published var errorMessage: String?

    enum FlashMode {
        case off, on
        var icon: String {
            switch self {
            case .off: return "bolt.slash.fill"
            case .on: return "bolt.fill"
            }
        }
    }

    // MARK: - Capture Session

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoOutputQueue = DispatchQueue(label: "camera.video.output.queue")

    private var videoDeviceInput: AVCaptureDeviceInput?
    private let videoDataOutput = AVCaptureVideoDataOutput()

    /// The latest sample buffer from the video stream.
    private var latestBuffer: CMSampleBuffer?
    private let bufferLock = NSLock()

    /// Flag to grab the next frame as a photo.
    private var captureNextFrame = false

    // MARK: - Setup

    func checkPermissionsAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { self.configureSession() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.sessionQueue.async { self.configureSession() }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "カメラへのアクセスが拒否されました。設定から許可してください。"
                    }
                }
            }
        default:
            DispatchQueue.main.async {
                self.errorMessage = "カメラへのアクセスが拒否されました。設定から許可してください。"
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Add video input
        guard let camera = defaultCamera(for: currentPosition),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
            videoDeviceInput = input
        }

        // Add video data output (used for silent frame capture)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)

        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }

        session.commitConfiguration()
        session.startRunning()

        DispatchQueue.main.async {
            self.isSessionRunning = self.session.isRunning
        }
    }

    // MARK: - Camera Controls

    func switchCamera() {
        sessionQueue.async {
            let newPosition: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back

            guard let newCamera = self.defaultCamera(for: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newCamera) else { return }

            self.session.beginConfiguration()

            if let currentInput = self.videoDeviceInput {
                self.session.removeInput(currentInput)
            }

            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.videoDeviceInput = newInput
            }

            self.session.commitConfiguration()

            DispatchQueue.main.async {
                self.currentPosition = newPosition
                self.zoomFactor = 1.0
            }
        }
    }

    func toggleFlash() {
        flashMode = flashMode == .off ? .on : .off
    }

    func setZoom(_ factor: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
        let clamped = max(1.0, min(factor, maxZoom))
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
            DispatchQueue.main.async { self.zoomFactor = clamped }
        } catch {}
    }

    func focus(at point: CGPoint, in viewSize: CGSize) {
        guard let device = videoDeviceInput?.device,
              device.isFocusPointOfInterestSupported else { return }

        let focusPoint = CGPoint(
            x: point.y / viewSize.height,
            y: 1.0 - point.x / viewSize.width
        )

        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = focusPoint
            device.focusMode = .autoFocus
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {}
    }

    // MARK: - Silent Capture

    /// Captures the current video frame as a photo — completely silent.
    func capturePhoto() {
        // Turn on torch if flash is enabled (for back camera)
        if flashMode == .on, currentPosition == .back {
            setTorch(on: true)
            // Briefly delay to let the torch illuminate the scene
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.captureNextFrame = true
            }
        } else {
            captureNextFrame = true
        }
    }

    /// Saves the last captured image to the photo library.
    func saveToLibrary() {
        guard let image = lastCapturedImage else { return }
        isSaving = true

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.errorMessage = "写真ライブラリへのアクセスが拒否されました。"
                }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    self.isSaving = false
                    if success {
                        self.showSavedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.showSavedFeedback = false
                        }
                    } else {
                        self.errorMessage = "保存に失敗しました: \(error?.localizedDescription ?? "不明なエラー")"
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func defaultCamera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: position) {
            return device
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    private func setTorch(on: Bool) {
        guard let device = videoDeviceInput?.device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {}
    }

    private func imageFromBuffer(_ buffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        // Determine orientation based on current camera position
        let orientation: UIImage.Orientation = currentPosition == .front ? .leftMirrored : .right
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if captureNextFrame {
            captureNextFrame = false

            // Turn off torch after capture
            if flashMode == .on, currentPosition == .back {
                setTorch(on: false)
            }

            if let image = imageFromBuffer(sampleBuffer) {
                DispatchQueue.main.async {
                    self.lastCapturedImage = image
                }
            }
        }
    }
}
