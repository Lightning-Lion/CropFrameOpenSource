//
//  QuadrilateralImageToRectImage.swift
//  CropFrame
//
//  Created by LightningLion on 2025/1/24.
//

import SwiftUI
import MixedRealityKit
import os
import opencv2

/// 扭曲四边形图像到矩形
func quadrilateralImageToRectImage(quadrilateralImage:CGImage,quadrilateral2D:Quadrilateral2D,outputRectImageSize:CGSize) -> CGImage? {
//    os_log("四边形\(String(describing: quadrilateral2D))")
    // 1. 创建目标矩形的四个角点
    let destTopLeft = CGPoint(x: 0, y: 0)
    let destTopRight = CGPoint(x: outputRectImageSize.width, y: 0)
    let destBottomRight = CGPoint(x: outputRectImageSize.width, y: outputRectImageSize.height)
    let destBottomLeft = CGPoint(x: 0, y: outputRectImageSize.height)
    
    // 2. 创建源点和目标点数组
    let sourcePoints = [
        quadrilateral2D.topLeft,
        quadrilateral2D.topRight,
        quadrilateral2D.bottomRight,
        quadrilateral2D.bottomLeft
    ]
    
    let destPoints = [
        destTopLeft,
        destTopRight,
        destBottomRight,
        destBottomLeft
    ]
    do {
        
        // 3. 计算透视变换矩阵
        let perspectiveTransform = try PerspectiveTransform.getPerspectiveTransform(src: sourcePoints, dst: destPoints)
        
        let outputSize:Size2i = PerspectiveTransform.cgSizeToSize2i(outputRectImageSize)
//        os_log("要求输出尺寸：\(outputSize.description())")
        // 7. 获取结果图像
        let transformedImage = PerspectiveTransform.warpPerspective(image: quadrilateralImage, perspectiveMatrix: perspectiveTransform, outputSize: outputSize)
//        os_log("图片输出尺寸：\(transformedImage.width), \(transformedImage.height)")
         return transformedImage
    } catch {
        os_log("\(String(describing:error))")
        return nil
    }
}
