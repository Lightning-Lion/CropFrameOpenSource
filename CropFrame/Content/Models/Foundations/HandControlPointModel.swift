import os
import SwiftUI
import ARKit
import RealityKit

@MainActor
@Observable
class HandControlPointModel {
    private
    let leftHandIndexFingerTip = AnchorEntity(.hand(.left, location: .indexFingerTip))
    private
    let leftHandThumbTip = AnchorEntity(.hand(.left, location: .thumbTip))
    private
    let rightHandIndexFingerTip = AnchorEntity(.hand(.right, location: .indexFingerTip))
    private
    let rightHandThumbTip = AnchorEntity(.hand(.right, location: .thumbTip))
    // 手指追踪
    private
    let spatialSession = SpatialTrackingSession()
    func run(baseEntity:Entity) async {
        let unavailable = await spatialSession.run(SpatialTrackingSession.Configuration(tracking: [.hand]))
        if let unavailable {
            guard unavailable.anchor.isEmpty else {
                fatalError("手势追踪开启失败")
            }
        }
        baseEntity.addChild(leftHandThumbTip)
        baseEntity.addChild(leftHandIndexFingerTip)
        baseEntity.addChild(rightHandThumbTip)
        baseEntity.addChild(rightHandIndexFingerTip)
        os_log("手势追踪运行中")
    }
    // 取大拇指和食指中心点
    func getControlPoint(baseEntity:Entity) -> (Point3D,Point3D)? {
        // 左右手都要
        guard let leftSIMD3Float = getLeftHandPosition(baseEntity: baseEntity),let rightSIMD3Float = getRightHandPosition(baseEntity: baseEntity) else {
            return nil
        }
        // 转换类型
        let left = PointAndVectorAndTransformConverter.simd3FloatToPoint3D(leftSIMD3Float)
        let right = PointAndVectorAndTransformConverter.simd3FloatToPoint3D(rightSIMD3Float)
        return (left,right)
    }
    private
    func getLeftHandPosition(baseEntity:Entity) -> SIMD3<Float>? {
        guard leftHandIndexFingerTip.isAnchored,leftHandThumbTip.isAnchored else {
            return nil
        }
        let indexPosition = Transform(matrix: leftHandIndexFingerTip.transformMatrix(relativeTo: baseEntity)).translation
        let thumbPosition = Transform(matrix: leftHandThumbTip.transformMatrix(relativeTo: baseEntity)).translation
        let center = (thumbPosition + indexPosition) / 2
        return center
    }
    private
    func getRightHandPosition(baseEntity:Entity) -> SIMD3<Float>? {
        guard rightHandIndexFingerTip.isAnchored,rightHandThumbTip.isAnchored else {
            return nil
        }
        let indexPosition = Transform(matrix: rightHandIndexFingerTip.transformMatrix(relativeTo: baseEntity)).translation
        let thumbPosition = Transform(matrix: rightHandThumbTip.transformMatrix(relativeTo: baseEntity)).translation
        let center = (thumbPosition + indexPosition) / 2
        return center
    }
}
