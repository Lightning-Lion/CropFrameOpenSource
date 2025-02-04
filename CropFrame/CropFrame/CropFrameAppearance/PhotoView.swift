//
//  CropBoxView.swift
//  CropFrame
//
//  Created by LightningLion on 2025/1/23.
//

import SwiftUI

@MainActor
@Observable
fileprivate
class PhotoSizeData {
    // 1 meter = 1360 points
    // https://www.createwithswift.com/understanding-real-world-sizes-for-visionos/
    fileprivate
    var viewSize:CGSize
    
    private
    init(viewSize: CGSize) {
        self.viewSize = viewSize
    }
    // 输入以米为单位的尺寸，兼容RealityKit
    static
    func initWithSize(width:Float,height:Float) -> PhotoSizeData {
        let toSwiftUISize = CGSize(width:realityKitSizeToSwiftUISize(realityKitSize: width),height: realityKitSizeToSwiftUISize(realityKitSize: height))
        return .init(viewSize: toSwiftUISize)
    }
    
    private
    static
    func realityKitSizeToSwiftUISize(realityKitSize:Float) -> CGFloat {
        CGFloat(realityKitSize * 1360)
    }
}

struct PhotoView: View {
    var photo:UIImage
    var size:(width:Float,height:Float)
    init(photo: UIImage, size: (width: Float, height: Float)) {
        self.photo = photo
        self.size = size
        self.model = .initWithSize(width: size.width, height: size.height)
    }
    @State
    private var model:PhotoSizeData
    @State
    private var visible = false
    var body: some View {
        ZStack {
            Color.clear // 占位，填满全部可用空间
            if visible {
                Image(uiImage: photo)
                    .resizable()
                
                    .transition(Twirl())
            }
        }
        .frame(width: model.viewSize.width, height: model.viewSize.height, alignment: .center)
        .clipShape(RoundedRectangle(cornerRadius: 50, style: .continuous))
        .task(id: "onLoad", { withAnimation(.smooth, { visible = true }) })
    }
}

fileprivate
struct Twirl: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .blur(radius: phase.isIdentity ? 0 : 10)
            .brightness(phase == .willAppear ? 1 : 0)
    }
}
