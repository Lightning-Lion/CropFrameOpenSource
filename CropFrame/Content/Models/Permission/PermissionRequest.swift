import ARKit
// 我只能在ImmersiveSpace里调用，在未开启ImmersiveSpace时requestAuthorization，总是会说This app failed to request an authorization.
@MainActor
func requestAuthorization() async throws {
    // 在沉浸式看剧下自动获得WorldTracking，无需显式授权。
    let result = await ARKitSession().requestAuthorization(for: [.handTracking,.cameraAccess])
    // 需要全部允许
    guard result.allSatisfy({ item in
        let status:ARKitSession.AuthorizationStatus = item.value
        switch status {
        case .notDetermined:
            return false
        case .allowed:
            return true
        case .denied:
            return false
        @unknown default:
            fatalError("未适配新系统")
        }
    }) else {
        throw RequestAuthorizationError()
    }
}

struct RequestAuthorizationError:LocalizedError {
    var errorDescription: String? {
        "未满足需要的权限：手部结构与动作、主相机"
    }
}
