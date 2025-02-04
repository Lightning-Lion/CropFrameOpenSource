//
//  CropFrameApp.swift
//  CropFrame
//
//  Created by LightningLion on 2025/1/23.
//

import SwiftUI

@main
struct CropFrameApp: App {

    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }
        // 就一个进入沉浸式空间按钮，不用很大的尺寸。
        .defaultSize(Size3D(width: 0.2, height: 0.13, depth: 0), in: .meters)

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    // 不知道哪里内存泄露了，得杀掉App来清理
                    Task { @MainActor in
                        await NotificationManager.shared.sendReturnNotification()
                        exit(0)
                    }
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
     }
}
