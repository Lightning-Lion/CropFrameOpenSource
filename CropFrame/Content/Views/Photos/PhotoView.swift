import Combine
import SwiftUI
import RealityKit

/// 呈现一张已拍摄的照片
struct PhotoView: View {
    @State
    var photo:PhotoModel
    @PhysicalMetric(from:.meters)
    private var pointsPerMeter: CGFloat = 1
    // 姿态在class PhotosModel {的private func displaySkeleton(photoID:UUID) throws {设置
    // 宽高在我这里设置
    private var width:CGFloat {
        pointsPerMeter * CGFloat(photo.pose.size.width)
    }
    private var height:CGFloat {
        pointsPerMeter * CGFloat(photo.pose.size.height)
    }
    @State
    private var show = false
    private let cornerRadius:Double = 50
    @AppStorage("photoPresentationMode") private var eyeMode: PhotoThreeDimensionalEffectMode = .left
    var body: some View {
        ZStack(alignment: .center, spacing: 1, content: {
            if show {
                // 第一层
                switch photo.state {
                case .loading,.error:
                    RoundedRectangle(cornerRadius: CGFloat(cornerRadius), style: .continuous)
                        .fill(Color.clear)
                        .stroke(Color.white, lineWidth: 10)
                        // 加载中骨架屏
                        // 呼吸
                        // 使用.fill(Material.ultraThinMaterial)会让你得到灰色半透明，而不是毛玻璃
                        .glassBackgroundEffect()
                        // 塑造略微发光感的边框
                        .shadow(color: Color.white, radius: 10, x: 0, y: 0)
                        .transition(.blurReplace)
                case .done(let imageStruct):
                    VStack {
                        switch eyeMode {
                        case .left:
                            Image(imageStruct.left, scale: 1, label: Text("照片"))
                                .resizable()
                                // 尺寸由View的.frame决定
                        case .right:
                            Image(imageStruct.right, scale: 1, label: Text("照片"))
                                // 尺寸由View的.frame决定
                                .resizable()
                        case .stereo:
                            // 我没法直接显示一个Image().resizable()，因为我要呈现左右眼，现在我保持好尺寸即可，使用ViewAttachmentComponent挂载我的Entity会设置Transform的
                            RealityView { content in
                                let plane = ModelEntity(mesh: .generatePlane(width: Float(photo.pose.size.width), height: Float(photo.pose.size.height),cornerRadius: Float(cornerRadius/pointsPerMeter)), materials: [
                                    imageStruct.stereo
                                ])
                                content.add(plane)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: CGFloat(cornerRadius), style: .continuous))
                    // 从加载状态切换过来的动画
                    .transition(.blurReplace.animation(.smooth))
                }
                // 如果出错，显示第二层
                switch photo.state {
                case .error(let error):
                    Text(error.localizedDescription)
                        .font(.largeTitle.bold())
                        .minimumScaleFactor(0.01)
                        .scaledToFit()
                        .padding()
                        // 从加载切换过来的动画
                        .transition(.blurReplace.animation(.smooth))
                        // 以避免被glass背板的厚度吞噬
                        .offset(z: -2)
                default:
                    EmptyView()
                }
            } else {
                // 外界会设置尺寸的
                Spacer()
            }
        })
        // 确保触发首次出现的transition动画
        .onAppear {
            withAnimation(.smooth) {
                show = true
            }
        }
        .frame(width: width, height: height, alignment: .center)
        // 衬垫一些，不然shadow和stroke会被clip掉
        .padding(30)
    }
}
