import os
import Combine
import SwiftUI
import Spatial
import RealityKit

@MainActor
let debugVisualization = PassthroughSubject<(String,Point3D,String),Never>() // displayName, point, tag

@MainActor
let debugRayVisualization = PassthroughSubject<(String,(Point3D,Vector3D),String),Never>() // displayName, ray(start,to), tag

@MainActor
let debugAxisVisualization = PassthroughSubject<(String,Transform,String),Never>() // displayName, axis, tag

// 我可以存放多个可视化点，每一个颜色不一样，点击还能显示tag
@MainActor
@Observable
class DebugVisualizationModel {
    private
    let baseEntity = Entity()
    private
    var entities:[String:Entity] = [:]
    private
    var colors:[UIColor] = [
        .black,
        .darkGray,
        .lightGray,
        .white,
        .gray,
        .red,
        .green,
        .blue,
        .cyan,
        .yellow,
        .magenta,
        .orange,
        .purple,
        .brown
    ]
    func createEntity() -> Entity {
        return baseEntity
    }
    func onReceived(tag:String,displayName:String,point:Point3D) {
        if let exist = entities[tag] {
            exist.setPosition(SIMD3<Float>(point.vector), relativeTo: nil)
        } else {
            guard let randomColor = colors.randomElement() else {
                fatalError("不应该取不到")
            }
            let sphereRadius:Float = 0.05
            let newEntity = ModelEntity(mesh: .generateSphere(radius: sphereRadius), materials: [SimpleMaterial(color: randomColor, isMetallic: false)])
            entities[tag] = newEntity
            // 增加标签
            let displayNameView = Entity()
            displayNameView.components.set(ViewAttachmentComponent(rootView: Text(displayName).padding().background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))))
            displayNameView.position = [0,0.1,0]
            displayNameView.components.set(BillboardComponent())
            newEntity.addChild(displayNameView)
            baseEntity.addChild(newEntity)
            newEntity.setPosition(SIMD3<Float>(point.vector), relativeTo: nil)
        }
    }
    private
    func quaternionFromUpVector(to targetVector: simd_float3) -> simd_quatf? {
        let up = simd_float3(0, 1, 0)
        let target = normalize(targetVector)
        
        // 避免目标向量为零向量
        if length(target) < Float.ulpOfOne {
            return nil
        }
        
        // 如果目标向量与 up 反向，用特殊处理
        let dotValue = dot(up, target)
        if abs(dotValue + 1.0) < 1e-6 {
            // 反向情况，选择任意垂直轴旋转180度
            let axis = normalize(cross(up, simd_float3(1, 0, 0)))
            if length(axis) < 1e-6 {
                // 如果叉积失败，换另一个轴
                return simd_quatf(angle: .pi, axis: normalize(cross(up, simd_float3(0, 0, 1))))
            }
            return simd_quatf(angle: .pi, axis: axis)
        }
        
        // 一般情况
        let cosTheta = dotValue
        let axis = normalize(cross(up, target))
        let angle = acos(cosTheta)
        
        return simd_quatf(angle: angle, axis: axis)
    }
    func onReceived(tag:String,displayName:String,ray:(Point3D,Vector3D)) {
        let (start,to) = ray
        guard let rotation = quaternionFromUpVector(to: SIMD3<Float>(to.vector)) else {
            logWithInterval("不合法的指向", tag: "DebugVisualizationModel.onReceived(tag:String,displayName:String,ray:(Point3D,Vector3D))")
            return
        }
        if let exist = entities[tag] {
            exist.setPosition(SIMD3<Float>(start.vector), relativeTo: nil)
            exist.setOrientation(rotation, relativeTo: nil)
        } else {
            let newEntity = RayVisualizer.make()
            entities[tag] = newEntity
            // 增加标签
            let displayNameView = Entity()
            displayNameView.components.set(ViewAttachmentComponent(rootView: Text(displayName).padding().background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))))
            displayNameView.position = [0,0.1,0]
            displayNameView.components.set(BillboardComponent())
            newEntity.addChild(displayNameView)
            baseEntity.addChild(newEntity)
            // 设置我的布局
            newEntity.setPosition(SIMD3<Float>(start.vector), relativeTo: nil)
            newEntity.setOrientation(rotation, relativeTo: nil)
        }
    }
    func onReceived(tag:String,displayName:String,axis:Transform) {
        if let exist = entities[tag] {
            exist.setTransformMatrix(axis.matrix, relativeTo: nil)
        } else {
            let newEntity = AxisVisualizer.make()
            entities[tag] = newEntity
            // 增加标签
            let displayNameView = Entity()
            displayNameView.components.set(ViewAttachmentComponent(rootView: Text(displayName).padding().background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))))
            displayNameView.position = [0,0.1,0]
            displayNameView.components.set(BillboardComponent())
            newEntity.addChild(displayNameView)
            baseEntity.addChild(newEntity)
            newEntity.setTransformMatrix(axis.matrix, relativeTo: nil)
        }
    }
    @MainActor
    struct RayVisualizer {
        // 创建了一个中心点在0，垂直的线
        static func make() -> Entity {
            /// The entity that contains four different meshes.
            let outer = Entity()
            /// The box for the y-axis.
            let width: Float = 0.0025
            let length: Float = 0.1
            let radius: Float = 0.005
            let rayMesh = MeshResource.generateBox(size: [width, length, width])

            /// The unlit green material.
            let rayMaterial = UnlitMaterial(color: .systemGreen)

            /// The entity with the box and material that represents the y-axis.
            let inner = ModelEntity(mesh: rayMesh, materials: [rayMaterial])

            inner.position = [0, 0.5 * length, 0]
            
            /// The sphere for the origin point.
            let originMesh = MeshResource.generateSphere(radius: radius)

            /// The unlit white material.
            let originMaterial = UnlitMaterial(color: .white)

            /// The entity with the sphere and white material that represents the origin point.
            let originEntity = ModelEntity(mesh: originMesh, materials: [originMaterial])

            // Add the origin point to the parent entity.
            outer.addChild(originEntity)
            
            outer.addChild(inner)

            return outer
        }
    }
    /// The structure that creates a visible representation of the x, y, and z axes.
    @MainActor
    struct AxisVisualizer {
        /// Builds the axis visualizer entity.
        static func make() -> Entity {
            /// The entity that contains four different meshes.
            let entity = Entity()

            /// The width, length, and radius values that each mesh uses.
            let width: Float = 0.0025
            let length: Float = 0.1
            let radius: Float = 0.005

            /// The box for the x-axis.
            let xAxisMesh = MeshResource.generateBox(size: [length, width, width])

            /// The unlit red material.
            let xAxisMaterial = UnlitMaterial(color: .systemRed)

            /// The entity with the box and material that represents the x-axis.
            let xAxisEntity = ModelEntity(mesh: xAxisMesh, materials: [xAxisMaterial])

            // Set the postion of the x-axis entity in 3D space.
            xAxisEntity.position = [0.5 * length, 0, 0]

            // Add the x-axis to the parent entity.
            entity.addChild(xAxisEntity)

            /// The box for the y-axis.
            let yAxisMesh = MeshResource.generateBox(size: [width, length, width])

            /// The unlit green material.
            let yAxisMaterial = UnlitMaterial(color: .systemGreen)

            /// The entity with the box and material that represents the y-axis.
            let yAxisEntity = ModelEntity(mesh: yAxisMesh, materials: [yAxisMaterial])

            // Set the position of the y-axis entity in 3D space.
            yAxisEntity.position = [0, 0.5 * length, 0]

            // Add the y-axis to the parent entity.
            entity.addChild(yAxisEntity)

            /// The box for the z-axis.
            let zAxisMesh = MeshResource.generateBox(size: [width, width, length])

            /// The unlit blue material.
            let zAxisMaterial = UnlitMaterial(color: .systemBlue)

            /// The entity with the box and material that represents the z-axis.
            let zAxisEntity = ModelEntity(mesh: zAxisMesh, materials: [zAxisMaterial])

            // Set the position of the z-axis entity in 3D space.
            zAxisEntity.position = [0, 0, 0.5 * length]

            // Add the z-axis to the main entity.
            entity.addChild(zAxisEntity)

            /// The sphere for the origin point.
            let originMesh = MeshResource.generateSphere(radius: radius)

            /// The unlit white material.
            let originMaterial = UnlitMaterial(color: .white)

            /// The entity with the sphere and white material that represents the origin point.
            let originEntity = ModelEntity(mesh: originMesh, materials: [originMaterial])

            // Add the origin point to the parent entity.
            entity.addChild(originEntity)

            return entity
        }
    }

}

struct EnableDebugVis: ViewModifier {
    @State
    var baseEntity:Entity
    @State
    private var debugVisMod = DebugVisualizationModel()
    func body(content: Content) -> some View {
        content
            .onAppear {
                os_log("onAppear")
                baseEntity.addChild(debugVisMod.createEntity())
            }
            .onReceive(debugVisualization) { (displayName,point,tag) in
                debugVisMod.onReceived(tag:tag,displayName:displayName, point: point)
            }
            .onReceive(debugAxisVisualization) { (displayName,axis,tag) in
                debugVisMod.onReceived(tag: tag, displayName: displayName, axis: axis)
            }
            .onReceive(debugRayVisualization) { (displayName,ray,tag) in
                debugVisMod.onReceived(tag: tag, displayName: displayName, ray: ray)
            }
    }
}

// 用法：
// .modifier(EnableDebugVis(baseEntity: vm.baseEntity))
// debugVisualization.send(("看向点",Point3D(vector: SIMD3<Double>(lookAtPointWrold)),"lookAtPointWrold"))
