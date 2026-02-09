import SwiftUI

@main
struct CropFrameApp: App {

    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .modifier(FreeSpace())
        }
        // 就一个进入沉浸式空间按钮，不用很大的尺寸。
        .windowResizability(.contentSize)
        // 在ContentView内加背景
        .windowStyle(.plain)

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
        }
     }
}
