import CoreGraphics

extension PoseBuilder {
    /// Returns an array of poses constructed using the outputs from the PoseNet model.
    var poses: [Pose] {
        var detectedPoses = [Pose]()

        // Iterate through the joints with the greatest confidence, referred to here as candidate roots
        for candidateRoot in candidateRoots {
            // Ignore any candidates that are in the proximity of joints of the same type
            let maxDistance = configuration.matchingJointDistance
            guard !detectedPoses.contains(candidateRoot, within: maxDistance) else {
                continue
            }

            var pose = assemblePose(from: candidateRoot)

            // Compute the pose's confidence by dividing the sum of all non-overlapping joints
            pose.confidence = confidence(for: pose, detectedPoses: detectedPoses)

            // Ignore any pose that has a confidence less than the assigned threshold
            guard pose.confidence >= configuration.poseConfidenceThreshold else {
                continue
            }

            detectedPoses.append(pose)

            // Exit early if enough poses have been detected.
            if detectedPoses.count >= configuration.maxPoseCount {
                break
            }
        }

        // Map the pose joints positions back onto the original image using pre-computed matrix
        detectedPoses.forEach { pose in
            pose.joints.values.forEach { joint in
                joint.position = joint.position.applying(modelToInputTransformation)
            }
        }

        return detectedPoses
    }

    // Returns candidate joints that are used as roots to assemble poses
    private var candidateRoots: [Joint] {
        var candidateRoots = [Joint]()

        for jointName in Joint.Name.allCases {
            for yIndex in 0..<output.height {
                for xIndex in 0..<output.width {
                    let cell = PoseNetOutput.Cell(yIndex, xIndex)

                    let jointConfidence = output.confidence(for: jointName, at: cell)

                    guard jointConfidence >= configuration.jointConfidenceThreshold
                        else { continue }

                    // Only consider a joint whose score is the greatest among its neighbors.
                    let greatestNeighborsConfidence = greatestConfidence(for: jointName, at: cell)
                    guard jointConfidence >= greatestNeighborsConfidence
                        else { continue }

                    let candidate = Joint(name: jointName,
                                          cell: cell,
                                          position: output.position(for: jointName, at: cell),
                                          confidence: jointConfidence,
                                          isValid: true)

                    candidateRoots.append(candidate)
                }
            }
        }

        // Sort & return candidates in order of their confidence.
        return candidateRoots.sorted { $0.confidence > $1.confidence }
    }

    // Calculates & returns the given pose's confidence.
    private func confidence(for pose: Pose, detectedPoses: [Pose]) -> Double {
        // Find all non-overlapping joints belonging to the existing pose.
        let joints = nonOverlappingJoints(for: pose, detectedPoses: detectedPoses)

        return joints.map { $0.confidence }.reduce(0, +) / Double(Joint.numberOfJoints)
    }

    // Returns all non-overlapping joints for a given pose.
    private func nonOverlappingJoints(for pose: Pose, detectedPoses: [Pose]) -> [Joint] {
        return pose.joints.values.filter { joint in
            guard joint.isValid else {
                return false
            }

            for detectedPose in detectedPoses {
                let otherJoint = detectedPose[joint.name]

                guard otherJoint.isValid else {
                    continue
                }

                if joint.position.distance(to: otherJoint.position) <= configuration.matchingJointDistance {
                    return false
                }
            }
            return true
        }
    }

    // Returns the confidence of the joint with the greatest confidence around the given cell
    private func greatestConfidence(for jointName: Joint.Name, at cell: PoseNetOutput.Cell) -> Double {
        // Calculate the start & end indices for the local window
        let yLowerBound = max(cell.yIndex - configuration.localSearchRadius, 0)
        let yUpperBound = min(cell.yIndex + configuration.localSearchRadius, output.height - 1)
        let yWindowIndices: ClosedRange<Int> = yLowerBound...yUpperBound

        let xLowerBound = max(cell.xIndex - configuration.localSearchRadius, 0)
        let xUpperBound = min(cell.xIndex + configuration.localSearchRadius, output.width - 1)
        let xWindowIndices: ClosedRange<Int> = xLowerBound...xUpperBound

        var greatestConfidence = 0.0

        // Scan over the local window in search of the cell with the greatest confidence
        for yIndex in yWindowIndices {
            for xIndex in xWindowIndices {
                guard yIndex != cell.yIndex, xIndex != cell.xIndex else {
                    continue
                }
                let localCell = PoseNetOutput.Cell(yIndex, xIndex)
                let localConfidence = output.confidence(for: jointName, at: localCell)

                greatestConfidence = max(greatestConfidence, localConfidence)
            }
        }

        return greatestConfidence
    }

    // Assembles a pose using the given candidate root joint
    private func assemblePose(from rootJoint: Joint) -> Pose {
        // Create a pose & update its root joint.
        var pose = Pose()
        pose[rootJoint.name] = rootJoint

        // Update the remaining joints by spawning from the root joint to find adjacent nodes
        var queryJoints = [rootJoint]
        while !queryJoints.isEmpty {
            let joint = queryJoints.removeFirst()

            // Update the details of all the adjacent joints
            for edge in Pose.edges(for: joint.name) {
                let parentJoint = pose[edge.parent]
                let childJoint = pose[edge.child]

                // Ignore any edges that have already been processed.
                guard !(parentJoint.isValid && childJoint.isValid) else {
                    continue
                }

                // Set the source joint to search from
                let sourceJoint = parentJoint.isValid ? parentJoint : childJoint
                // Set the adjacent joint to search to.
                let adjacentJoint = parentJoint.isValid ? childJoint : parentJoint
                // Update the properties of the adjacent joint
                configure(joint: adjacentJoint,
                          from: sourceJoint,
                          given: Pose.edge(from: parentJoint.name, to: childJoint.name)!)
                // Add the adjacent joint to the queue if its confidence is greater
                if adjacentJoint.isValid {
                    queryJoints.append(adjacentJoint)
                }
            }
        }

        return pose
    }

    // Update the properties of the given joint using the `sourceJoint` and associated `edge`
    private func configure(joint: Joint,
                           from sourceJoint: Joint,
                           given edge: Pose.Edge) {

        // Query the appropriate displacement map to obtain the displacement vector.
        var displacementVector = CGVector.zero
        if edge.parent == sourceJoint.name {
            // Parent -> Child.
            displacementVector = output.forwardDisplacement(for: edge.index, at: sourceJoint.cell)
        } else {
            // Child -> Parent.
            displacementVector = output.backwardDisplacement(for: edge.index, at: sourceJoint.cell)
        }

        // To apply the displacement vector to the source joint's position to find an position
        var approximateJointPosition = sourceJoint.position + displacementVector

        // To refine the joint's position by adjusting the position using the associated offset
        for _ in 0..<configuration.adjacentJointOffsetRefinementSteps {
            guard let jointCell = output.cell(for: approximateJointPosition) else {
                break
            }

            let offset = output.offset(for: joint.name, at: jointCell)
            approximateJointPosition.x = CGFloat(jointCell.xIndex) * CGFloat(output.modelOutputStride) + offset.dx
            approximateJointPosition.y = CGFloat(jointCell.yIndex) * CGFloat(output.modelOutputStride) + offset.dy
        }

        // To obtain & assign the joint's cell by mapping the derived position
        guard let jointCell = output.cell(for: approximateJointPosition) else {
            return
        }

        // To update joint
        joint.cell = jointCell
        joint.position = approximateJointPosition
        joint.confidence = output.confidence(for: joint.name, at: joint.cell)
        joint.isValid = joint.confidence >= configuration.jointConfidenceThreshold
    }
}

// MARK: - Array Extension

private extension Array where Element == Pose {
    // To Return a Boolean value that indicates whether the given candidate joint matches an existing joint of pose
    func contains(_ candidate: Joint, within distance: Double) -> Bool {
        // To check each pose in the array
        for pose in self {
            // To find the joint that matches the candidate
            let matchingJoint = pose[candidate.name]

            // To skip the pose's joint if it is not valid
            guard matchingJoint.isValid else { continue }

            if matchingJoint.position.distance(to: candidate.position) <= distance {
                // Candidate is in proximity to an existing joint
                return true
            }
        }
        return false
    }
}
