//
//  DetectGestureTrigger.swift
//  CropFrame
//
//  Created by LightningLion on 2025/1/24.
//

import SwiftUI
import RealityKit
import os

@MainActor
@Observable
class GestureTriggerDataPack {
    var data:GestureTriggerData? = nil
}

struct GestureTriggerData:Identifiable,Equatable {
    let id = UUID()
    let timestamp = Date.now
}

// 当左右两只手都捏和的时候，触发拍摄
// 避免一直捏着一直触发
/// 检测触发拍照的手势
struct DetectGestureTrigger: ViewModifier {
    @State
    var handPositionDataPack:HandPositionDataPack
    @State
    var gestureTriggerDataPack:GestureTriggerDataPack
    @State
    private var canTrigger = true
    func body(content: Content) -> some View {
        content
            .onChange(of: handPositionDataPack.data, initial: true) { oldValue, newValue in
                guard let leftHandThumbnailPosition = handPositionDataPack.data.leftHandThumbnailPosition,
                      let leftHandIndexFingerPosition = handPositionDataPack.data.leftHandIndexFingerPosition,
                      let rightHandThumbnailPosition = handPositionDataPack.data.rightHandThumbnailPosition,
                      let rightHandIndexFingerPosition = handPositionDataPack.data.rightHandIndexFingerPosition else {
                    os_log("手跟踪丢了")
                    return
                }
                let leftTwoFingerDistant:Float = distance(leftHandThumbnailPosition, leftHandIndexFingerPosition)
                let rightTwoFingerDistant:Float = distance(rightHandThumbnailPosition, rightHandIndexFingerPosition)
                // 左右手都小于2厘米
                if leftTwoFingerDistant < 0.02 && rightTwoFingerDistant < 0.02 {
                    if canTrigger {
                        canTrigger = false // 避免一直捏着，重复触发
                        os_log("手势触发")
                        gestureTriggerDataPack.data = GestureTriggerData()
                    } else {
                        // 手还捏着呢，刚捏上的时候已经触发过了，现在不能触发
                    }
                }
                // 左右手都大于3厘米，算放开
                if leftTwoFingerDistant > 0.03 && rightTwoFingerDistant > 0.03 {
                    canTrigger = true
                }
            }
    }
}
