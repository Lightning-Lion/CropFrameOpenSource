import SwiftUI

// 当相机流失败的时候，在沉浸式环境视野居中显示错误，就像Vision Pro系统的提示弹窗一样
struct CameraWithHeadErrorView: View {
    let error:String
    @Environment(\.dismissImmersiveSpace)
    private var dismissImmersiveSpace
    @State
    private var loading = false
    var body: some View {
        VStack {
            Text(error)
            // 需要重启一遍各个模块，未来可以直接原地重启，现在我们直接退出沉浸式空间重新进入一次
            Button {
                Task { @MainActor in
                    withAnimation(.smooth) {
                        loading = true
                    }
                    await dismissImmersiveSpace()
                    withAnimation(.smooth) {
                        loading = false
                    }
                }
            } label: {
                if loading {
                    ProgressView()
                        .transition(.blurReplace)
                } else {
                    Text("退出沉浸式环境")
                        .transition(.blurReplace)
                }
            }
        }
        .padding()
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 29))
    }
}
