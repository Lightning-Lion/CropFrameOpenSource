import CoreGraphics
import RealityKit

// 我就是CGPoint的Float版本
nonisolated
struct FloatPoint:Hashable,Equatable,Sendable {
    var x:Float
    var y:Float
    init(_ x: Float, _ y: Float) {
        self.x = x
        self.y = y
    }
    init(_ xy:(Float,Float)) {
        self.x = xy.0
        self.y = xy.1
    }
    init(_ point:CGPoint) {
        self.x = Float(point.x)
        self.y = Float(point.y)
    }
    init(_ simd2Float:SIMD2<Float>) {
        self.x = simd2Float.x
        self.y = simd2Float.y
    }
    var round:FloatPoint {
        FloatPoint(_DarwinFoundation1.round(x), _DarwinFoundation1.round(y))
    }
    var debugDescription:String {
        "("+x.formatted()+","+y.formatted()+")"
    }
    var asSizeDebugDescription:String {
        x.formatted()+"×"+y.formatted()
    }
    func toTuple() -> (Float,Float) {
        (x,y)
    }
}

// 我就是CGPoint的Double版本
nonisolated
struct Point2D:Hashable,Equatable,Sendable,CustomDebugStringConvertible {
    public
    var x:Double
    public
    var y:Double
    public
    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    public
    var debugDescription: String {
        x.formatted()+", "+y.formatted()
    }
    func toCGPoint() -> CGPoint {
        CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
}

// 我就是模仿Spatial模块的Size3D写的，也是Double版本
nonisolated
struct Size2D:Hashable,Equatable,Sendable,CustomDebugStringConvertible {
    var width:Double
    var height:Double
    init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
    init(simd2Double:SIMD2<Double>) {
        self.width = simd2Double.x
        self.height = simd2Double.y
    }
    var debugDescription: String {
        width.formatted()+" × "+height.formatted()
    }
}

// 对Transform类的扩展
// 因为RealityKit还在使用Float32表示Transform，所以使用我们的扩展
// 目前这样没有精度提升，只是避免后续处理步骤丢失精度，但如果之后RealityKit也改用Double了，就可以获得精度提示
extension Transform {
    var matrixDouble:simd_double4x4 {
        convertToDouble4x4(from:matrix)
    }
    
    private
    func convertToDouble4x4(from floatMatrix: float4x4) -> double4x4 {
        // 遍历矩阵的每一行和每一列，将Float转换为Double
        return double4x4(
            columns: (
                SIMD4<Double>(Double(floatMatrix.columns.0.x), Double(floatMatrix.columns.0.y), Double(floatMatrix.columns.0.z), Double(floatMatrix.columns.0.w)),
                SIMD4<Double>(Double(floatMatrix.columns.1.x), Double(floatMatrix.columns.1.y), Double(floatMatrix.columns.1.z), Double(floatMatrix.columns.1.w)),
                SIMD4<Double>(Double(floatMatrix.columns.2.x), Double(floatMatrix.columns.2.y), Double(floatMatrix.columns.2.z), Double(floatMatrix.columns.2.w)),
                SIMD4<Double>(Double(floatMatrix.columns.3.x), Double(floatMatrix.columns.3.y), Double(floatMatrix.columns.3.z), Double(floatMatrix.columns.3.w))
            )
        )
    }
}

// 对SIMD类的扩展
extension SIMD2<Double> {
    init(_ point2D:Point2D) {
        self.init(x: point2D.x, y: point2D.y)
    }
}

extension SIMD2<Float> {
    init(_ floatPoint:FloatPoint) {
        self.init(x: floatPoint.x, y: floatPoint.y)
    }
    init(_ size2D:Size2D) {
        self.init(x: Float(size2D.width), y: Float(size2D.height))
    }
}

extension SIMD4 {
    /// Extract the X, Y, and Z components of a SIMD4 as a SIMD3.
    var xyz: SIMD3<Scalar> { .init(x, y, z) }
}
