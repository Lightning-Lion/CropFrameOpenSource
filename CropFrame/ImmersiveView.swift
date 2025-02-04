//
//  ImmersiveView.swift
//  CropFrame
//
//  Created by LightningLion on 2025/1/23.
//

import SwiftUI
import RealityKit
import RealityKitContent
import MixedRealityKit
import os

struct ImmersiveView: View {
    @State
    private var vm = ImmersiveViewModel()
    var body: some View {
        CameraPassthroughMR(attachments:$vm.attachments, liveFrame: $vm.liveFrame) { content in
            vm.realityViewContentPack = .init(realityViewContent: content)
            // 添加取景框实体
            vm.appendCropBoxView(realityViewContent: content)
        }
        // 获得手指位置
        .modifier(HandTrackingView(handPosition: vm.handPositionDataPack, pack: $vm.realityViewContentPack))
        // 根据手指位置，计算出取景框
        .modifier(UpdateCropFrameData(handPositionDataPack: vm.handPositionDataPack, cropFrameDataPack: vm.cropFrameDataPack))
        // 更新取景框实体
        .onChange(of: vm.cropFrameDataPack.data, initial: true) { oldValue, newValue in
            vm.updateCropBoxEntity()
        }
        // 检测拍照手势
        .modifier(DetectGestureTrigger(handPositionDataPack: vm.handPositionDataPack, gestureTriggerDataPack: vm.gestureTriggerDataPack))
        // 拍照，添加照片到场景里
        .onChange(of: vm.gestureTriggerDataPack.data, initial: true) { oldValue, newValue in
            vm.tryToTakePhoto()
        }
        // 音效
        .modifier(ShutterSoundSupport(shutterSoundMod: vm.shutterSoundMod, shutterTrigger: vm.gestureTriggerDataPack.data))
    }
}


@MainActor
@Observable
fileprivate
class ImmersiveViewModel {
    var liveFrame: FrameData?
    let cropBoxSizeData:CropBoxSizeData = CropBoxSizeData()
    var attachments:[AttachmentComponent] = []
    let handPositionDataPack = HandPositionDataPack()
    var realityViewContentPack:RealityViewContentPack?
    let cropFrameDataPack = CropFrameDataPack()
    let gestureTriggerDataPack = GestureTriggerDataPack()
    let shutterSoundMod = ShutterSound()
       // 这个实体是Crop Frame框框
    private let entity = Entity()
    private let photosModel = PhotosModel()
    
    func appendCropBoxView(realityViewContent:RealityViewContent) {
        // 这个attachmentView不论尺寸如何变化，刚好是中心点位于实体原点。
        entity.components.set(attachments.queryNewItem(attachmentView: AnyView(CropBoxView(sizeData: cropBoxSizeData))))
        entity.setPosition([0,1.5,-1], relativeTo: nil) // 初始位置。如果没有手势跟踪，会出现在这里。
        realityViewContent.add(entity)
    }
    func updateCropBoxEntity() {
        guard let data = cropFrameDataPack.data else {
            os_log("框架位置和尺寸还没有准备好")
            return
        }
        entity.setTransformMatrix(data.transform.matrix, relativeTo: nil)
        cropBoxSizeData.setSize(width: data.size.0, height: data.size.1)
    }
    
    func tryToTakePhoto() {
        guard let gestureData = gestureTriggerDataPack.data else {
            os_log("无触发手势")
            return
        }
        guard let cropFrameData = cropFrameDataPack.data else {
            os_log("框架位置和尺寸还没有准备好")
            return
        }
        guard let photo = liveFrame else {
            os_log("相机视频流帧还没有准备好")
            return
        }
        guard let realityViewContent = realityViewContentPack?.realityViewContent else {
            os_log("realityViewContent还没有准备好")
            return
        }
        photosModel.addPhoto(gestureData: gestureData, cropFrameData: cropFrameData, photo: photo, realityViewContent: realityViewContent, attachments: &attachments,mrData:photo.mrData)
    }
    

}

@MainActor
@Observable
class PhotosModel {
    private var photoEntities = [Entity]()
    fileprivate
    func addPhoto(gestureData:GestureTriggerData,cropFrameData:CropFrameData,photo:FrameData,realityViewContent:RealityViewContent,attachments:inout [AttachmentComponent],mrData:MRData) {
        // 把图片裁剪出来，从完整的相机画面的得到手势区域的图片。
        // 相机画面是左眼，因此最终只有左眼看起来是对齐的。
        guard let croppedImage:CGImage = ImageCropper.cropImage(cropFrameData: cropFrameData, photo: photo, photoViewPhysicalSize: cropFrameData.size, mrData: mrData) else {
            os_log("从Passthrough裁剪图片失败")
            return
        }
        
        let newPhotoEntity = Entity()
        
        // 这个attachmentView不论尺寸如何变化，刚好是中心点位于实体原点。
        newPhotoEntity.components.set(attachments.queryNewItem(attachmentView: AnyView(PhotoView(photo: UIImage(cgImage: croppedImage), size: cropFrameData.size))))
        
        // 直接设置好位置，图片的位置一生成就保持不动了。
        newPhotoEntity.setTransformMatrix(cropFrameData.transform.matrix, relativeTo: nil)
        
        realityViewContent.add(newPhotoEntity)
        self.photoEntities.append(newPhotoEntity)
        os_log("添加了一张照片")
    }
    
   
    
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
