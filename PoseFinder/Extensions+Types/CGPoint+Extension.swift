import CoreGraphics

extension CGPoint {
    init(_ cell: PoseNetOutput.Cell) {
        self.init(x: CGFloat(cell.xIndex), y: CGFloat(cell.yIndex))
    }

    // To Calculate & returns the squared distance between this point and another
    func squaredDistance(to other: CGPoint) -> CGFloat {
        let diffX = other.x - x
        let diffY = other.y - y

        return diffX * diffX + diffY * diffY
    }

    // To calculate & returns the distance between this point and another
    func distance(to other: CGPoint) -> Double {
        return Double(squaredDistance(to: other).squareRoot())
    }

    // To calculate & returns the result of an element-wise addition
    static func + (_ lhs: CGPoint, _ rhs: CGVector) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }

    // To perform element-wise addition
    static func += (lhs: inout CGPoint, _ rhs: CGVector) {
        lhs.x += rhs.dx
        lhs.y += rhs.dy
    }

    // To calculate & returns the result of an element-wise multiplication
    static func * (_ lhs: CGPoint, _ scale: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * scale, y: lhs.y * scale)
    }

    // To calculate & returns the result of an element-wise multiplication.
    static func * (_ lhs: CGPoint, _ rhs: CGSize) -> CGPoint {
        return CGPoint(x: lhs.x * rhs.width, y: lhs.y * rhs.height)
    }
}
