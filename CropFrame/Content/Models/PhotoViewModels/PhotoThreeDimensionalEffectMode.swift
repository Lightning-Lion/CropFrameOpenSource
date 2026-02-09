import Foundation

// 照片立体感设置
enum PhotoThreeDimensionalEffectMode: String, CaseIterable, Identifiable {
    case left = "left"
    case right = "right"
    case stereo = "stereo"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .left:
            return "左摄像头画面"
        case .right:
            return "右摄像头画面"
        case .stereo:
            return "立体照片"
        }
    }
}
