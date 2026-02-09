import os
import Combine
import SwiftUI
import RealityKit

// 执行清理操作
@MainActor
let onClosingImmersiveSpace = PassthroughSubject<Void,Never>()

// 侦测RealityView的销毁
// 以发出清理操作
@MainActor
@Observable
class ImmersiveSpaceDestoryDetector {
    private
    var eventSource:Cancellable? = nil
    // 跳过第一个
    private
    var count = 0
    // 只发生一次关闭事件，避免销毁已不存在的
    private
    var triggered = false
    // 实测
    // 1.于ManipulateComponent交互后
    // 2.因为PhotoView呈现照片的时候使用了RealityView
    // 会导致外界RealityView无法正常销毁（也就是ImmersiveSpace会被迫销毁，但其中的RealityView无法正常释放）
    // 通过测试，ImmersiveView销毁时候，会触发SceneEvents.AnchoredStateChanged，我们通过这一点来确认。
    func listenWillClose(baseEntity:Entity) {
        Task { @MainActor in
            do {
                // 要等待baseEntity进入场景，才能设置订阅
                // 这个过程应该很快，用不了几秒，轮询一下好了
                let scene = try await getScene(baseEntity: baseEntity)
                let head = AnchorEntity(.head)
                baseEntity.addChild(head)
                // 设置订阅
                eventSource = scene.subscribe(to: SceneEvents.AnchoredStateChanged.self) { event in
                    // 头的跟踪丢失了，那就是ImmersiveSpace关闭了
                    if event.anchor == head && event.isAnchored == false && head.isAnchored == false && head.isActive == false && head.isEnabledInHierarchy == false {
                        // 关闭这个动作只会触发一次
                        if self.triggered == false {
                            self.triggered = true
                            os_log("ImmersiveSpace要销毁了")
                            onClosingImmersiveSpace.send()
                        }
                    }
                }
                os_log("已成功设置订阅")
            } catch {
                os_log("订阅失败")
                os_log("\(error.localizedDescription)")
            }
        }
    }
    
    // 因为传入的是Entity，而我们需要在RealityViewContent或者RealityKit.Scene上才能.subscribe(
    private
    func getScene(baseEntity:Entity) async throws -> RealityKit.Scene {
        while true {
            if let scene:RealityKit.Scene = baseEntity.scene {
                return scene
                // 循环结束
            } else {
                // 下一帧再试试
                try await Task.sleep(for: .seconds(1/120))
            }
        }
    }
}
