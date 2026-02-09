import Foundation
import CoreGraphics
import SwiftUI

// 在图片上绘制调试框
struct QuadrilateralVisualization {
    // 用法：
    // 在QuadrilateralCropper的func cropInViewfinderPart()内
    // 调试算法：在图像上绘制可视化
//        let debugVisualize = try await drawQuadrilateral(image: image, quadrilateral: quadrilateral2DCoreImage)
//        return debugVisualize
    func drawQuadrilateral(image: CGImage, quadrilateral: Quadrilateral2DCoreImageCoordinates) throws -> CGImage {
        // 获取图像尺寸
        let width = image.width
        let height = image.height
        
        // 创建绘制上下文
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw NSError(domain: "QuadrilateralDrawer", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create graphics context"])
        }
        
        // 设置上下文参数
        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        
        // 绘制原始图像
        let imageRect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(image, in: imageRect)
        
        // 设置四边形绘制属性
        context.setLineWidth(10.0)
        context.setStrokeColor(UIColor.yellow.cgColor)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        
        // 绘制四边形
        context.beginPath()
        
        // 移动到左上角
        context.move(to: quadrilateral.topLeft)
        
        // 绘制四条边
        context.addLine(to: quadrilateral.topRight)      // 上边
        context.addLine(to: quadrilateral.bottomRight)   // 右边
        context.addLine(to: quadrilateral.bottomLeft)    // 下边
        context.addLine(to: quadrilateral.topLeft)       // 左边，闭合图形
        
        // 描边
        context.strokePath()
        
        // 从上下文中获取图像
        guard let resultImage = context.makeImage() else {
            throw NSError(domain: "QuadrilateralDrawer", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create output image"])
        }
        
        return resultImage
    }
}

// 让CGRect可以直接在日志中被打印
extension CGRect: @retroactive CustomStringConvertible {
    public var description: String {
        return String(format: "CGRect(x: %.2f, y: %.2f, width: %.2f, height: %.2f)",
                      origin.x, origin.y, size.width, size.height)
    }
}
