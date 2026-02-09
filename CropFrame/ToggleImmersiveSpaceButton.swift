import Combine
import SwiftUI

@MainActor
let onAuthorizationError = PassthroughSubject<Error,Never>()

@MainActor
let onStartingViewfinderSystemError = PassthroughSubject<Error,Never>()

@MainActor
let onGetIntrinsicsAndExtrinsicsError = PassthroughSubject<Error,Never>()

@MainActor
let onStartCameraError = PassthroughSubject<Error,Never>()

struct ToggleImmersiveSpaceButton: View {

    @Environment(AppModel.self) private var appModel

    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @State private var showError = false
    @State private var error:Error? = nil

    var body: some View {
        Button {
           Task { @MainActor in
               switch appModel.immersiveSpaceState {
                   // 当前是打开，接下来需要关闭
                   case .open:
                       appModel.immersiveSpaceState = .inTransition
                       await dismissImmersiveSpace()
                       // Don't set immersiveSpaceState to .closed because there
                       // are multiple paths to ImmersiveView.onDisappear().
                       // Only set .closed in ImmersiveView.onDisappear().

                   // 当前是关闭，接下来需要打开
                   case .closed:
                       appModel.immersiveSpaceState = .inTransition
                       switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
                           case .opened:
                               // Don't set immersiveSpaceState to .open because there
                               // may be multiple paths to ImmersiveView.onAppear().
                               // Only set .open in ImmersiveView.onAppear().
                               break

                           case .userCancelled, .error:
                               // On error, we need to mark the immersive space
                               // as closed because it failed to open.
                               fallthrough
                           @unknown default:
                               // On unknown response, assume space did not open.
                               appModel.immersiveSpaceState = .closed
                       }
                   // 当前是正在变换
                   case .inTransition:
                       // This case should not ever happen because button is disabled for this case.
                       break
               }
           }
        } label: {
            Text(appModel.immersiveSpaceState == .open ? "Hide Immersive Space" : "Show Immersive Space")
        }
        .disabled(appModel.immersiveSpaceState == .inTransition)
        .animation(.none, value: 0)
        .fontWeight(.semibold)
        // 接收ImmersiveSpace侧发来的错误消息
        .onReceive(onAuthorizationError, perform: { error in
            self.error = error
            self.showError = true
        })
        .onReceive(onStartingViewfinderSystemError, perform: { error in
            self.error = error
            self.showError = true
        })
        .onReceive(onGetIntrinsicsAndExtrinsicsError, perform: { error in
            self.error = error
            self.showError = true
        })
        .onReceive(onStartCameraError, perform: { error in
            self.error = error
            self.showError = true
        })
        // ImmersiveSpace侧发来错误消息后会关闭沉浸式空间，我把错误消息popover呈现出来
        .popover(isPresented: $showError) {
            if let error {
                Text(error.localizedDescription)
                    .padding()
            }
        }
    }
}
