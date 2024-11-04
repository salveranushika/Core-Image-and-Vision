import CoreML
import Vision

protocol PoseNetDelegate: AnyObject {
    func poseNet(_ poseNet: PoseNet, didPredict predictions: PoseNetOutput)
}

class PoseNet {
    // To the delegate to receive the PoseNet model's outputs
    weak var delegate: PoseNetDelegate?

    // PoseNet model's input size
    let modelInputSize = CGSize(width: 513, height: 513)

    // PoseNet model's output stride.
    let outputStride = 16

    // Core ML model that the PoseNet model uses to generate estimates for the poses
    private let poseNetMLModel: MLModel

    init() throws {
        poseNetMLModel = try PoseNetMobileNet075S16FP16(configuration: .init()).model
    }

    // To calls the `prediction` method of the PoseNet model and returns the outputs to the assigned delegate
    func predict(_ image: CGImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Wrap the image in an instance of PoseNetInput to have it resized before
            let input = PoseNetInput(image: image, size: self.modelInputSize)

            guard let prediction = try? self.poseNetMLModel.prediction(from: input) else {
                return
            }

            let poseNetOutput = PoseNetOutput(prediction: prediction,
                                              modelInputSize: self.modelInputSize,
                                              modelOutputStride: self.outputStride)

            DispatchQueue.main.async {
                self.delegate?.poseNet(self, didPredict: poseNetOutput)
            }
        }
    }
}
