//
//  UpdateCropFrameSizeAndTransform.swift
//  CropFrame
//
//  Created by LightningLion on 2025/1/23.
//

import SwiftUI
import RealityKit
import os
import MixedRealityKit

@MainActor
@Observable
class CropFrameDataPack {
    var data:CropFrameData?
}

/// 根据手的位置，计算取景框的位置和尺寸
struct UpdateCropFrameData: ViewModifier {
    @State
    var handPositionDataPack:HandPositionDataPack
    @State
    var cropFrameDataPack:CropFrameDataPack
    @State
    private var cropBoxPositionController = CropBoxPositionController()
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
                let leftHandTargetPosition:CropBoxPositionController.ThumbIndexMidpoint = (leftHandThumbnailPosition + leftHandIndexFingerPosition) / 2
                let rightHandTargetPosition:CropBoxPositionController.ThumbIndexMidpoint = (rightHandThumbnailPosition + rightHandIndexFingerPosition) / 2
                guard let cameraPosition:SIMD3<Float> = SharedDeviceTransform.shared.deviceTransform?.translation else {
                    os_log("设备位置跟踪丢失")
                    return
                }
                guard let cropFrameData = cropBoxPositionController.getCropBoxData(leftHandTargetPosition: leftHandTargetPosition, rightHandTargetPosition: rightHandTargetPosition, cameraPosition: cameraPosition) else {
                    os_log("框架位置无法计算")
                    return
                }
                // 如果上面的步骤失败了导致return，框架会定在原地
                cropFrameDataPack.data = cropFrameData
            }
    }
}


