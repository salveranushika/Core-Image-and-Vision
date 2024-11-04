import CoreML
import Vision

class PoseNetInput: MLFeatureProvider {
    // Name of the PoseNet model's input feature.
    
    private static let imageFeatureName = "image"

    // Original image this feature provider uses as input to its consumers.
    var imageFeature: CGImage

    /// The size of the images this feature provider produces to its consumers.
    let imageFeatureSize: CGSize

    var featureNames: Set<String> {
        return [PoseNetInput.imageFeatureName]
    }

    init(image: CGImage, size: CGSize) {
        imageFeature = image
        imageFeatureSize = size
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        guard featureName == PoseNetInput.imageFeatureName else {
            return nil
        }

        let options: [MLFeatureValue.ImageOption: Any] = [
            .cropAndScale: VNImageCropAndScaleOption.scaleFill.rawValue
        ]

        return try? MLFeatureValue(cgImage: imageFeature,
                                   pixelsWide: Int(imageFeatureSize.width),
                                   pixelsHigh: Int(imageFeatureSize.height),
                                   pixelFormatType: imageFeature.pixelFormatInfo.rawValue,
                                   options: options)
    }
}
