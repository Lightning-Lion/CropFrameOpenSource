import Spatial
import RealityKit

// 进行坐标系转换、float4x4的构建
// 纯数学计算，可以在任意actor中执行
nonisolated
struct PointAndVectorAndTransformConverter {
    
    /// 将世界空间的点转换为参考坐标系（local）下的点
    static
    func worldToLocal(
        _ pointWorld: Point3D,
        head: Transform
    ) -> Point3D {
        let pointWorldSIMD3Float:SIMD3<Float> = SIMD3<Float>(pointWorld.vector)
        let headFloat4x4:float4x4 = head.matrix
        let pointLocalSIMD3Float:SIMD3<Float> = worldToLocalInner(pointWorldSIMD3Float, head: headFloat4x4)
        let pointLocal:Point3D = Point3D(vector: SIMD3<Double>(pointLocalSIMD3Float))
        return pointLocal
    }
    
    /// 将世界空间的两个点转换为参考坐标系（local）下的点
    private
    static
    func worldToLocalInner(
        _ pointWorld: simd_float3,
        head: simd_float4x4
    ) -> simd_float3 {
        // 1. 计算世界矩阵的逆矩阵（核心：坐标转换的逆变换）
        let inverseHead = simd_inverse(head)
        
        // 2. 辅助函数：世界点转local点
        func convertPoint(_ worldPoint: simd_float3) -> simd_float3 {
            // simd是4维矩阵运算，需将3D点扩展为齐次坐标（w=1）
            let homogeneousPoint = simd_float4(worldPoint.x, worldPoint.y, worldPoint.z, 1.0)
            // 逆矩阵 × 齐次坐标 = local空间齐次坐标
            let localHomogeneous = inverseHead * homogeneousPoint
            // 还原为3D点（取x/y/z分量，w分量归一化，此处因是仿射变换w≈1）
            return simd_float3(localHomogeneous.x, localHomogeneous.y, localHomogeneous.z)
        }
        
        // 3. 转换点并返回
        let pointLocal = convertPoint(pointWorld)
        
        return pointLocal
    }
    
    /// 将世界空间的两个3D点转换为参考坐标系（local）下的点
    /// - Parameters:
    ///   - point1World: 第一个点的世界空间坐标
    ///   - point2World: 第二个点的世界空间坐标
    ///   - head: 参考坐标系的世界矩阵
    /// - Returns: 元组 (local空间点1, local空间点2)
    static
    func worldToLocal(
        _ point1World: Point3D,
        _ point2World: Point3D,
        head: Transform
    ) -> (Point3D, Point3D) {
        let point1Local:Point3D = worldToLocal(point1World, head: head)
        let point2Local:Point3D = worldToLocal(point2World, head: head)
        return (point1Local,point2Local)
    }
    
    static
    func point3DToSIMD3Float(_ point3D:Point3D) -> SIMD3<Float> {
        SIMD3<Float>(point3D.vector)
    }
    
    
    static
    func simd3FloatToPoint3D(_ simd3Float:SIMD3<Float>) -> Point3D {
        Point3D(SIMD3<Double>(simd3Float))
    }
    
    static
    func vector3DToSIMD3Float(_ vector3D:Vector3D) -> SIMD3<Float> {
        SIMD3<Float>(vector3D.vector)
    }
    
    static
    func localToWorld(local:Vector3D,head:Transform) -> Vector3D {
        var removeTranslationHead = head
        removeTranslationHead.translation = .zero
        return Vector3D(vector: SIMD3<Double>(
            Transform(matrix:
                        removeTranslationHead.matrix * Transform(translation: SIMD3<Float>(local.vector)).matrix
                     ).translation
        ))
    }
    
    static
    func makeMatrixSimplifiedL1(xAxis: Vector3D,
                                      yAxis: Vector3D,
                                      zAxis: Vector3D,
                                      center: Point3D) -> Transform {
        return Transform(matrix: makeMatrixSimplified(xAxis: SIMD3<Float>(xAxis.vector), yAxis: SIMD3<Float>(yAxis.vector), zAxis: SIMD3<Float>(zAxis.vector), center: SIMD3<Float>(center.vector)))
    }
    
    private
    static
    func makeMatrixSimplified(xAxis: simd_float3,
                                      yAxis: simd_float3,
                                      zAxis: simd_float3,
                                      center: simd_float3) -> simd_float4x4 {
        
        // 关键点：使用rows初始化器
        simd_float4x4(rows:[
            SIMD4<Float>([xAxis.x, yAxis.x, zAxis.x,center.x]),
            SIMD4<Float>([xAxis.y, yAxis.y, zAxis.y,center.y]),
            SIMD4<Float>([xAxis.z, yAxis.z, zAxis.z,center.z]),
            SIMD4<Float>([0,0,0,1])
        ])
    }
}
