import SwiftUI
import RealityKit

// 把我这个View变成一个Entity
func buildViewfindEntity(controller: ViewfinderViewController) -> Entity {
    let entity = Entity()
    entity.components.set(ViewAttachmentComponent(rootView: ViewfinderView(controller: controller)))
    return entity
}

@MainActor
@Observable
class ViewfinderViewController {
    var show = false
    // 输入以米为单位的尺寸
    // 当show为false时，宽高没有意义
    var width:Float = 1
    var height:Float = 1
}

/// 定义了取景框的外观
struct ViewfinderView: View {
    @State
    var controller:ViewfinderViewController
    @PhysicalMetric(from:.meters)
    private var pointsPerMeter: CGFloat = 1
    private var width:CGFloat {
        pointsPerMeter * CGFloat(controller.width)
    }
    private var height:CGFloat {
        pointsPerMeter * CGFloat(controller.height)
    }
    var body: some View {
        ZStack(alignment: .center, spacing: 1, content: {
            if (controller.show) {
                RoundedRectangle(cornerRadius: 50, style: .continuous)
                    .fill(Color.clear)
                    .stroke(Color.white, lineWidth: 10)
                    // 塑造略微发光感的边框
                    .shadow(color: Color.white, radius: 10, x: 0, y: 0)
//                    .modifier(DebugOverlay())
                    // 显示/消失动画
                    // 塑造出的感觉是淡入+浮起
                    .transition(.blurReplace.animation(.smooth))
            } else {
                // 手未被跟踪上，在跟踪上的时候会自动把show设为true
            }
        })
        .frame(width: width, height: height, alignment: .center)
        // 衬垫一些，不然shadow和stroke会被clip掉
        .padding(30)
    }
}

struct DebugOverlay: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topLeading, content: {
                // 调试
                Text("正面左上角")
                    .font(.title.bold())
                    .padding([.top,.leading],35)
            })
    }
}
