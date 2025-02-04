//
//  CropBoxView.swift
//  CropFrame
//
//  Created by LightningLion on 2025/1/23.
//

import SwiftUI

@MainActor
@Observable
class CropBoxSizeData {
    // 1 meter = 1360 points
    // https://www.createwithswift.com/understanding-real-world-sizes-for-visionos/
    fileprivate
    var viewSize:CGSize = CGSize(width: 1360, height: 1360)
    // 输入以米为单位的尺寸，兼容RealityKit
    func setSize(width:Float,height:Float) {
        let toSwiftUISize = CGSize(width:realityKitSizeToSwiftUISize(realityKitSize: width),height: realityKitSizeToSwiftUISize(realityKitSize: height))
        self.viewSize = toSwiftUISize
    }
    private
    func realityKitSizeToSwiftUISize(realityKitSize:Float) -> CGFloat {
        CGFloat(realityKitSize * 1360)
    }
}

/// 定义了取景框的外观
struct CropBoxView: View {
    @State
    var sizeData:CropBoxSizeData
    var body: some View {
        ZStack(alignment: .center, spacing: 1, content: {
            RoundedRectangle(cornerRadius: 50, style: .continuous)
                .fill(Color.clear)
                .stroke(Color.white, lineWidth: 10)
            // 塑造略微发光感的边框
                .shadow(color: Color.white, radius: 10, x: 0, y: 0)
        })
        .frame(width: sizeData.viewSize.width, height: sizeData.viewSize.height, alignment: .center)
        // 衬垫一些，不然shadow和stroke会被clip掉
        .padding(30)
    }
}

#Preview {
    CropBoxView(sizeData: .init())
}
