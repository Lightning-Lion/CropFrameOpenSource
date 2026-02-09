import os
import SwiftUI
import ARKit
import RealityKit

@MainActor
@Observable
class HeadAxisModel {
    private
    let arSession = ARKitSession()
    private
    let worldTracking = WorldTrackingProvider()
    func run() async throws {
        do {
            try await arSession.run([worldTracking])
            // 启动成功了就会返回
        } catch {
            // 包装错误
            throw WorldTrackingLostError()
        }
    }
    func getHeadTransform() -> Transform? {
        let device = getDeviceTransform(worldTracking: worldTracking)
        let head = device
        return head
    }
    private
    func getDeviceTransform(worldTracking:WorldTrackingProvider) -> Transform? {
        guard worldTracking.state == .running else {
            return nil
        }
        guard let anchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return nil
        }
        return Transform(matrix: anchor.originFromAnchorTransform)
    }
    struct WorldTrackingLostError:LocalizedError {
        var errorDescription: String? {
            "世界跟踪丢失"
        }
    }
}
