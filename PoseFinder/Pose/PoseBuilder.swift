import CoreGraphics

struct PoseBuilder {
    /// Prediction from the PoseNet model
    let output: PoseNetOutput
    /// Transformation matrix used to map joints from the PoseNet model's input image size onto the original image size.
    let modelToInputTransformation: CGAffineTransform
    /// Parameters the Pose Builder uses in its pose algorithms.
    var configuration: PoseBuilderConfiguration

    init(output: PoseNetOutput, configuration: PoseBuilderConfiguration, inputImage: CGImage) {
        self.output = output
        self.configuration = configuration

        // Create a transformation matrix to transform joint positions back into the space of original input size
        modelToInputTransformation = CGAffineTransform(scaleX: inputImage.size.width / output.modelInputSize.width,
                                                       y: inputImage.size.height / output.modelInputSize.height)
    }
}
