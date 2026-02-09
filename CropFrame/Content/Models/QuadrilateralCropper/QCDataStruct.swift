import os
import SwiftUI
import RealityKit

// 表示一个四边形，因为从3D投影来的，很可能不是矩形
// 左上角是原点
struct Quadrilateral2D {
    let topLeft:CGPoint
    let topRight:CGPoint
    let bottomLeft:CGPoint
    let bottomRight:CGPoint
    
}

extension Quadrilateral2D {
    // 创建 CGRect 的便捷初始化方法
    init(rect: CGRect) {
        self.init(
            topLeft: CGPoint(x: rect.minX, y: rect.minY),
            topRight: CGPoint(x: rect.maxX, y: rect.minY),
            bottomLeft: CGPoint(x: rect.minX, y: rect.maxY),
            bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
        )
    }
    
    // 转换到Core Image坐标系（Y轴翻转）
    func toCoreImageCoordinates(in size: CGSize) -> Quadrilateral2DCoreImageCoordinates {
        Quadrilateral2DCoreImageCoordinates(
            topLeft: CGPoint(x: topLeft.x, y: size.height - topLeft.y),
            topRight: CGPoint(x: topRight.x, y: size.height - topRight.y),
            bottomLeft: CGPoint(x: bottomLeft.x, y: size.height - bottomLeft.y),
            bottomRight: CGPoint(x: bottomRight.x, y: size.height - bottomRight.y)
        )
    }
}


// Core Image坐标系
// 左下角是原点
struct Quadrilateral2DCoreImageCoordinates {
    let topLeft:CGPoint
    let topRight:CGPoint
    let bottomLeft:CGPoint
    let bottomRight:CGPoint
}

extension Quadrilateral2DCoreImageCoordinates {
    
    // 检查四边形是否与矩形相交
    func intersects(with rect: CGRect) -> Bool {
        // 检查四边形的任何顶点是否在矩形内
        for point in [topLeft, topRight, bottomLeft, bottomRight] {
            if rect.contains(point) {
                return true
            }
        }
        
        // 检查四边形的边是否与矩形的边相交
        let edges = [
            (topLeft, topRight),      // 上边
            (topRight, bottomRight),  // 右边
            (bottomRight, bottomLeft), // 下边
            (bottomLeft, topLeft)      // 左边
        ]
        
        let rectEdges = [
            (CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY)), // 下边
            (CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY)), // 右边
            (CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)), // 上边
            (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.minY))  // 左边
        ]
        
        for edge in edges {
            for rectEdge in rectEdges {
                if linesIntersect(edge.0, edge.1, rectEdge.0, rectEdge.1) {
                    return true
                }
            }
        }
        
        return false
    }
    
    // 检查四边形是否完全在矩形内
    func isCompletelyInside(_ rect: CGRect) -> Bool {
        for point in [topLeft, topRight, bottomLeft, bottomRight] {
            if !rect.contains(point) {
                return false
            }
        }
        return true
    }
    
    
    // 一个矩阵，包含在整个四边形在内
    func boundingRect() -> CGRect {
        let xValues = [topLeft.x, topRight.x, bottomLeft.x, bottomRight.x]
        let yValues = [topLeft.y, topRight.y, bottomLeft.y, bottomRight.y]
        
        let minX = xValues.min() ?? 0
        let maxX = xValues.max() ?? 0
        let minY = yValues.min() ?? 0
        let maxY = yValues.max() ?? 0
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    // 线段相交检测函数
    private func linesIntersect(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> Bool {
        let denominator = (p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y)
        
        if denominator == 0 {
            return false // 平行线
        }
        
        let ua = ((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x)) / denominator
        let ub = ((p2.x - p1.x) * (p1.y - p3.y) - (p2.y - p1.y) * (p1.x - p3.x)) / denominator
        
        return ua >= 0 && ua <= 1 && ub >= 0 && ub <= 1
    }
    
    // 平移四边形
    func translatedBy(dx: CGFloat, dy: CGFloat) -> Quadrilateral2DCoreImageCoordinates {
        return Quadrilateral2DCoreImageCoordinates(
            topLeft: CGPoint(x: topLeft.x + dx, y: topLeft.y + dy),
            topRight: CGPoint(x: topRight.x + dx, y: topRight.y + dy),
            bottomLeft: CGPoint(x: bottomLeft.x + dx, y: bottomLeft.y + dy),
            bottomRight: CGPoint(x: bottomRight.x + dx, y: bottomRight.y + dy)
        )
    }
}
