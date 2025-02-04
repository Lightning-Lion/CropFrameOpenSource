/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A structure with the entity view protocol to generate and update meshes for each hand anchor.
*/

import SwiftUI
import RealityKit
import ARKit
import os
import MixedRealityKit

@MainActor
@Observable
class HandPositionDataPack  {
    var data:HandPositionData = HandPositionData()
}

struct HandPositionData:Equatable {
    let id = UUID()
    let timestamp = Date.now
    var leftHandThumbnailPosition:SIMD3<Float>?
    var leftHandIndexFingerPosition:SIMD3<Float>?
    var rightHandThumbnailPosition:SIMD3<Float>?
    var rightHandIndexFingerPosition:SIMD3<Float>?
}

/// 跟踪用户的左右手大拇指和食指指尖的位置
struct HandTrackingView: ViewModifier {
    @State
    var handPosition:HandPositionDataPack
    @Binding
    var pack:RealityViewContentPack?
    
    /// The ARKit session for hand tracking.
    private let arSession = ARKitSession()

    /// The provider instance for hand tracking.
    private let handTracking = HandTrackingProvider()

    /// The most recent anchor that the provider detects on the left hand.
    @State var latestLeftHand: HandAnchor?

    /// The most recent anchor that the provider detects on the right hand.
    @State var latestRightHand: HandAnchor?

    /// The main body of the view.
    func body(content: Content) -> some View {
        content
            .onReady($pack, perform: { content in
                content.add(makeHandEntities())
            })
    }

    /// Create and return an entity that contains all hand-tracking entities.
    @MainActor
    func makeHandEntities() -> Entity {
        /// The entity to contain all hand-tracking meshes.
        let root = Entity()

        // Start the ARKit session.
        runSession()

        /// The left hand.
        let leftHand = Hand()

        /// The right hand.
        let rightHand = Hand()

        // Add the left hand to the root entity.
        root.addChild(leftHand.handRoot)

        // Add the right hand to the root entity.
        root.addChild(rightHand.handRoot)
        
        // Set the `ClosureComponent` to enable the hand entities to update over time.
        root.components.set(ClosureComponent(closure: { deltaTime in
            var handData = HandPositionData()
            // Iterate through all of the anchors on the left hand.
            if let leftAnchor = self.latestLeftHand, let leftHandSkeleton = leftAnchor.handSkeleton {
              
                for (jointName) in HandSkeleton.JointName.allCases {
                    /// The current transform of the person's left hand joint.
                    let anchorFromJointTransform = leftHandSkeleton.joint(jointName).anchorFromJointTransform

                    // Update the joint entity to match the transform of the person's left hand joint.
                    let meGlobalTransform = leftAnchor.originFromAnchorTransform * anchorFromJointTransform
                    if jointName == .thumbTip {
                        handData.leftHandThumbnailPosition = Transform(matrix: meGlobalTransform).translation
                    } else if jointName == .indexFingerTip {
                        handData.leftHandIndexFingerPosition = Transform(matrix: meGlobalTransform).translation
                    }
                }
            }

            // Iterate through all of the anchors on the right hand.
            if let rightAnchor = self.latestRightHand, let rightHandSkeleton = rightAnchor.handSkeleton {
                for (jointName) in HandSkeleton.JointName.allCases {
                    /// The current transform of the person's right hand joint.
                    let anchorFromJointTransform = rightHandSkeleton.joint(jointName).anchorFromJointTransform

                    
                    // Update the joint entity to match the transform of the person's left hand joint.
                    let meGlobalTransform = rightAnchor.originFromAnchorTransform * anchorFromJointTransform
                    
                    if jointName == .thumbTip {
                        handData.rightHandThumbnailPosition = Transform(matrix: meGlobalTransform).translation
                    } else if jointName == .indexFingerTip {
                        handData.rightHandIndexFingerPosition = Transform(matrix: meGlobalTransform).translation
                    }
                }
            }
            
            self.handPosition.data = handData
        }))

        return root
    }

    /// Check whether an ARKit session can run and start the hand-tracking provider.
    func runSession() {
        Task {
            do {
                // Attempt to run the ARKit session with the hand-tracking provider.
                try await arSession.run([handTracking])
            } catch let error as ARKitSession.Error {
                print("The App has encountered an error while running providers: \(error.localizedDescription)")
            } catch let error {
                print("The App has encountered an unexpected error: \(error.localizedDescription)")
            }

            // Start to collect each hand-tracking anchor.
            for await anchorUpdate in handTracking.anchorUpdates {
                // Check if the anchor is on the left or right hand.
                switch anchorUpdate.anchor.chirality {
                case .left:
                    self.latestLeftHand = anchorUpdate.anchor
                case .right:
                    self.latestRightHand = anchorUpdate.anchor
                }
            }
        }
    }
}


/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A structure containing all entities attached to hand-tracking anchors.
*/
/// A structure that contains white spheres on each joint of a hand.
fileprivate
struct Hand {
    /// The hand root to contain all hand-tracking anchor entities.
    var handRoot = Entity()

    /// The entity that associates with the joint name.
    var fingers: [HandSkeleton.JointName: Entity] = [:]

    /// The collection of joints in a hand.
    static let joints: [(HandSkeleton.JointName, Finger, Bone)] = [
        // Define the thumb bones.
        (.thumbKnuckle, .thumb, .knuckle),
        (.thumbIntermediateBase, .thumb, .intermediateBase),
        (.thumbIntermediateTip, .thumb, .intermediateTip),
        (.thumbTip, .thumb, .tip),

        // Define the index-finger bones.
        (.indexFingerMetacarpal, .index, .metacarpal),
        (.indexFingerKnuckle, .index, .knuckle),
        (.indexFingerIntermediateBase, .index, .intermediateBase),
        (.indexFingerIntermediateTip, .index, .intermediateTip),
        (.indexFingerTip, .index, .tip),

        // Define the middle-finger bones.
        (.middleFingerMetacarpal, .middle, .metacarpal),
        (.middleFingerKnuckle, .middle, .knuckle),
        (.middleFingerIntermediateBase, .middle, .intermediateBase),
        (.middleFingerIntermediateTip, .middle, .intermediateTip),
        (.middleFingerTip, .middle, .tip),

        // Define the ring-finger bones.
        (.ringFingerMetacarpal, .ring, .metacarpal),
        (.ringFingerKnuckle, .ring, .knuckle),
        (.ringFingerIntermediateBase, .ring, .intermediateBase),
        (.ringFingerIntermediateTip, .ring, .intermediateBase),
        (.ringFingerTip, .ring, .tip),

        // Define the little-finger bones.
        (.littleFingerMetacarpal, .little, .metacarpal),
        (.littleFingerKnuckle, .little, .knuckle),
        (.littleFingerIntermediateBase, .little, .intermediateBase),
        (.littleFingerIntermediateTip, .little, .intermediateTip),
        (.littleFingerTip, .little, .tip),

        // Define wrist and arm bones.
        (.forearmWrist, .forearm, .wrist),
        (.forearmArm, .forearm, .arm)
    ]

    init() {
        /// The size of the sphere mesh.
        let radius: Float = 0.01

        /// The material to apply to the sphere entity.
        let material = SimpleMaterial(color: .white, isMetallic: false)

        // For each joint, create a sphere and attach it to the finger.
        for bone in Self.joints {
            /// The model entity representation of a hand anchor.
            let sphere = ModelEntity(
                mesh: .generateSphere(radius: radius),
                materials: [material]
            )

            // Add the sphere to the `handRoot` entity.
            handRoot.addChild(sphere)

            // Attach the sphere to the finger.
            fingers[bone.0] = sphere
        }
    }
}
/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An enumeration representing each part of the finger that forms the hand's skeleton.
*/

fileprivate
enum Finger: Int, CaseIterable {
    case forearm
    case thumb
    case index
    case middle
    case ring
    case little
}
/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An enumeration that represents each part of the bone and defines the joint name from the hand skeleton.
*/
fileprivate
enum Bone: Int, CaseIterable {
    case arm
    case wrist
    case metacarpal
    case knuckle
    case intermediateBase
    case intermediateTip
    case tip
}
