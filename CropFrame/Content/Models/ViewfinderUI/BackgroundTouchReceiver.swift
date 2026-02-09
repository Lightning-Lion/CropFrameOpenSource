import SwiftUI
import RealityKit

@MainActor
@Observable
class ClickableSkyBoxModel {
    private
    var skyBox:Entity? = nil
    // 拍照的捏和手势在用户看任何空白位置（除了UI视图、现有的照片）的时候，都应该触发，为了做到这一点，创建巨大的天空球来接收手势
    func clickableSkyBox() -> ModelEntity {
        
        // 创建模型实体
        // 启用碰撞检测
        // 10米不够，因为用户可以将窗口移动到10米外，这样会阻碍与Window交互。
        // 那就100米
        let clickableSkyBoxEntity = ModelEntity(components: [CollisionComponent(shapes: generateConvexHollowBox(size: 100))])
        
        // 能够接收手势
        clickableSkyBoxEntity.components.set(InputTargetComponent())
        // 因为要捕获拍照手势（双手同时捏和，简单的在RealityView上附加onTapGesture是不够的，那个只能捕获单手点击，双手同时点击它会以为是捏合缩放）
        // 那我们自己捕获捏合手势
        var manipulationComponent = ManipulationComponent()
        // 我只捕获手势，音效我自己加
        manipulationComponent.audioConfiguration = .none
        // 后续使用会检查是否是双手同时捏和
        clickableSkyBoxEntity.components.set(manipulationComponent)
        // 外界使用
//         var token: EventSubscription = content.subscribe(to: ManipulationEvents.WillRelease.self)  { event in
//             if isClickGesture(event:event) {
//                 os_log("触发了点击手势")
//                 vm.soundTrigger = UUID()
//             }
//         }
        self.skyBox = clickableSkyBoxEntity
        return clickableSkyBoxEntity
    }
    
    // 是不是拍照的咔擦手势
    // 捏合的是我才算
    // 双手同时捏合才算
    // 单手捏合不算
    func isClickGesture(event: ManipulationEvents.WillRelease) -> Bool {
        guard event.entity == skyBox else {
            return false
        }
        guard event.inputDeviceSet.count == 2 else {
            return false
        }
        var leftPinch = false
        var rightPinch = false
        for pinch in
                event.inputDeviceSet
            .filter({ $0.kind == .indirectPinch })
        {
            switch pinch.chirality {
            case .left:
                leftPinch = true
            case .right:
                rightPinch = true
            default:
                continue
            }
        }
        guard leftPinch && rightPinch else {
            return false
        }
        return true
    }
    
    /// 生成纯Convex拼接的空心立方体壳（外壁、内壁均可碰撞）
    /// 需要可视化的话可以把它放在固定位置，然后开启Debug Visualizations的Collision Shapes and Axes，移动视角观察
    /// 我们这里只是用作sky box来接收用户向任意空白处的点击事件，但实际上也可以用来作为内部装东西的容器
    /// - Parameters:
    ///   - size: 立方体的边长（width、height、length）
    /// - Returns: 6个方向的Convex形状数组，可直接传入CollisionComponent
    private func generateConvexHollowBox(size: Float) -> [ShapeResource] {
        var sphereShellShapes = [ShapeResource]()
        
        // 6个基础方向（上下左右前后），覆盖完整立方体面
        
        let frontSlice = {
            let baseSlice = generatePlane(size: size)
            let rotationQuat = simd_quatf(angle: .pi/2, axis: SIMD3<Float>(1,0,0))
            let translationVec = SIMD3(0, 0, 1) * size / 2
            let transformedSlice = baseSlice.offsetBy(rotation: rotationQuat,
                                                      translation: translationVec)
            return transformedSlice
        }()
        sphereShellShapes.append(frontSlice)
        
        let backSlice = {
            let baseSlice = generatePlane(size: size)
            let rotationQuat = simd_quatf(angle: -.pi/2, axis: SIMD3<Float>(1,0,0))
            let translationVec = SIMD3(0, 0, -1) * size / 2
            let transformedSlice = baseSlice.offsetBy(rotation: rotationQuat,
                                                      translation: translationVec)
            return transformedSlice
        }()
        sphereShellShapes.append(backSlice)
        
        let topSlice = {
            let baseSlice = generatePlane(size: size)
            let rotationQuat = simd_quatf(angle: .pi, axis: SIMD3<Float>(1,0,0))
            let translationVec = SIMD3(0, 1, 0) * size / 2
            let transformedSlice = baseSlice.offsetBy(rotation: rotationQuat,
                                                      translation: translationVec)
            return transformedSlice
        }()
        sphereShellShapes.append(topSlice)
        
        let bottomSlice = {
            let baseSlice = generatePlane(size: size)
            let translationVec = SIMD3(0, -1, 0) * size / 2
            let transformedSlice = baseSlice.offsetBy(translation: translationVec)
            return transformedSlice
        }()
        sphereShellShapes.append(bottomSlice)
        
        let leftSlice = {
            let baseSlice = generatePlane(size: size)
            let rotationQuat = simd_quatf(angle: .pi/2, axis: SIMD3<Float>(0,0,-1))
            let translationVec = SIMD3(-1, 0, 0) * size / 2
            let transformedSlice = baseSlice.offsetBy(rotation: rotationQuat,
                                                      translation: translationVec)
            return transformedSlice
        }()
        sphereShellShapes.append(leftSlice)
        
        let rightSlice = {
            let baseSlice = generatePlane(size: size)
            let rotationQuat = simd_quatf(angle: -.pi/2, axis: SIMD3<Float>(0,0,-1))
            let translationVec = SIMD3(1, 0, 0) * size / 2
            let transformedSlice = baseSlice.offsetBy(rotation: rotationQuat,
                                                      translation: translationVec)
            return transformedSlice
        }()
        sphereShellShapes.append(rightSlice)
        
        return sphereShellShapes
    }
    /// 生成单个平面
    private func generatePlane(size: Float) -> ShapeResource {
        // 定义X-Z平面（Y=0）的正方形点集，中心点为坐标原点 (0, 0, 0)
        let planePoints: [SIMD3<Float>] = [
            [-size/2, 0, -size/2],  // 左下
            [ size/2, 0, -size/2],  // 右下
            [ size/2, 0,  size/2],  // 右上
            [-size/2, 0,  size/2]   // 左上
        ]
        // 点集转Convex凸包（generateConvex约束，会自动设置厚度）
        return ShapeResource.generateConvex(from: planePoints)
    }
}
