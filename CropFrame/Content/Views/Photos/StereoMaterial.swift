import os
import SwiftUI
import RealityKit
// 这是Reality Composer Pro里的Bundle
import RealityKitContent

@MainActor
@Observable
class StereoMaterialModel {
    func createMaterial(leftEye:CGImage,rightEye:CGImage) async throws -> ShaderGraphMaterial {
        // 这个from看新建的.usda文件名
        // 这个in看Reality Composer Pro里左上角的场景内元素列表的结构
        os_log("开始加载")
        var matX = try await ShaderGraphMaterial(named: "/Root/Material",
                                                 from: "Materials/StereoMaterial.usda",
                                                 in: realityKitContentBundle)
        os_log("ShaderGraphMaterial加载成功")
        let imgLeft = leftEye
        let left =  try await cgImageToMaterial(imgLeft)
        try matX.setParameter(name: "LeftEye", value: .textureResource(left))
        
        let imgRight = rightEye
        let right =  try await cgImageToMaterial(imgRight)
        try matX.setParameter(name: "RightEye", value: .textureResource(right))
        
        
        return matX
    }
    // CGImage转TextureResource
    private
    func cgImageToMaterial(_ cgImage:CGImage) async throws -> TextureResource {
        let texture = try await TextureResource(image: cgImage, options: TextureResource.CreateOptions.init(semantic: nil))
        return texture
    }
    struct UIImageToMaterialError:LocalizedError {
        var errorDescription: String? {
            "UIImage无法转换为CGImage"
        }
    }
}
