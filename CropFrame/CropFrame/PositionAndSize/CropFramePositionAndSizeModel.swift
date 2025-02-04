//
//  CropBoxPositionController.swift
//  CropFrame
//
//  Created by LightningLion on 2025/1/23.
//

import SwiftUI
import RealityKit
import os

/// 根据手的位置，计算取景框的位置和尺寸
@MainActor
@Observable
class CropBoxPositionController {

    struct RectangleResult {
        let center: SIMD3<Float>    // 矩形的中心点
        let vertices: [SIMD3<Float>] // 四个顶点，顺序：左上、右上、右下、左下
    }

    func calculateRectangle(pointA: SIMD3<Float>, pointB: SIMD3<Float>) -> RectangleResult? {
        // 检查两点是否能构成合法矩形
        // 1. 如果两点在同一水平面上(Y相同)，则无法构成矩形
        if pointA.y == pointB.y {
            return nil
        }
        
        // 2. 如果两点的X和Z完全相同，也无法构成矩形
        if pointA.x == pointB.x && pointA.z == pointB.z {
            return nil
        }
        
        var vertices: [SIMD3<Float>] = []
        
        if pointA.y > pointB.y {
            // A的Y更大，所以A是左上点，B是右下点
            vertices = [
                pointA,                                    // 左上
                SIMD3<Float>(pointB.x, pointA.y, pointB.z),  // 右上
                pointB,                                    // 右下
                SIMD3<Float>(pointA.x, pointB.y, pointA.z)   // 左下
            ]
        } else {
            // A的Y更小，所以A是左下点，B是右上点
            vertices = [
                SIMD3<Float>(pointA.x, pointB.y, pointA.z),  // 左上
                pointB,                                    // 右上
                SIMD3<Float>(pointB.x, pointA.y, pointB.z),  // 右下
                pointA                                     // 左下
            ]
        }
        
        // 计算中心点
        let center = (pointA + pointB) / 2
        
        return RectangleResult(center: center, vertices: vertices)
    }

    // 使用示例：
    struct Ray {
        let origin: SIMD3<Float>    // 射线起点
        let direction: SIMD3<Float> // 射线方向（单位向量）
    }

    /// 计算矩形平面的两个法线（一个指向正面，一个指向反面）
    func calculateNormals(_ rectangle: RectangleResult) -> (front: Ray, back: Ray) {
        // 1. 获取两个边的向量
        let v1 = rectangle.vertices[1] - rectangle.vertices[0]  // 上边的向量（右上 - 左上）
        let v2 = rectangle.vertices[3] - rectangle.vertices[0]  // 左边的向量（左下 - 左上）
        
        // 2. 计算叉积得到法向量（v1 × v2）并归一化
        let frontDirection = simd_normalize(simd_cross(v1, v2))
        let backDirection = -frontDirection  // 反方向
        
        // 3. 使用矩形中心点作为起点
        return (
            front: Ray(origin: rectangle.center, direction: frontDirection),
            back: Ray(origin: rectangle.center, direction: backDirection)
        )
    }

    /// 选择朝向相机的法线方向
    func selectVisibleNormal(normals: (front: Ray, back: Ray), cameraPosition: SIMD3<Float>) -> Ray {
        // 1. 计算从平面中心指向相机的向量
        let toCamera = simd_normalize(cameraPosition - normals.front.origin)
        
        // 2. 计算两个方向与指向相机向量的点积
        let frontDot = simd_dot(normals.front.direction, toCamera)
        
        // 3. 如果前向法线与指向相机的向量点积为正，说明前向法线朝向相机
        return frontDot > 0 ? normals.front : normals.back
    }

    /// 计算将标准坐标系对齐到矩形平面的旋转四元数
    /// +Y 对齐到矩形的上向量（从下到上）
    /// +X 对齐到矩形的右向量（从左到右）
    /// -Z 对齐到给定的法线方向
    func calculateRectangleRotation(rectangleResult: RectangleResult, normal: Ray) -> simd_quatf {
        // 1. 计算矩形的基向量（归一化）
        let upVector = simd_normalize(rectangleResult.vertices[0] - rectangleResult.vertices[3])
        let rightVector = simd_normalize(rectangleResult.vertices[1] - rectangleResult.vertices[0])
        let forwardVector = normal.direction
        
        // 2. 构建旋转矩阵
        // 以便最终的图片是面向我的。
        let rotationMatrix = simd_float3x3(
            columns: (
                rightVector,
                upVector,
                forwardVector
            )
        )
        
        return simd_quaternion(rotationMatrix)
    }
    
    
    typealias RectangleSize = (Float,Float) // 宽、高，以米为单位
    /// 计算矩形的尺寸（宽度和高度，以米为单位）
    func calculateRectangleSize(_ rectangle: RectangleResult) -> RectangleSize {
        // 计算宽度（左上到右上的距离）
        let width = simd_length(rectangle.vertices[1] - rectangle.vertices[0])
        
        // 计算高度（左下到左上的距离）
        let height = simd_length(rectangle.vertices[0] - rectangle.vertices[3])
        
        return RectangleSize(width: width, height: height)
    }

    
    func exampleP0() {
        // 示例1：pointA的Y更大，作为左上点
        let pointA1 = SIMD3<Float>(0, 2, 3)  // 左上
        let pointB1 = SIMD3<Float>(2, 0, 0)  // 右下
        if let result1 = calculateRectangle(pointA: pointA1, pointB: pointB1) {
            print("示例1 - 矩形中心点:", result1.center)
            print("顶点:")
            for (index, vertex) in result1.vertices.enumerated() {
                print("顶点\(index + 1):", vertex)
            }
        }
        
        // 示例2：pointA的Y更小，作为左下点
        let pointA2 = SIMD3<Float>(0, 0, 3)  // 左下
        let pointB2 = SIMD3<Float>(2, 2, 0)  // 右上
        if let result2 = calculateRectangle(pointA: pointA2, pointB: pointB2) {
            print("示例2 - 矩形中心点:", result2.center)
            print("顶点:")
            for (index, vertex) in result2.vertices.enumerated() {
                print("顶点\(index + 1):", vertex)
            }
        }
    }
    func exampleP1() {
        let pointA = SIMD3<Float>(0, 2, 3)
        let pointB = SIMD3<Float>(2, 0, 0)
        if let rectangle = calculateRectangle(pointA: pointA, pointB: pointB) {
            let normals = calculateNormals(rectangle)
            let cameraPosition = SIMD3<Float>(1, 1, 5)
            let visibleNormal = selectVisibleNormal(normals: normals, cameraPosition: cameraPosition)
            
            // 计算旋转四元数
            let rotation = calculateRectangleRotation(rectangleResult: rectangle, normal: visibleNormal)
            
            // 构建变换
            let transform = Transform(
                scale: .one,
                rotation: rotation,
                translation: rectangle.center
            )
        }
    }
    typealias ThumbIndexMidpoint = SIMD3<Float>
    // 相机位置只是用来确定平面是哪一面朝向了用户（如果点积大于0，说明夹角小于90度，即前向法线朝向相机，返回前向法线；否则返回背向法线），具体用Device位置、还是左眼位置、还是右眼位置，都不重要。
    func getCropBoxData(leftHandTargetPosition:ThumbIndexMidpoint,rightHandTargetPosition:ThumbIndexMidpoint,cameraPosition:SIMD3<Float>) -> CropFrameData? {
        let pointA = leftHandTargetPosition
        let pointB = rightHandTargetPosition
        if let rectangle = calculateRectangle(pointA: pointA, pointB: pointB) {
            let normals = calculateNormals(rectangle)
            let cameraPosition = cameraPosition
            let visibleNormal = selectVisibleNormal(normals: normals, cameraPosition: cameraPosition)
            
            // 计算旋转四元数
            let rotation = calculateRectangleRotation(rectangleResult: rectangle, normal: visibleNormal)
            
            // 构建变换
            let transform = Transform(
                scale: .one,
                rotation: rotation,
                translation: rectangle.center
            )
            let size:RectangleSize = calculateRectangleSize(rectangle)
            let vertices:Rect2DIn3D = Rect2DIn3D(topLeft: rectangle.vertices[0], topRight: rectangle.vertices[1], bottomRight: rectangle.vertices[2], bottomLeft: rectangle.vertices[3])
            return CropFrameData(transform:transform,size:size, vertices:vertices)
        }
        os_log("双手的位置不合法，比如同在Y轴上导致无法计算矩形")
        return nil
    }
}

struct CropFrameData:Identifiable,Equatable {
    // 每帧的数据，都会被赋予新的id和时间戳，以作区分
    let id = UUID()
    let timestamp = Date.now
    
    // 对CropFrame实体的中心点的变换
    let transform:Transform
    
    // 宽、高，米为单位
    let size:CropBoxPositionController.RectangleSize
    
    let vertices:Rect2DIn3D
}

extension CropFrameData {
    
    static func == (lhs: CropFrameData, rhs: CropFrameData) -> Bool {
        lhs.id == rhs.id
    }
    
}

struct Rect2DIn3D {
    let topLeft:SIMD3<Float>
    let topRight:SIMD3<Float>
    let bottomRight:SIMD3<Float>
    let bottomLeft:SIMD3<Float>
    func toRect2D(converFunction:@escaping (SIMD3<Float>) throws -> CGPoint) rethrows -> Quadrilateral2D {
        Quadrilateral2D(topLeft: try converFunction(topLeft), topRight: try converFunction(topRight), bottomRight: try converFunction(bottomRight), bottomLeft: try converFunction(bottomLeft))
    }
}

// 表示一个四边形，因为从3D投影来的，很可能不是矩形
struct Quadrilateral2D {
    let topLeft:CGPoint
    let topRight:CGPoint
    let bottomRight:CGPoint
    let bottomLeft:CGPoint
}

enum Quadrilateral2DError: Error {
    case invalidQuadrilateral(String)
    case invalidTolerance(String)
}

extension Quadrilateral2D {
    // 默认实现，使用 5% 的容差
//    更严格：可以改为 3%
//    更宽松：可以改为 8%
    func toCGRect() throws -> CGRect {
        return try toCGRect(tolerancePercentage: 0.05)
    }
    
    // 带自定义容差的实现
    func toCGRect(tolerancePercentage: CGFloat) throws -> CGRect {
        // 验证容差参数
        guard tolerancePercentage > 0 && tolerancePercentage < 1 else {
            throw Quadrilateral2DError.invalidTolerance("Tolerance percentage must be between 0 and 1")
        }
        
        // 计算四边形的大致尺寸
        let width = max(
            abs(topRight.x - topLeft.x),
            abs(bottomRight.x - bottomLeft.x)
        )
        let height = max(
            abs(bottomLeft.y - topLeft.y),
            abs(bottomRight.y - topRight.y)
        )
        
        // 使用自定义比例计算容差
        let maxDimension = max(width, height)
        let tolerance = maxDimension * tolerancePercentage
        
        // 检查边的平行度
        let topWidth = abs(topRight.x - topLeft.x)
        let bottomWidth = abs(bottomRight.x - bottomLeft.x)
        let leftHeight = abs(bottomLeft.y - topLeft.y)
        let rightHeight = abs(bottomRight.y - topRight.y)
        
        // 计算边长差异与容忍度的比较
        let horizontalDifference = abs(topWidth - bottomWidth)
        let verticalDifference = abs(leftHeight - rightHeight)
        
        let isHorizontalParallel = horizontalDifference <= tolerance
        let isVerticalParallel = verticalDifference <= tolerance
        
        if !isHorizontalParallel || !isVerticalParallel {
            throw Quadrilateral2DError.invalidQuadrilateral("""
                The quadrilateral is not rectangular enough:
                Horizontal difference: \(horizontalDifference)
                Vertical difference: \(verticalDifference)
                Tolerance: \(tolerance) (\(tolerancePercentage * 100)% of max dimension)
                """
            )
        }
        
        // 计算边界框
        let minX = min(topLeft.x, topRight.x, bottomLeft.x, bottomRight.x)
        let maxX = max(topLeft.x, topRight.x, bottomLeft.x, bottomRight.x)
        let minY = min(topLeft.y, topRight.y, bottomLeft.y, bottomRight.y)
        let maxY = max(topLeft.y, topRight.y, bottomLeft.y, bottomRight.y)
        
        return CGRect(x: minX,
                     y: minY,
                     width: maxX - minX,
                     height: maxY - minY)
    }
}
