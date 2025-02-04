import SwiftUI
import RealityKit
import os
import MixedRealityKit


/// 负责将取景框内的画面，从完整的相机帧中裁剪出来
struct ImageCropper {
    
    static
    func cropImage(cropFrameData:CropFrameData,photo:FrameData,photoViewPhysicalSize:CropBoxPositionController.RectangleSize,mrData:MRData) -> CGImage? {
        let deviceTransform:Transform = photo.deviceTransform
        do {
            let quadrilateral2D:Quadrilateral2D = try cropFrameData.vertices.toRect2D { point3D in
                let point2D = try MRPoint2D3DConverterFast.worldPointToCameraPoint(worldPoint: point3D, deviceTransform: deviceTransform, mrData: mrData)
                return point2D
            }
            guard let croppedImage:CGImage = twoDCropImage(quadrilateral: quadrilateral2D, photo: photo.cameraPhoto, photoViewPhysicalSize: photoViewPhysicalSize) else {
                os_log("CGImage裁剪图片失败")
                return nil
            }
            return croppedImage
        } catch {
            os_log("\(String(describing: error))")
            return nil
        }
        
    }
    
    private
    static
    func twoDCropImage(quadrilateral:Quadrilateral2D,photo:CGImage,photoViewPhysicalSize:CropBoxPositionController.RectangleSize) -> CGImage? {
        // ---
        // 本来是先以四边形裁剪，然后再扭曲到矩形
        // 现在发现用OpenCV直接以四边形的四个点，做扭曲到矩形的四个点，就可以了
        // ---
        // 不管物理尺寸多少，总是使用1080P
        let photoViewImageSize = resizeTo1080P(width: photoViewPhysicalSize.0, height: photoViewPhysicalSize.1)
//        os_log("要求的图片的尺寸\(photoViewImageSize.0),\(photoViewImageSize.1)")
        // 然后扭曲到矩形，以便PhotoView使用
        guard let perspectivedImage:CGImage = quadrilateralImageToRectImage(quadrilateralImage: photo, quadrilateral2D: quadrilateral, outputRectImageSize: toCGSize(inputValue: photoViewImageSize)) else {
            os_log("使用OpenCV完成透视变换失败")
            return nil
        }
        os_log("最终得到的图片的尺寸\(perspectivedImage.width),\(perspectivedImage.height)")
        return perspectivedImage
    }
    
    
    // 保持比例不变，最短边总是1080像素
    // 输入和输出都是“宽，高”
    private
    static
    func resizeTo1080P(width: Float, height: Float) -> (Float, Float) {
        let targetMin: Float = 1080
        
        if width < height {
            // 如果宽度是最短边
            let aspectRatio = height / width
            let newHeight = targetMin * aspectRatio
            return (targetMin, newHeight)
        } else {
            // 如果高度是最短边
            let aspectRatio = width / height
            let newWidth = targetMin * aspectRatio
            return (newWidth, targetMin)
        }
    }
    private
    static
    func toCGSize(inputValue:(Float, Float)) -> CGSize {
        let widthCGFloat:CGFloat = CGFloat(inputValue.0)
        let heightCGFloat:CGFloat = CGFloat(inputValue.1)
        return CGSize(width: widthCGFloat, height: heightCGFloat)
    }
}
