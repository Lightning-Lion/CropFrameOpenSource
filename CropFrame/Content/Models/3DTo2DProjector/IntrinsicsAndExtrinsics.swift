import os
import SwiftUI
import ARKit

// 在ImmersiveSpace启动的时候，获取一下内参和外参，在整个生命周期是不会变的
// 系统更新后调整相机投影方式了，可能会变
@MainActor
@Observable
class GetIntrinsicsAndExtrinsics {
    
    private let cameraPositions: [CameraFrameProvider.CameraPosition] = [.left, .right]
    private var arkitSession: ARKitSession? = nil
    private let worldTracking:WorldTrackingProvider = WorldTrackingProvider()
    private var cameraFrameProvider: CameraFrameProvider? = nil
    
    func getIntrinsicsAndExtrinsics() async throws -> IntrinsicsAndExtrinsics {
        let arkitSession = ARKitSession()
        let authorizationStatus = await arkitSession.requestAuthorization(for: [.cameraAccess])
        
        guard authorizationStatus[.cameraAccess] == .allowed else {
            throw RunCameraFrameProviderError()
        }
        
        let cameraFrameProvider = CameraFrameProvider()
        try await arkitSession.run([worldTracking,cameraFrameProvider])
        self.arkitSession = arkitSession
        self.cameraFrameProvider = cameraFrameProvider
        
        // 这些参数和class CameraWithHead {里一样
        let formats = CameraVideoFormat
            .supportedVideoFormats(for: .main, cameraPositions: cameraPositions)
            .filter({ $0.cameraRectification == .mono })
        
        let desiredFormat = formats.max { $0.frameSize.height < $1.frameSize.height }
        
        guard let desiredFormat,
              let cameraFrameUpdates = cameraFrameProvider.cameraFrameUpdates(for: desiredFormat) else {
            throw ObserveCameraFrameUpdates()
        }
        
        let resolution:CGSize = desiredFormat.frameSize
        
        // 获取到第一个就行了
        for await cameraFrame in cameraFrameUpdates {
            guard let leftEyeSample = cameraFrame.sample(for: .left), let rightEyeSample = cameraFrame.sample(for: .right) else {
                throw ObserveCameraFrameUpdates()
            }
            // 内参
            let leftEyeIntrinsics = leftEyeSample.parameters.intrinsics
            let rightEyeIntrinsics = rightEyeSample.parameters.intrinsics
            // 外参
            let leftEyeExtrinsics = leftEyeSample.parameters.extrinsics
            let rightEyeExtrinsics = rightEyeSample.parameters.extrinsics
            let intrinsicsAndExtrinsics:IntrinsicsAndExtrinsics = IntrinsicsAndExtrinsics(
                leftEyeIntrinsics: leftEyeIntrinsics,
                rightEyeIntrinsics: rightEyeIntrinsics,
                leftEyeExtrinsics: leftEyeExtrinsics,
                rightEyeExtrinsics: rightEyeExtrinsics,
                resolution: resolution
            )
            // 提早返回，提早结束循环
            return intrinsicsAndExtrinsics
        }
        // 流里一个元素也没有，直接结束了
        throw GetIntrinsicsAndExtrinsicsError.noSampleProvided
    }
    
    // 数据结构
    
    // 相机内参和外参在整个ImmersiveSpace生命周期是固定的，获取一次就行了
    // 系统更新后调整相机投影方式了，可能会变
    // 我只负责记录这一组数据，后处理交给3DTo2DProjector
    struct IntrinsicsAndExtrinsics {
        var leftEyeIntrinsics:simd_float3x3
        var rightEyeIntrinsics:simd_float3x3
        var leftEyeExtrinsics:simd_float4x4
        var rightEyeExtrinsics:simd_float4x4
        var resolution:CGSize
    }
    
    // 错误
    struct RunCameraFrameProviderError:LocalizedError {
        var errorDescription: String? {
            #if targetEnvironment(simulator)
            "请在真机上运行本项目"
            #else
            "权限未申请，导致authorizationStatus[.cameraAccess] != .allowed"
            #endif
        }
    }
    
    struct ObserveCameraFrameUpdates:LocalizedError {
        var errorDescription: String? {
            "cameraFrameProvider.cameraFrameUpdates() return nil"
        }
    }
    
    enum GetIntrinsicsAndExtrinsicsError:LocalizedError {
        case noSampleProvided
        var errorDescription: String? {
            switch self {
            case .noSampleProvided:
                "没有得到样本"
            }
        }
    }
}
