import AVFoundation
import CoreVideo
import UIKit
import VideoToolbox

protocol VideoCaptureDelegate: AnyObject {
    func videoCapture(_ videoCapture: VideoCapture, didCaptureFrame image: CGImage?)
}

class VideoCapture: NSObject {
    enum VideoCaptureError: Error {
        case captureSessionIsMissing
        case invalidInput
        case invalidOutput
        case unknown
    }

    // Delegate to receive the captured frames
    weak var delegate: VideoCaptureDelegate?

    // Capture session used to coordinate the flow of data from input devices to capture outputs
    let captureSession = AVCaptureSession()

    // Capture output that records video and provides access to video frames
    let videoOutput = AVCaptureVideoDataOutput()

    // Current camera's position
    private(set) var cameraPostion = AVCaptureDevice.Position.back

    // Dispatch queue responsible for processing camera set up and frame capture
    private let sessionQueue = DispatchQueue(
        label: "com.example.apple-samplecode.estimating-human-pose-with-posenet.sessionqueue")

    // Toggles between the front and back camera.
    public func flipCamera(completion: @escaping (Error?) -> Void) {
        sessionQueue.async {
            do {
                self.cameraPostion = self.cameraPostion == .back ? .front : .back

                // To indicate the start of a set of configuration changes to the capture session
                self.captureSession.beginConfiguration()

                try self.setCaptureSessionInput()
                try self.setCaptureSessionOutput()

                // To commit configuration changes
                self.captureSession.commitConfiguration()

                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }

    // Sets up the capture session
    public func setUpAVCapture(completion: @escaping (Error?) -> Void) {
        sessionQueue.async {
            do {
                try self.setUpAVCapture()
                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }

    private func setUpAVCapture() throws {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }

        captureSession.beginConfiguration()

        captureSession.sessionPreset = .vga640x480

        try setCaptureSessionInput()

        try setCaptureSessionOutput()

        captureSession.commitConfiguration()
    }

    private func setCaptureSessionInput() throws {
        // Use the default capture device to obtain access to the physical device
        guard let captureDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: AVMediaType.video,
            position: cameraPostion) else {
                throw VideoCaptureError.invalidInput
        }

        // To remove any existing inputs
        captureSession.inputs.forEach { input in
            captureSession.removeInput(input)
        }

        // Create an instance of AVCaptureDeviceInput to capture the data from capture device
        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            throw VideoCaptureError.invalidInput
        }

        guard captureSession.canAddInput(videoInput) else {
            throw VideoCaptureError.invalidInput
        }

        captureSession.addInput(videoInput)
    }

    private func setCaptureSessionOutput() throws {
        // Tp remove any previous outputs
        captureSession.outputs.forEach { output in
            captureSession.removeOutput(output)
        }

        // To set the pixel type
        let settings: [String: Any] = [
            String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]

        videoOutput.videoSettings = settings

        // To discard newer frames that arrive while the dispatch queue is already busy with an older frame
        videoOutput.alwaysDiscardsLateVideoFrames = true

        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            throw VideoCaptureError.invalidOutput
        }

        captureSession.addOutput(videoOutput)

        // To update the video orientation
        if let connection = videoOutput.connection(with: .video),
            connection.isVideoOrientationSupported {
            connection.videoOrientation =
                AVCaptureVideoOrientation(deviceOrientation: UIDevice.current.orientation)
            connection.isVideoMirrored = cameraPostion == .front

            // Inverse the landscape orientation to force the image in the upward orientation.
            if connection.videoOrientation == .landscapeLeft {
                connection.videoOrientation = .landscapeRight
            } else if connection.videoOrientation == .landscapeRight {
                connection.videoOrientation = .landscapeLeft
            }
        }
    }

    // To begin capturing frames
    public func startCapturing(completion completionHandler: (() -> Void)? = nil) {
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }

            if let completionHandler = completionHandler {
                DispatchQueue.main.async {
                    completionHandler()
                }
            }
        }
    }

    // To end capturing frames
    public func stopCapturing(completion completionHandler: (() -> Void)? = nil) {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }

            if let completionHandler = completionHandler {
                DispatchQueue.main.async {
                    completionHandler()
                }
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {

    public func captureOutput(_ output: AVCaptureOutput,
                              didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        guard let delegate = delegate else { return }

        if let pixelBuffer = sampleBuffer.imageBuffer {
            // Attempt to lock the image buffer to gain access to its memory.
            guard CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) == kCVReturnSuccess
                else {
                    return
            }

            // To create Core Graphics image placeholder.
            var image: CGImage?

            // To create a Core Graphics bitmap image from the pixel buffer
            VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &image)

            // To release the image buffer.
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

            DispatchQueue.main.sync {
                delegate.videoCapture(self, didCaptureFrame: image)
            }
        }
    }
}
