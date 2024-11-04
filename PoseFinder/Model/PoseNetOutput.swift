import CoreML
import Vision

struct PoseNetOutput {
    enum Feature: String {
        case heatmap = "heatmap"
        case offsets = "offsets"
        case backwardDisplacementMap = "displacementBwd"
        case forwardDisplacementMap = "displacementFwd"
    }

    // Structure that defines the coordinates of an index used to query the PoseNet model outputs
    struct Cell {
        let yIndex: Int
        let xIndex: Int

        init(_ yIndex: Int, _ xIndex: Int) {
            self.yIndex = yIndex
            self.xIndex = xIndex
        }

        static var zero: Cell {
            return Cell(0, 0)
        }
    }

    // Multidimensional array that stores the confidence for each joint
    let heatmap: MLMultiArray

    // Multidimensional array that stores an offset for each joint
    let offsets: MLMultiArray

    // Multidimensional array that stores the displacement vector from each joint to its parent
    let backwardDisplacementMap: MLMultiArray

    // Multidimensional array that stores the displacement vector from each parent joint to one of its children
    let forwardDisplacementMap: MLMultiArray

    /// PoseNet model's input size
    let modelInputSize: CGSize

    /// PoseNet model's output stride
    let modelOutputStride: Int

    // To return the **height** of the output array (`heatmap.shape[1]`).
    var height: Int {
        return heatmap.shape[1].intValue
    }

    // To return the **width** of the output array (`heatmap.shape[2]`).
    var width: Int {
        return heatmap.shape[2].intValue
    }

    init(prediction: MLFeatureProvider, modelInputSize: CGSize, modelOutputStride: Int) {
        guard let heatmap = prediction.multiArrayValue(for: .heatmap) else {
            fatalError("Failed to get the heatmap MLMultiArray")
        }
        guard let offsets = prediction.multiArrayValue(for: .offsets) else {
            fatalError("Failed to get the offsets MLMultiArray")
        }
        guard let backwardDisplacementMap = prediction.multiArrayValue(for: .backwardDisplacementMap) else {
            fatalError("Failed to get the backwardDisplacementMap MLMultiArray")
        }
        guard let forwardDisplacementMap = prediction.multiArrayValue(for: .forwardDisplacementMap) else {
            fatalError("Failed to get the forwardDisplacementMap MLMultiArray")
        }

        self.heatmap = heatmap
        self.offsets = offsets
        self.backwardDisplacementMap = backwardDisplacementMap
        self.forwardDisplacementMap = forwardDisplacementMap

        self.modelInputSize = modelInputSize
        self.modelOutputStride = modelOutputStride
    }
}

// MARK: - Utility and accessor methods

extension PoseNetOutput {
    // To Calculates & returns the position for a given joint type at the specified grid cell
    func position(for jointName: Joint.Name, at cell: Cell) -> CGPoint {
        let jointOffset = offset(for: jointName, at: cell)

        // To calculate the joint’s coarse position
        var jointPosition = CGPoint(x: cell.xIndex * modelOutputStride,
                                    y: cell.yIndex * modelOutputStride)

        // To add the offset to get a precise position
        jointPosition += jointOffset

        return jointPosition
    }

    // To return the cell for a given position
    func cell(for position: CGPoint) -> Cell? {
        let yIndex = Int((position.y / CGFloat(modelOutputStride))
            .rounded())
        let xIndex = Int((position.x / CGFloat(modelOutputStride))
            .rounded())

        guard yIndex >= 0 && yIndex < height
            && xIndex >= 0 && xIndex < width else {
                return nil
        }

        return Cell(yIndex, xIndex)
    }

    // To return the associated offset for a joint at the specified cell index
    func offset(for jointName: Joint.Name, at cell: Cell) -> CGVector {
        // To create the index for the y and x component of the offset
        let yOffsetIndex = [jointName.rawValue, cell.yIndex, cell.xIndex]
        let xOffsetIndex = [jointName.rawValue + Joint.numberOfJoints, cell.yIndex, cell.xIndex]

        // To obtain y and x component of the offset from the offsets array
        let offsetY: Double = offsets[yOffsetIndex].doubleValue
        let offsetX: Double = offsets[xOffsetIndex].doubleValue

        return CGVector(dx: CGFloat(offsetX), dy: CGFloat(offsetY))
    }

    // To return the associated confidence for a joint at the specified index
    func confidence(for jointName: Joint.Name, at cell: Cell) -> Double {
        let multiArrayIndex = [jointName.rawValue, cell.yIndex, cell.xIndex]
        return heatmap[multiArrayIndex].doubleValue
    }

    // To return the forward displacement vector for the specified edge and index
    func forwardDisplacement(for edgeIndex: Int, at cell: Cell) -> CGVector {
        // To create the MLMultiArray index
        let yEdgeIndex = [edgeIndex, cell.yIndex, cell.xIndex]
        let xEdgeIndex = [edgeIndex + Pose.edges.count, cell.yIndex, cell.xIndex]

        // To extract the displacements from MultiArray
        let displacementY = forwardDisplacementMap[yEdgeIndex].doubleValue
        let displacementX = forwardDisplacementMap[xEdgeIndex].doubleValue

        return CGVector(dx: displacementX, dy: displacementY)
    }

    // To return the backwards displacement vector for the specified edge and cell
    func backwardDisplacement(for edgeIndex: Int, at cell: Cell) -> CGVector {
        // To create the MLMultiArray index
        let yEdgeIndex = [edgeIndex, cell.yIndex, cell.xIndex]
        let xEdgeIndex = [edgeIndex + Pose.edges.count, cell.yIndex, cell.xIndex]

        // To extract the displacements from MultiArray
        let displacementY = backwardDisplacementMap[yEdgeIndex].doubleValue
        let displacementX = backwardDisplacementMap[xEdgeIndex].doubleValue

        return CGVector(dx: displacementX, dy: displacementY)
    }
}

// MARK: - MLFeatureProvider extension

extension MLFeatureProvider {
    func multiArrayValue(for feature: PoseNetOutput.Feature) -> MLMultiArray? {
        return featureValue(for: feature.rawValue)?.multiArrayValue
    }
}

// MARK: - MLMultiArray extension

extension MLMultiArray {
    subscript(index: [Int]) -> NSNumber {
        return self[index.map { NSNumber(value: $0) } ]
    }
}
