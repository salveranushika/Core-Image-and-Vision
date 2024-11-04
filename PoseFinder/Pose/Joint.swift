import CoreGraphics

class Joint {
    enum Name: Int, CaseIterable {
        case nose
        case leftEye
        case rightEye
        case leftEar
        case rightEar
        case leftShoulder
        case rightShoulder
        case leftElbow
        case rightElbow
        case leftWrist
        case rightWrist
        case leftHip
        case rightHip
        case leftKnee
        case rightKnee
        case leftAnkle
        case rightAnkle
    }

    // Total no. of joints available
    static var numberOfJoints: Int {
        return Name.allCases.count
    }

    // Name used to identify the joint
    let name: Name

    // Position of the joint relative to the image
    var position: CGPoint

    // Joint's respective cell index into model's output grid
    var cell: PoseNetOutput.Cell

    // Confidence score associated with this joint
    var confidence: Double

    // Boolean value that indicates if the joint satisfies the joint threshold defined in the configuration
    var isValid: Bool

    init(name: Name,
         cell: PoseNetOutput.Cell = .zero,
         position: CGPoint = .zero,
         confidence: Double = 0,
         isValid: Bool = false) {
        self.name = name
        self.cell = cell
        self.position = position
        self.confidence = confidence
        self.isValid = isValid
    }
}
