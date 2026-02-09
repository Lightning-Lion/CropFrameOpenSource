import os
import CoreImage
import SwiftUI
import RealityKit

// 从相机照片中截取出取景框的部分
// Core Image 框架不要求主线程
struct QuadrilateralCropper {
    
    // 我就是Quadrilateral2D的Double版本
    struct Viewfinder2DCornersPose {
        var topLeft: Point2D
        var topRight: Point2D
        var bottomLeft: Point2D
        var bottomRight: Point2D
        
        func toQuadrilateral2D() -> Quadrilateral2D {
            Quadrilateral2D(
                topLeft: topLeft.toCGPoint(),
                topRight: topRight.toCGPoint(),
                bottomLeft: bottomLeft.toCGPoint(),
                bottomRight: bottomRight.toCGPoint()
            )
        }
    }
    
    // 取景框在3D中是一个矩阵
    // 但是投影在摄像头里就是一个四边形
    // 我们从相机照片里截取这个四边形，投影为矩形
    // 然后显示在3D中的取景框矩形里（不管上一步的裁切区域能给出多少分辨率，总是拉伸填满整个取景框）
    // 这样在摄像头看来它还是那个四边形
    func cropInViewfinderPart(
        image: CGImage,
        twoDCorners: QuadrilateralCropper.Viewfinder2DCornersPose,
        strictness: CropStrictness
    ) async throws -> CGImage {
        
        let quadrilateral2D: Quadrilateral2D = twoDCorners.toQuadrilateral2D()
        let imageSize = CGSize(width: image.width, height: image.height)
        
        let ciQuadrilateral:Quadrilateral2DCoreImageCoordinates = quadrilateral2D.toCoreImageCoordinates(in: imageSize)
        
        // 根据严格度等级进行验证
        try validateQuadrilateral(ciQuadrilateral, in: imageSize, with: strictness)
        // 裁剪并投影后的图片
        let cropImage = try await QuadrilateralCropActor().cropQuadrilateral(
            quadrilateral: quadrilateral2D,
            image: image,
            strictness: strictness
        )
        return cropImage
    }
    
    // 如果不希望拍摄的图像中有半透明区域
    // 就需要及早拦截
    private func validateQuadrilateral(
        _ quadrilateral: Quadrilateral2DCoreImageCoordinates,
        in imageSize: CGSize,
        with strictness: CropStrictness
    ) throws {
        let imageRect = CGRect(origin: .zero, size: imageSize)
        
        switch strictness {
        case .loose:
            // 宽松模式：不验证，直接通过
            break
            
        case .normal:
            // 普通模式：检查四边形是否与图片有交集
            guard quadrilateral.intersects(with: imageRect) else {
                throw QuadrilateralCropActor.CropQuadrilateralError.noIntersectionWithImage
            }
            
        case .strict:
            // 严格模式：检查四边形是否完全在图片内
            guard quadrilateral.isCompletelyInside(imageRect) else {
                throw QuadrilateralCropActor.CropQuadrilateralError.quadrilateralNotFullyInsideImage
            }
        }
    }
    
    // 裁切严格度等级
    enum CropStrictness {
        case loose      // 宽松：不要求四边形在画面内，可能裁切出纯透明图像
        case normal     // 普通：要求四边形与画面相交（默认），可能裁切出有一个角是透明的图像
        case strict     // 严格：要求四边形完全在照片内
        
        var description: String {
            switch self {
            case .loose:
                return "宽松模式（可能返回透明图像）"
            case .normal:
                return "普通模式（要求有交集）"
            case .strict:
                return "严格模式（完全包含在图片内）"
            }
        }
    }
    
    // 测试，确保行为和预期一致
    func testBehavior() async -> CGImage {
        // 版权来源：https://unsplash.com/photos/two-fathers-carrying-children-on-shoulders-on-a-mountain-path-peEOQ4_dqOo
        let image = UIImage(contentsOfFile: Bundle.main.url(forResource: "Unsplash.png", withExtension: nil)!.path(percentEncoded: true))!.cgImage!
        if true {
            // 在图像内
            return try! await cropInViewfinderPart(image: image, twoDCorners: .init(topLeft: .init(x: 694, y: 224), topRight: .init(x: 1098, y: 185), bottomLeft: .init(x: 686, y: 317), bottomRight: .init(x: 1119, y: 409)), strictness: .strict)
        } else {
            // 出界的，测试透明背景正不正常
            return try! await cropInViewfinderPart(image: image, twoDCorners: .init(topLeft: .init(x: -100, y: -100), topRight: .init(x: 2000, y: -185), bottomLeft: .init(x: -233, y: 1200), bottomRight: .init(x: 2200, y: 1670)), strictness: .loose)
        }
    }
    
    
    struct QuadrilateralDebug: View {
        @State
        private var cgImage:CGImage? = nil
        var body: some View {
            VStack {
                if let cgImage {
                    Image(cgImage, scale: 1, label: Text(""))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .border(.yellow, width: 4)
                }
                Text("Quadrilateral调试")
                    .font(.largeTitle.bold())
                    .task {
                        self.cgImage = await QuadrilateralCropper().testBehavior()
                    }
            }
        }
    }

    #Preview {
        QuadrilateralDebug()
    }
}

// 在后台线程执行图像操作
fileprivate actor QuadrilateralCropActor {
    // 传入一个四边形，裁切出来，投影为矩形
    func cropQuadrilateral(
        quadrilateral: Quadrilateral2D,
        image: CGImage,
        strictness: QuadrilateralCropper.CropStrictness
    ) throws -> CGImage {
        do {
            let inputCIImage: CIImage = CIImage(cgImage: image)
            // 将四边形坐标转换为Core Image坐标系（Y轴翻转）
            let ciQuadrilateral = quadrilateral.toCoreImageCoordinates(in: CGSize(width: image.width,height: image.height))
            let outputCIImage: CIImage = try perspectiveTransform(
                inputImage: inputCIImage,
                quadrilateral: ciQuadrilateral,
                strictness: strictness
            )
            let outputCGImage: CGImage = try ciImageToCGImage(ciImage: outputCIImage)
            return outputCGImage
        } catch {
            os_log("\(error.localizedDescription)")
            throw CropQuadrilateralError.cropFailed
        }
    }
    
    // 应用透视变换的核心函数
    // 我的行为表现就应该和
    // Imgproc.getPerspectiveTransform
    // 然后
    // Imgproc.warpPerspective(
    // 一样，其中src就是我这里得到的设置的值，dst就是目标画布的边角（目标画布的尺寸、长宽比不重要，反正最终上屏的时候是设置了width、height的，拉伸到对应值即可）
    // 如果呈现区域超出原图，会呈现透明
    // CIFilter.perspectiveCorrection有个问题，不支持负数（超出图像边界）的顶点区域，因此需要做一下包装
    private func perspectiveTransform(
        inputImage: CIImage,
        quadrilateral ciQuadrilateral: Quadrilateral2DCoreImageCoordinates,
        strictness: QuadrilateralCropper.CropStrictness
    ) throws -> CIImage {
        
        // 扩展图像并调整坐标
        let (extendedImage, adjustedQuad) = try extendImageIfNeeded(
            inputImage: inputImage,
            quadrilateral: ciQuadrilateral
        )
        
        // 执行透视变换
        let perspectiveTransformFilter = CIFilter.perspectiveCorrection()
        perspectiveTransformFilter.inputImage = extendedImage
        perspectiveTransformFilter.topLeft = adjustedQuad.topLeft
        perspectiveTransformFilter.topRight = adjustedQuad.topRight
        perspectiveTransformFilter.bottomLeft = adjustedQuad.bottomLeft
        perspectiveTransformFilter.bottomRight = adjustedQuad.bottomRight
        
        guard let outputImage = perspectiveTransformFilter.outputImage else {
            throw PerspectiveTransformError.filterFailed
        }
        
        return outputImage
    }
    
    // 因为裁切区域可能在图像外，所以会裁出空白的
    // 但因为CIFilter.perspectiveCorrection不支持往图像外裁剪
    // 我们需要提前扩展图像，把空白部分留出来
    private func extendImageIfNeeded(
        inputImage: CIImage,
        quadrilateral ciQuadrilateral: Quadrilateral2DCoreImageCoordinates
    ) throws -> (extendedImage: CIImage, adjustedQuadrilateral: Quadrilateral2DCoreImageCoordinates) {
        
        let imageBounds = CGRect(x: 0, y: 0,
                               width: inputImage.extent.width,
                               height: inputImage.extent.height)
        let quadBounds:CGRect = ciQuadrilateral.boundingRect()
        
        // 检查是否所有点都在图像内
        func pointInBounds(_ point: CGPoint) -> Bool {
            return imageBounds.contains(point)
        }
        
        let allPointsInside = [
            ciQuadrilateral.topLeft,
            ciQuadrilateral.topRight,
            ciQuadrilateral.bottomLeft,
            ciQuadrilateral.bottomRight
        ].allSatisfy(pointInBounds)
        
        if allPointsInside {
            return (inputImage, ciQuadrilateral)
        }
        
        // 计算需要的最小边界
        let minX = min(0, quadBounds.minX)
        let minY = min(0, quadBounds.minY)
        let maxX = max(imageBounds.maxX, quadBounds.maxX)
        let maxY = max(imageBounds.maxY, quadBounds.maxY)
        
        let newBounds = CGRect(x: 0, y: 0,
                              width: maxX - minX,
                              height: maxY - minY)
        
        // 创建新图像
        let backgroundColor = CIColor.clear
        let backgroundImage = CIImage(color: backgroundColor)
            .cropped(to: newBounds)
        
        // 计算平移量
        let translateX = -minX
        let translateY = -minY
        
        // 平移原始图像
        let transform = CGAffineTransform(
            translationX: translateX,
            y: translateY
        )
        let transformedImage = inputImage.transformed(by: transform)
        let extendedImage = transformedImage.composited(over: backgroundImage)
        
        // 调整四边形坐标
        let adjustedQuadrilateral = ciQuadrilateral.translatedBy(
            dx: translateX,
            dy: translateY
        )
        
        return (extendedImage, adjustedQuadrilateral)
    }

    // CIImage转CGImage
    // CGImage转CIImage直接用CIImage(cgImage: image)初始化器
    private func ciImageToCGImage(ciImage: CIImage) throws -> CGImage {
        let ciContext = CIContext()
        // 从 CIImage 初始化 CGImage（核心方法）
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw CIImageCreateCGImageError()
        }
        return cgImage
    }
    
    // 错误类
    enum CropQuadrilateralError: LocalizedError {
        case cropFailed
        case noIntersectionWithImage
        case quadrilateralNotFullyInsideImage
        
        var errorDescription: String? {
            switch self {
            case .cropFailed:
                return "裁切出取景框四边形失败"
            case .noIntersectionWithImage:
                return "四边形与图片没有交集"
            case .quadrilateralNotFullyInsideImage:
                return "四边形没有完全包含在图片内"
            }
        }
    }

    enum PerspectiveTransformError: Error {
        case filterFailed
        case extentCalculationFailed
        var errorDescription: String? {
            switch self {
            case .filterFailed:
                "filterFailed"
            case .extentCalculationFailed:
                "extentCalculationFailed"
            }
        }
    }
    
    struct CIImageCreateCGImageError: LocalizedError {
        var errorDescription: String? {
            "CIImage 转换 CGImage 失败"
        }
    }
}
