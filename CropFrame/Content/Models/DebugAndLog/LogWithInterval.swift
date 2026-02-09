import os
import SwiftUI

// 我可以在每帧要执行的操作出错时，以节流后的频率发出log日志，而不至于每帧一条日志填满控制台
// 这样虽然没法右键jump to source了，但还是可以搜索对应tag找到源代码
@MainActor
@Observable
class LogWithInterval {
    static let shared = LogWithInterval()
    private init() {
        
    }
    private
    var lastLogTime:[String:Date] = [:] // tag, date
    func logWithInterval(message:String,tag:String) {
        let current = Date.now
        if let lastTime = lastLogTime[tag] {
            let duration:TimeInterval = current.timeIntervalSince(lastTime)
            if duration < 2 {
                // 忽略
            } else {
                lastLogTime[tag] = Date.now
                os_log("[\(tag)]\(message)")
            }
        } else {
            lastLogTime[tag] = Date.now
            os_log("[\(tag)]\(message)")
        }
    }
}

@MainActor
func logWithInterval(_ message:String,tag:String) {
    LogWithInterval.shared.logWithInterval(message: message, tag: tag)
}
