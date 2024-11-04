import CoreGraphics

enum Algorithm: Int {
    case single
    case multiple
}

struct PoseBuilderConfiguration {
    /// Min value for valid joints in pose
    var jointConfidenceThreshold = 0.1

    /// Min value for valid pose
    var poseConfidenceThreshold = 0.5

    /// Min distance between 2 distinct joints of same type
    var matchingJointDistance = 40.0

    /// Search radius used when checking if a joint has the greatest confidence amongst its neighbors
    var localSearchRadius = 3

    /// Max number of poses returned
    var maxPoseCount = 15

    /// Number of iterations performed to refine an adjacent joint's position
    var adjacentJointOffsetRefinementSteps = 3
}
