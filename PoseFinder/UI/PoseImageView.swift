import UIKit

@IBDesignable
class PoseImageView: UIImageView {

    // Data structure used to describe a visual connection between two joints
    struct JointSegment {
        let jointA: Joint.Name
        let jointB: Joint.Name
    }

    // Array of joint-pairs that define the lines of a pose's wireframe drawing
    static let jointSegments = [
        // Connected joints that are on the left side of the body
        JointSegment(jointA: .leftHip, jointB: .leftShoulder),
        JointSegment(jointA: .leftShoulder, jointB: .leftElbow),
        JointSegment(jointA: .leftElbow, jointB: .leftWrist),
        JointSegment(jointA: .leftHip, jointB: .leftKnee),
        JointSegment(jointA: .leftKnee, jointB: .leftAnkle),
        // Connected joints that are on the right side of the body
        JointSegment(jointA: .rightHip, jointB: .rightShoulder),
        JointSegment(jointA: .rightShoulder, jointB: .rightElbow),
        JointSegment(jointA: .rightElbow, jointB: .rightWrist),
        JointSegment(jointA: .rightHip, jointB: .rightKnee),
        JointSegment(jointA: .rightKnee, jointB: .rightAnkle),
        // Connected joints that cross over the body
        JointSegment(jointA: .leftShoulder, jointB: .rightShoulder),
        JointSegment(jointA: .leftHip, jointB: .rightHip)
    ]

    // Width of the line connecting two joints
    @IBInspectable var segmentLineWidth: CGFloat = 2
    // Color of the line connecting two joints
    @IBInspectable var segmentColor: UIColor = UIColor.systemTeal
    // Radius of the circles drawn for each joint
    @IBInspectable var jointRadius: CGFloat = 4
    // Color of the circles drawn for each joint.
    @IBInspectable var jointColor: UIColor = UIColor.systemPink

    // MARK: - Rendering methods

    // Returns an image showing the detected poses
    func show(poses: [Pose], on frame: CGImage) {
        let dstImageSize = CGSize(width: frame.width, height: frame.height)
        let dstImageFormat = UIGraphicsImageRendererFormat()

        dstImageFormat.scale = 1
        let renderer = UIGraphicsImageRenderer(size: dstImageSize,
                                               format: dstImageFormat)

        let dstImage = renderer.image { rendererContext in
            // To draw the current frame as the background for the new image
            draw(image: frame, in: rendererContext.cgContext)

            for pose in poses {
                // To draw the segment lines
                for segment in PoseImageView.jointSegments {
                    let jointA = pose[segment.jointA]
                    let jointB = pose[segment.jointB]

                    guard jointA.isValid, jointB.isValid else {
                        continue
                    }

                    drawLine(from: jointA,
                             to: jointB,
                             in: rendererContext.cgContext)
                }

                // To draw the joints as circles above the segment lines
                for joint in pose.joints.values.filter({ $0.isValid }) {
                    draw(circle: joint, in: rendererContext.cgContext)
                }
            }
        }

        image = dstImage
    }

    // To vertically flips and draws the given image.
    func draw(image: CGImage, in cgContext: CGContext) {
        cgContext.saveGState()
        cgContext.scaleBy(x: 1.0, y: -1.0)
        let drawingRect = CGRect(x: 0, y: -image.height, width: image.width, height: image.height)
        cgContext.draw(image, in: drawingRect)
        cgContext.restoreGState()
    }

    /// Draws a line between two joints.
    func drawLine(from parentJoint: Joint,
                  to childJoint: Joint,
                  in cgContext: CGContext) {
        cgContext.setStrokeColor(segmentColor.cgColor)
        cgContext.setLineWidth(segmentLineWidth)

        cgContext.move(to: parentJoint.position)
        cgContext.addLine(to: childJoint.position)
        cgContext.strokePath()
    }

    /// Draw a circle in the location of the given joint.
    private func draw(circle joint: Joint, in cgContext: CGContext) {
        cgContext.setFillColor(jointColor.cgColor)

        let rectangle = CGRect(x: joint.position.x - jointRadius, y: joint.position.y - jointRadius,
                               width: jointRadius * 2, height: jointRadius * 2)
        cgContext.addEllipse(in: rectangle)
        cgContext.drawPath(using: .fill)
    }
}
