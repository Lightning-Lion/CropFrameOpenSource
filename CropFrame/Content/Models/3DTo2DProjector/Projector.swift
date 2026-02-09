import os
import SwiftUI
import Spatial
import RealityKit

// 把取景框投影到2D四边形
@MainActor
@Observable
class ThreeDTo2DProjector {
    // 传入要转换的点是左相机还是右相机
    var camera:Device.Camera
    // 传入原始内外参（整个生命周期不变，系统更新后调整相机投影方式了，可能会变）
    var intrinsicsAndExtrinsics:GetIntrinsicsAndExtrinsics.IntrinsicsAndExtrinsics
    init(camera: Device.Camera, intrinsicsAndExtrinsics: GetIntrinsicsAndExtrinsics.IntrinsicsAndExtrinsics) {
        self.camera = camera
        self.intrinsicsAndExtrinsics = intrinsicsAndExtrinsics
    }
    // 把3D点投影到2D像素坐标
    // 如果3D点不在面前，会抛出
    // 但我们允许fov外的，因为如果图像有一个角不在画面内，我们也可以裁切部分，QuadrilateralCropper会判断
    func to2DCornersPoint(
        cornersPose:ViewfinderOrnamentPoseToCornersPose.ViewfinderOrnamentCornersPose,
        head:Transform
    ) async throws -> QuadrilateralCropper.Viewfinder2DCornersPose {
        let perspectiveCameraData:PerspectiveCameraData = try await buildupPerspectiveData(head: head, intrinsicsAndExtrinsics: intrinsicsAndExtrinsics)
        let worldToCamera = WorldToCamera(perspectiveCameraData: perspectiveCameraData)
        // 转换每个点
        let topLeft2D = try worldToCamera.worldPointToCameraPixel(worldPoint: cornersPose.topLeft, eye: camera)
        let topRight2D = try worldToCamera.worldPointToCameraPixel(worldPoint: cornersPose.topRight, eye: camera)
        let bottomLeft2D = try worldToCamera.worldPointToCameraPixel(worldPoint: cornersPose.bottomLeft, eye: camera)
        let bottomRight2D = try worldToCamera.worldPointToCameraPixel(worldPoint: cornersPose.bottomRight, eye: camera)
        let twoDCornersPose:QuadrilateralCropper.Viewfinder2DCornersPose = QuadrilateralCropper.Viewfinder2DCornersPose(
            topLeft: topLeft2D,
            topRight: topRight2D,
            bottomLeft: bottomLeft2D,
            bottomRight: bottomRight2D
        )
        return twoDCornersPose
    }
    // 从传入的原始数据构造实用的PerspectiveCameraData
    private
    func buildupPerspectiveData(head:Transform,
                                intrinsicsAndExtrinsics:GetIntrinsicsAndExtrinsics.IntrinsicsAndExtrinsics) async throws -> PerspectiveCameraData {
        let currentFrameInner = intrinsicsAndExtrinsics
        let resolution:Size2D = Size2D(width: currentFrameInner.resolution.width, height: currentFrameInner.resolution.height)
        let perspectiveCameraData: PerspectiveCameraData = try await ProcessCameraFrameIntrinsicsAndExtrinsics().processCameraFrameIntrinsicsAndExtrinsics(
            deviceTransform: head,
            leftEyeIntrinsics: currentFrameInner.leftEyeIntrinsics,
            rightEyeIntrinsics: currentFrameInner.rightEyeIntrinsics,
            leftEyeExtrinsics: currentFrameInner.leftEyeExtrinsics,
            rightEyeExtrinsics: currentFrameInner.rightEyeExtrinsics,
            resolution:resolution
        )
        return perspectiveCameraData
    }
}

// 我只是存储使用左相机还是右相机与head
struct Device {
    var eye:Camera
    var deviceTransform:Transform
    public
    init(eye: Camera, deviceTransform: Transform) {
        self.eye = eye
        self.deviceTransform = deviceTransform
    }
    public
    enum Camera {
        case left
        case right
    }
}

// 存储一次进行世界→相机投影要用的数据
// 包括内参、外参、分辨率
fileprivate
struct PerspectiveCameraData:Equatable {
    var simpleIntrinsic:SingleEyeIntrinsic.SimpleCameraIntrinsic
    var leftEyeCameraPose:Transform
    var rightEyeCameraPose:Transform
    var resolution:Size2D
    
    init(simpleIntrinsic: SingleEyeIntrinsic.SimpleCameraIntrinsic, leftEyeCameraPose: Transform, rightEyeCameraPose: Transform, resolutionV1: Size2D) {
        self.simpleIntrinsic = simpleIntrinsic
        self.leftEyeCameraPose = leftEyeCameraPose
        self.rightEyeCameraPose = rightEyeCameraPose
        self.resolution = resolutionV1
    }
}


// 使用这一组内参，在游戏引擎中拍摄的时候，拍到的画面就和Vision Pro摄像头画面一样（针孔相机模型、透视投影、一样的Fov、一样的宽高比、一样的分辨率）。
fileprivate
nonisolated
struct SingleEyeIntrinsic {
    struct SimpleCameraIntrinsic:Equatable {
        var yfov_radians:Float
        var yfov_radiansV1:Double
        // 是width/height
        var aspectRatio:Float
        var aspectRatioV1:Double
        func yfov_deg() -> Float {
            return yfov_radians * (180.0 / .pi)
        }
        func yfov_degV1() -> Double {
            return yfov_radiansV1 * (180.0 / .pi)
        }
    }

    static
    func leftEyeSimpleIntrinsic(leftEyeIntrinsics:simd_double3x3,cameraImageSize:Size2D) throws -> SimpleCameraIntrinsic {
        // 内参矩阵
        let K = leftEyeIntrinsics

        // 提取 fx, fy, cx, cy
        let fx: Double = K.columns.0.x
        let fy: Double = K.columns.1.y
        let cx: Double = K.columns.0.z
        let cy: Double = K.columns.1.z

        // 分辨率
        let W = 2 * cx
        let H = 2 * cy
        
        // 下游处理的时候常常假设像素是正方形，我们要验证这一假设。
        guard fx == fy else {
            throw SimpleIntrinsicError.fxNotEqualfy("假设像素是正方形，fx应该等于fy。实际上fx不等于fy，像素不是正方形。")
        }
        
        // 下游处理的时候常常假设主点在图像中心，我们要验证。
        guard W == cameraImageSize.width && H == cameraImageSize.height else {
            throw SimpleIntrinsicError.widthOrHeightNotMatch("假设主点在图像中心，计算出的宽高是\(W)×\(H)，但实际的宽高是\(cameraImageSize.debugDescription)，也就是主点不在图像中心。")
        }
        
        // 计算 FOV（弧度）
        @inline(__always)
        func fovRad(size: Double, f: Double) -> Double {
            return 2.0 * atan((size * 0.5) / f)
        }

        let VFOV = fovRad(size: H, f: fy)
        return .init(yfov_radians: Float(VFOV), yfov_radiansV1: VFOV, aspectRatio: Float(W/H), aspectRatioV1: W/H)
    }
    
    // 错误类
    enum SimpleIntrinsicError:LocalizedError {
        case fxNotEqualfy(String)
        case widthOrHeightNotMatch(String)
        var errorDescription: String? {
            switch self {
            case .fxNotEqualfy(let detail):
                detail
            case .widthOrHeightNotMatch(let detail):
                detail
            }
        }
    }
}

// 使用这一组外参，配合上面的那组内参，在游戏引擎中拍摄的时候，拍到的画面就和Vision Pro摄像头画面一样。
fileprivate
nonisolated
struct SingleEyeExtrinsic {
    static
    func getViewTransform(from extrinsic: simd_float4x4) throws -> Transform {
        // CameraFrame.Sample.Parameters给出的所谓外参，需要经过如下变换，才是可用于pyrender渲染的外参：先绕X轴旋转180度，然后求逆
        let rotation:simd_quatf = simd_quatf(angle: .pi,axis: [1,0,0])
        let rotationMatrix:simd_float4x4 = Transform(rotation: rotation).matrix
        
        let rotated:simd_float4x4 = (rotationMatrix * extrinsic)
        let inversed:simd_float4x4 = rotated.inverse
        let cameraViewTransform = Transform(matrix: inversed)
        // 下游处理的时候（比如Kabsch算法设计用于找到最优的刚体变换）
        // 常常假设相机外参只包含旋转和平移，我们要验证这一点。
        
        // 验证 det(R) == 1
        let epsilon:Float = 1e-6
        guard abs(simd_determinant(cameraViewTransform.matrix) - 1) < epsilon else {
            throw GetViewTransformError.notRigidTransformation("假设是正交变换（旋转+平移），行列式理应为 1，事实上行列式不等于 1，所以矩阵包含缩放或投影。")
        }
        let tolerance:Float = 1e-6
        guard abs(cameraViewTransform.scale.x - 1) < tolerance &&
                abs(cameraViewTransform.scale.y - 1) < tolerance &&
                abs(cameraViewTransform.scale.z - 1) < tolerance else {
            throw GetViewTransformError.notRigidTransformation("不是刚性变换，可能带有缩放。")
        }
        // 验证是否只包含旋转和平移，没有缩放、非均匀缩放或其他仿射变换成分。
        guard isEqual(cameraViewTransform,Transform(rotation: cameraViewTransform.rotation, translation: cameraViewTransform.translation),tolerance: 1e-6) else {
            throw GetViewTransformError.notRigidTransformation("不是刚性变换，可能带有缩放和剪切。")
        }
        
        return Transform(matrix: inversed)
    }
    private
    static
    func isEqual(_ origin: Transform, _ target: Transform, tolerance: Float) -> Bool {
        // translation
        let translationEqual = origin.translation == target.translation
        // rotation
        let rotationEqual = origin.rotation == target.rotation
        // scale
        let scaleEqual = all(abs(origin.scale - target.scale) .<= SIMD3<Float>(repeating: tolerance))

        return translationEqual && rotationEqual && scaleEqual
    }
    // 错误类
    enum GetViewTransformError:LocalizedError {
        case notRigidTransformation(String)
        var errorDescription: String? {
            switch self {
            case .notRigidTransformation(let detail):
                detail
            }
        }
    }
}

// 从Sample给出的内参外参，计算出方便我们计算的内参外参
// 因为Sample给出的外参是局部的，而不是全局的，不符合一般渲染引擎外参的习惯
fileprivate
actor ProcessCameraFrameIntrinsicsAndExtrinsics {
    // 我需要转换一些类型，主要是计算出leftEyeCameraPose和rightEyeCameraPose
    func processCameraFrameIntrinsicsAndExtrinsics(
        deviceTransform: Transform,
        leftEyeIntrinsics: simd_float3x3,
        rightEyeIntrinsics: simd_float3x3,
        leftEyeExtrinsics: simd_float4x4,
        rightEyeExtrinsics: simd_float4x4,
        resolution: Size2D
    ) throws -> PerspectiveCameraData {
        // 以Vision Pro的硬件设计，左右相机的内参应该是一样的
        guard leftEyeIntrinsics == rightEyeIntrinsics else {
            throw ProcessCameraFrameIntrinsicsAndExtrinsicsError.designForVisionProOnly
        }
        let simpleIntrinsic = try SingleEyeIntrinsic.leftEyeSimpleIntrinsic(leftEyeIntrinsics: convertToDouble3x3(from: leftEyeIntrinsics), cameraImageSize: resolution)
       
        let leftEyeCameraViewTransform = try SingleEyeExtrinsic.getViewTransform(from: leftEyeExtrinsics)
        // 计算左眼在世界中的pose
        let leftEyeCameraPose = {
            let leftEyeCameraExtrinsic = Transform(matrix: deviceTransform.matrix*leftEyeCameraViewTransform.matrix)
            return leftEyeCameraExtrinsic
        }()
        
        let rightEyeCameraViewTransform = try SingleEyeExtrinsic.getViewTransform(from: rightEyeExtrinsics)
        // 计算右眼在世界中的pose
        let rightEyeCameraPose = {
            let rightEyeCameraExtrinsic = Transform(matrix: deviceTransform.matrix*rightEyeCameraViewTransform.matrix)
            return rightEyeCameraExtrinsic
        }()
        
        let perspectiveCameraData:PerspectiveCameraData = PerspectiveCameraData(simpleIntrinsic: simpleIntrinsic, leftEyeCameraPose: leftEyeCameraPose, rightEyeCameraPose: rightEyeCameraPose, resolutionV1: resolution)
        
        return perspectiveCameraData
    }
    
    // 目前ARKit给的相机内参外参还是Float，我们在这里提升为Double，确保下游的计算精度。
    private
    func convertToDouble3x3(from floatMatrix: simd_float3x3) -> simd_double3x3 {
        // 遍历3x3矩阵的每一列和每个元素，将Float转换为Double
        return simd_double3x3(
            columns: (
                SIMD3<Double>(Double(floatMatrix.columns.0.x), Double(floatMatrix.columns.0.y), Double(floatMatrix.columns.0.z)),
                SIMD3<Double>(Double(floatMatrix.columns.1.x), Double(floatMatrix.columns.1.y), Double(floatMatrix.columns.1.z)),
                SIMD3<Double>(Double(floatMatrix.columns.2.x), Double(floatMatrix.columns.2.y), Double(floatMatrix.columns.2.z))
            )
        )
    }
    
    // 错误
    enum ProcessCameraFrameIntrinsicsAndExtrinsicsError:LocalizedError {
        case designForVisionProOnly
        var errorDescription: String? {
            switch self {
            case .designForVisionProOnly:
                "本App仅为Vision Pro设计"
            }
        }
    }
}

// 将世界点转换为相机点
fileprivate
class WorldToCamera {
    // 传入包括内参、外参、分辨率的PerspectiveCameraData
    private
    var perspectiveCameraData:PerspectiveCameraData
    
    init(perspectiveCameraData: PerspectiveCameraData) {
        self.perspectiveCameraData = perspectiveCameraData
    }
    
    /// 将世界坐标系中的3D点投影到相机图像平面
    /// - Parameters:
    ///   - worldPoint: 世界坐标系中的3D点
    ///   - eye: 左眼或右眼相机
    /// - Returns: 2D像素坐标
    func worldPointToCameraPixel(
        worldPoint: Point3D,
        eye: Device.Camera
    ) throws -> Point2D {
        // 1. 获取相机参数
        let cameraPose = getCameraPose(for: eye)
        let resolution = perspectiveCameraData.resolution
        // 从内参矩阵中提取焦距 (fx, fy) 和主点 (cx, cy)，焦距的单位是像素而不是毫米
        let (fx, fy, cx, cy) = GetIntrinsics().restoreIntrinsicsV1(simpleIntrinsic: perspectiveCameraData.simpleIntrinsic, resolution: resolution)
        
        // 2. 将世界点转换到相机坐标系
        // 把局部的方向向量转换为世界的方向向量，计算时将齐次坐标的 w 分量设为 0。
        let worldPointHomogeneous = SIMD4<Double>(
            worldPoint.x,
            worldPoint.y,
            worldPoint.z,
            1.0
        )
        
        // 计算相机变换矩阵的逆（世界→相机）
        let cameraViewMatrix = cameraPose.inverse  // 关键：需要逆矩阵
        
        // 转换到相机空间
        let cameraSpaceHomogeneous = cameraViewMatrix * worldPointHomogeneous
        let cameraSpacePoint = cameraSpaceHomogeneous.xyz
        
        // 3. 检查点是否在相机前方（Z < 0 在相机坐标系中通常表示前方）
        if cameraSpacePoint.z >= 0 {
            // 无法执行投影
            throw WorldToCameraError.pointNotInFront
        }
        
        // 4. 透视投影到图像平面
        // 使用相似三角形原理
        let normalizedX = cameraSpacePoint.x / (-cameraSpacePoint.z)  // Z为负，需要取反
        let normalizedY = cameraSpacePoint.y / (-cameraSpacePoint.z)
        
        // 5. 转换为像素坐标
        let pixelX = normalizedX * fx + cx
        let pixelY = normalizedY * fy + cy
        
        // 6. Y轴翻转（3D Y向上 → 图像Y向下）
        // 因为3D中，+X是向右的，+Y是向上的，而图片中，+X是向右的，+Y是向下的，所以需要翻转Y轴
        let imageY = resolution.height - pixelY
        
        return Point2D(x: pixelX, y: imageY)
    }
    
    // 获取相机的世界姿态
    private func getCameraPose(for camera: Device.Camera) -> simd_double4x4 {
        switch camera {
        case .left:
            return perspectiveCameraData.leftEyeCameraPose.matrixDouble
        case .right:
            return perspectiveCameraData.rightEyeCameraPose.matrixDouble
        }
    }
    
    // 错误类
    enum WorldToCameraError:LocalizedError {
        case pointNotInFront
        var errorDescription: String? {
            switch self {
            case .pointNotInFront:
                "点在相机后方或平面上，不可见"
            }
        }
    }
    
    // 计算内参
    fileprivate
    class GetIntrinsics {
        // 从图片宽高计算cx和cy
        func getCxCy(W:Float,H:Float) -> (cx:Float,cy:Float) {
            let cx = W/2
            let cy = H/2
            return (cx:cx,cy:cy)
        }
        
        // 从 FOV（弧度）和图片高度计算fy
        func fy(vfov:Float,height:Float) -> Float {
            let size = height
            let VFOV = vfov
            let fy = (size * 0.5) / tan(VFOV / 2.0)
            return fy
        }
        
        // 从图片宽高计算cx和cy
        func getCxCyV1(W:Double,H:Double) -> (cx:Double,cy:Double) {
            let cx = W/2
            let cy = H/2
            return (cx:cx,cy:cy)
        }
        
        // 从 FOV（弧度）和图片高度计算fy
        func fyV1(vfov:Double,height:Double) -> Double {
            let size = height
            let VFOV = vfov
            let fy = (size * 0.5) / tan(VFOV / 2.0)
            return fy
        }
     
        func restoreIntrinsicsV1(simpleIntrinsic:SingleEyeIntrinsic.SimpleCameraIntrinsic,resolution: Size2D) -> (fx:Double,fy:Double,cx:Double,cy:Double) {
            let (cx,cy) = getCxCyV1(W: resolution.width, H: resolution.height)
            let fy = fyV1(vfov: simpleIntrinsic.yfov_radiansV1, height: resolution.height)
            // 像素是正方形
            let fx = fy
            return (fx:fx,fy:fy,cx:cx,cy:cy)
        }
    }
}
