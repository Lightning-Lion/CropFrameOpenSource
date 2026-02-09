import CoreImage
import CoreVideo

// 把CameraFrameProvider.CameraFrameUpdates给的CVReadOnlyPixelBuffer转换为CGImage
extension CVReadOnlyPixelBuffer {
    func toCGImage(context:CIContext) async throws -> CGImage {
        try await CVPixelBufferToCGImageModel().convertToCGImage(buffer: self,context:context)
    }
}

// 在后台线程执行
actor CVPixelBufferToCGImageModel {
    func convertToCGImage(buffer: CVReadOnlyPixelBuffer,context:CIContext) throws -> CGImage {
        try buffer.withUnsafeBuffer { cvPixelBuffer in
            let ciImage = CIImage(cvPixelBuffer: cvPixelBuffer)
            
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                throw CVPixelBufferToCGImageError.failedToCreateCGImageFromCVPixelBuffer
            }
            return cgImage
        }
    }
    enum CVPixelBufferToCGImageError:Error,LocalizedError {
        case failedToCreateCGImageFromCVPixelBuffer
        var errorDescription: String? {
            switch self {
            case .failedToCreateCGImageFromCVPixelBuffer:
                "failedToCreateCGImageFromCVPixelBuffer"
            }
        }
    }
}
