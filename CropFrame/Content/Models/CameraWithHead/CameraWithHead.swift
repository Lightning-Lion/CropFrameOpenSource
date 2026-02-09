import os
import SwiftUI
import ARKit
import RealityKit
import ARKit
import AVFoundation
import SwiftUI

// 捕获双目照片，附带头部姿态
// 外界只需要调用takePhoto()方法即可
// 在出错的时候在沉浸式空间内弹窗显示
@MainActor
@Observable
class CameraWithHead {
    var task:Task<Void,Never>? = nil
    var error:Error? = nil
    private let cameraPositions: [CameraFrameProvider.CameraPosition] = [.left, .right]
    private var arkitSession: ARKitSession? = nil
    private let worldTracking:WorldTrackingProvider = WorldTrackingProvider()
    private var cameraFrameProvider: CameraFrameProvider? = nil
    // 因为我们没法在调用takePhoto()去CameraFrameProvider获取.currentFrame（它的设计不提供这个属性），我们只能持续存储每一帧，然后在takePhoto()的时候拿最后一帧，这刚好也实现了零延迟快门（甚至还有略微提前）
    private var latest:LatestRawFrame? = nil
    private
    let context = CIContext(options: nil)
    
    func runCameraFrameProvider() async throws {
        let arkitSession = ARKitSession()
        let authorizationStatus = await arkitSession.requestAuthorization(for: [.cameraAccess])
        
        guard authorizationStatus[.cameraAccess] == .allowed else {
            throw RunCameraFrameProviderError()
        }
        
        let cameraFrameProvider = CameraFrameProvider()
        try await arkitSession.run([worldTracking,cameraFrameProvider])
        self.arkitSession = arkitSession
        self.cameraFrameProvider = cameraFrameProvider
        
        task = Task { @MainActor in
            do {
                try await observeCameraFrameUpdates(cameraFrameProvider:cameraFrameProvider)
                os_log("ImmersiveSpace关闭了")
            } catch {
                self.error = error
                os_log("相机流出错：\(error.localizedDescription)")
            }
        }
    }
    
    // 设计为返回确切的错误，而不是一个nil了事
    // 在这个时候才进行图片的处理，而不是每帧处理图片，降低发热
    func takePhoto() async throws -> Photo {
        guard let latest else {
            throw TakePhotoError.frameNotReady
        }
        do {
            let leftRaw = try await latest.left.buffer.toCGImage(context: context)
            let rightRaw = try await latest.right.buffer.toCGImage(context: context)
            // 进行降噪
            let left = try leftRaw.denoised()
            let right = try rightRaw.denoised()
            return Photo(left: left, right: right, head: latest.head)
        } catch {
            os_log("\(error.localizedDescription)")
            throw TakePhotoError.conversationError
        }
    }
    
    private func observeCameraFrameUpdates(cameraFrameProvider:CameraFrameProvider) async throws {
        // 我们希望用户在目之所及都可以拍照，而不要去左右摄像头都能完整覆盖画面
        let formats = CameraVideoFormat
            .supportedVideoFormats(for: .main, cameraPositions: cameraPositions)
            .filter({ $0.cameraRectification == .mono })
        
        // 拍照需要高质量分辨率
        let desiredFormat = formats.max { $0.frameSize.height < $1.frameSize.height }

        // 获取流
        guard let desiredFormat,
              let cameraFrameUpdates: CameraFrameProvider.CameraFrameUpdates = cameraFrameProvider.cameraFrameUpdates(for: desiredFormat) else {
            throw ObserveCameraFrameUpdates()
        }
        
        // 遍历流
        // 阻塞不要紧
        for await cameraFrame in cameraFrameUpdates {
            guard !Task.isCancelled else {
                os_log("CameraFrameUpdates被取消了，可能是ImmersiveSpace已被关闭，我被通知释放")
                break
            }
            guard worldTracking.state == .running else {
                logWithInterval("因为世界跟踪不可用，暂不更新相机帧", tag: "d3de0c9e163840eaae60")
                continue
            }
            // 在用户摘下头显的时候，虽然头部跟踪会丢失，但摄像头画面仍然能继续
            guard cameraFrameProvider.state == .running else {
                logWithInterval("因为CameraFrameProvider不可用，暂不更新相机帧", tag: "f84609f3-b984-4a96-bc89-c145cf8f2f70")
                continue
            }
            guard let leftSample = cameraFrame.sample(for: .left), let rightSample = cameraFrame.sample(for: .right) else {
                throw ObserveCameraFrameUpdates()
            }
            guard let head = getHead() else {
                logWithInterval("因为头部姿态不可用，暂不更新相机帧", tag: "7bb2ba40-f433-4474-acfa-74a3ef7bfc49")
                continue
            }
            latest = LatestRawFrame(left: leftSample, right: rightSample, head: head)
        }
        os_log("ImmersiveSpace关闭了")
    }
    
    
    
    private
    func getHead() -> Transform? {
        guard let anchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return nil
        }
        return Transform(matrix: anchor.originFromAnchorTransform)
    }
    
    struct LatestRawFrame {
        var left: CameraFrame.Sample
        var right: CameraFrame.Sample
        var head: Transform
    }
    
    struct Photo {
        var left: CGImage
        var right: CGImage
        // 后面裁切的时候要同时用到Viewfinder的.pose和Photo的.head
        var head: Transform
    }
    
    struct RunCameraFrameProviderError:LocalizedError {
        var errorDescription: String? {
            "authorizationStatus[.cameraAccess] != .allowed"
        }
    }
    struct ObserveCameraFrameUpdates:LocalizedError {
        var errorDescription: String? {
            "cameraFrameProvider.cameraFrameUpdates() return nil"
        }
    }
    enum TakePhotoError:LocalizedError {
        case frameNotReady
        case conversationError
        var errorDescription: String? {
            switch self {
            case .frameNotReady:
                "还没有可用的帧"
            case .conversationError:
                "格式转换错误"
            }
        }
    }
}

// 降噪
fileprivate
extension CGImage {
    func denoised(noiseLevel: Float = 0.02, sharpness: Float = 0.4) throws -> CGImage {
        let ciImage = CIImage(cgImage: self)
        
        let filter = CIFilter.noiseReduction()
        filter.inputImage = ciImage
        filter.noiseLevel = noiseLevel
        filter.sharpness = sharpness
        
        guard let outputImage = filter.outputImage,
              let cgImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            throw DenoiseError.ciImageToCGImageFailed
        }
        
        return cgImage
    }
    
    enum DenoiseError:LocalizedError {
        case ciImageToCGImageFailed
        var errorDescription: String? {
            switch self {
            case .ciImageToCGImageFailed:
                "CIImage转换到CGImage失败"
            }
        }
    }
}
