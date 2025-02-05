Crop Frame
---

# 实机演示

[https://www.bilibili.com/video/BV1CoP1eKERg](https://www.bilibili.com/video/BV1CoP1eKERg)

---

# 如何运行

## 先决条件：

- Vision Pro真机

    该项目使用手势追踪及主摄像头访问，无法在模拟器里体验功能。

- [Enterprise APIs](https://developer.apple.com/documentation/visionOS/building-spatial-experiences-for-business-apps-with-enterprise-apis#Request-the-entitlements)中的[Main camera access](https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.developer.arkit.main-camera-access.allow)

    该项目使用Vision Pro的本机摄像头来拍照，需要使用该API。

**不满足上述条件的话，可能App不会报错，但什么也不显示**

1. 在项目的根目录里存放你的Enterprise.license文件，没有这个文件将无法正常签名。

1. 在项目的Signing & Capabilities里检查是否已经设置了Main Camera Access能力。

教程视频：[https://www.bilibili.com/video/BV1CZP1evE7s](https://www.bilibili.com/video/BV1CZP1evE7s)

---

# 抛砖引玉

代码有很多地方能优化的，欢迎您讨论。您不用「慢悠悠的发邮件等回复」。

您直接来[找我](https://www.feishu.cn/invitation/page/add_contact/?token=d4br5909-0f29-4e22-adf8-aebc814e7c5d&amp;unique_id=Zz2qoXiCUqhYjKsrHBrGnA==)，给您拉视频会议，马上解决，（免费）。

如果您没有Enterprise APIs，但**想更多了解它用起来是什么样的**，也可以加我，我可以为您提供更多实机演示视频。

---

# 无障碍

本App需要您有左手大拇指、左手食指、右手大拇指、右手食指才能正常交互。

---

# 代码细节

- 当我们表示3D点时，我们总是使用RealityKit坐标系。

- 当我们表示2D点时，我们总是假设平面的左上角为(0,0)，平面的右下角为(宽,高)。

- 该项目未提供多语言支持，仅支持中文。
    
    代码中的注释均为中文，App中的错误说明、UI界面也是中文。

---

# 不完善

我会希望可以在拍摄完照片后，将图片保存到相册。

或者在App里有一个相簿，记录每张图片拍照的位置。

如果您有兴趣为这个演示增加功能，欢迎提交PR或者直接联系我协作开发。

---

# 第三方引用

创意参考
[https://x.com/aidan_wolf/status/1838941247148278146](https://x.com/aidan_wolf/status/1838941247148278146)

拍照快门音频来自剪映，如果您需要商业使用请购买音频版权。

照片拍摄动画参考：[https://developer.apple.com/documentation/swiftui/creating-visual-effects-with-swiftui](https://developer.apple.com/documentation/swiftui/creating-visual-effects-with-swiftui)

ClosureComponent代码参考：[ https://developer.apple.com/documentation/realitykit/tracking-and-visualizing-hand-movement]( https://developer.apple.com/documentation/realitykit/tracking-and-visualizing-hand-movement)

第三方软件包：

[OpenCV-SPM](https://github.com/yeatse/opencv-spm.git) [许可证](https://github.com/yeatse/opencv-spm/blob/main/LICENSE)

[SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON.git) [许可证](https://github.com/SwiftyJSON/SwiftyJSON/blob/master/LICENSE)

App图标由豆包绘制。

---

# 非分发说明

该项目使用了Main Camera Access权利，根据[苹果的要求](https://developer.apple.com/documentation/visionOS/building-spatial-experiences-for-business-apps-with-enterprise-apis#Request-the-entitlements)，该权利属于visionOS的企业API，开发出的App仅允许作为组织专有内部应用程序。

本GitHub存储库仅作为技术分享，不涉及App分发。

---

# 免责声明

本项目仅作为抛砖引玉，不保证代码质量，在生产环境中使用造成的损失需要您自己负责。
