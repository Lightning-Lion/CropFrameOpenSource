import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State
    private var vm = ImmersiveViewV1Model()
    @Environment(\.dismissImmersiveSpace)
    private var dismissImmersiveSpace
    var body: some View {
        RealityView { content in
            // 添加世界原点
            content.add(vm.baseEntity)
            // 初始化Viewfinder
            await vm.viewfinderPack.run(baseEntity: vm.baseEntity,
                                  dismissImmersiveSpace: dismissImmersiveSpace)
        }
        .onAppear {
            appModel.immersiveSpaceState = .open
        }
        .onDisappear {
            appModel.immersiveSpaceState = .closed
        }
        .modifier(vm.viewfinderPack.modifier(baseEntity: vm.baseEntity))
    }
    
}

@MainActor
@Observable
class ImmersiveViewV1Model {
    // 世界原点
    let baseEntity = Entity()
    // Viewfinder入点
    let viewfinderPack = ViewfinderPack()
}
