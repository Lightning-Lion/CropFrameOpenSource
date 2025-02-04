import UserNotifications

// 在离开App后，主动向用户发一条通知，方便用户回到App
class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    // 申请通知权限
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("请求通知权限出错: \(error.localizedDescription)")
            }
            completion(granted)
        }
    }
    
    // 发送通知
    func sendReturnNotification() async {
        let content = UNMutableNotificationContent()
             content.title = "返回App"
             
             // 添加返回App的按钮
             let returnAction = UNNotificationAction(
                 identifier: "RETURN_ACTION",
                 title: "返回",
                 options: .foreground
             )
             
             // 创建通知类别
             let category = UNNotificationCategory(
                 identifier: "RETURN_CATEGORY",
                 actions: [returnAction],
                 intentIdentifiers: [],
                 options: []
             )
             
             // 注册通知类别
             UNUserNotificationCenter.current().setNotificationCategories([category])
             
             // 设置通知的类别标识符
             content.categoryIdentifier = "RETURN_CATEGORY"
             
             // 创建触发器，1秒后触发
             let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
             
             let request = UNNotificationRequest(
                 identifier: UUID().uuidString,
                 content: content,
                 trigger: trigger
             )
        
        // 添加通知请求
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("发送通知失败: \(error.localizedDescription)")
        }
    }
}
