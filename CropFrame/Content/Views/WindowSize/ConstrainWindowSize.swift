import SwiftUI

// 在每次打开时，限制窗口尺寸，随后允许用户自行拉大
struct FreeSpace: ViewModifier {
    @State
    private var launchWindowSizeMeasureDone = false
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
                .frame(width: launchWindowSizeMeasureDone ? nil : 737, height: launchWindowSizeMeasureDone ? nil : 320)
        }
        .onAppear {
            launchWindowSizeMeasureDone = true
        }
    }
}

