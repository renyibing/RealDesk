# RealDesk 快速开始指南

本指南将帮助您快速设置和运行 RealDesk 远程控制客户端。

## 前置条件

1. **Flutter SDK**（3.0 或更高版本）
   ```bash
   flutter --version
   ```

2. **对应平台的开发环境**
   - Windows: Visual Studio 2019+
   - macOS: Xcode 12+
   - Linux: GTK 3.0+
   - Android: Android SDK
   - iOS: Xcode + CocoaPods

## 安装步骤

### 1. 获取项目代码

项目位于：`d:/WorkSpaces/momo-project/realdesk`

### 2. 安装依赖

```bash
cd d:/WorkSpaces/momo-project/realdesk
flutter pub get
```

### 3. 生成代码

由于项目使用了 Freezed 进行代码生成，首次运行需要生成代码：

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. 验证环境

```bash
flutter doctor
```

确保没有严重错误（红色 ✗）。

## 运行应用

### Windows

```bash
flutter run -d windows
```

### Android

```bash
# 连接 Android 设备或启动模拟器
flutter devices

# 运行应用
flutter run -d <device-id>
```

### iOS

```bash
# 打开 iOS 模拟器
open -a Simulator

# 运行应用
flutter run -d ios
```

### macOS

```bash
flutter run -d macos
```

### Linux

```bash
flutter run -d linux
```

## 设置远程主机

RealDesk 需要连接到一个运行 WebRTC 的远程主机。您可以使用 remotecontrol 项目作为主机。

### 方案 1：使用 remotecontrol + Ayame

1. **启动 Ayame 信令服务器**

```bash
cd d:/WorkSpaces/momo-project/ayame
./ayame --config config.ini
```

默认端口：3000

2. **启动 remotecontrol 主机**

```bash
cd d:/WorkSpaces/momo-project/remotecontrol
./remotecontrol --use-ayame \
  --ayame-signaling-url ws://localhost:3000/signaling \
  --ayame-room-id test-room \
  --video-codec VP8
```

### 方案 2：使用其他 WebRTC 服务

您也可以使用其他支持 WebRTC 的服务，如：
- Jitsi
- Janus Gateway
- mediasoup
- LiveKit

只需确保信令协议兼容。

## 连接到远程主机

1. **启动 RealDesk 应用**

2. **在连接页面输入：**
   - 信令服务器地址：`ws://localhost:3000/signaling`
   - 房间 ID：`test-room`
   - 访问令牌：留空（如果不需要）

3. **点击"连接"按钮**

4. **等待连接建立**
   - 应该会看到"正在连接..."状态
   - 几秒钟后应该能看到远程桌面画面

## 基本使用

### 控制远程桌面

- **移动鼠标**：在视频画面上移动手指/鼠标
- **点击**：点击视频画面
- **滚动**：使用鼠标滚轮或双指滑动
- **输入文字**：焦点在视频上时直接打字

### 切换鼠标模式

点击底部控制栏的鼠标图标：
- **绝对模式**（默认）：鼠标位置与点击位置一致
- **相对模式**：发送鼠标移动增量

### 查看统计信息

点击底部控制栏的分析图标，查看：
- FPS（帧率）
- 视频/音频码率
- RTT（往返延迟）
- 抖动
- 丢包率

### 断开连接

点击底部控制栏的"断开连接"按钮。

## 常见问题

### 问题 1：无法连接到信令服务器

**症状：** 显示"连接失败"

**解决方案：**
1. 检查信令服务器是否正在运行
2. 检查信令服务器地址是否正确
3. 检查防火墙设置
4. 尝试使用 `127.0.0.1` 代替 `localhost`

### 问题 2：连接成功但无视频

**症状：** 显示"等待流..."但没有画面

**解决方案：**
1. 检查远程主机是否正在发送视频
2. 查看浏览器控制台是否有错误
3. 检查 ICE 连接状态
4. 尝试添加 TURN 服务器

### 问题 3：视频卡顿或延迟高

**症状：** 视频播放不流畅，延迟明显

**解决方案：**
1. 查看统计信息中的 RTT 和丢包率
2. 检查网络带宽
3. 降低视频分辨率或码率
4. 切换到更快的网络
5. 使用 TURN 服务器

### 问题 4：编译错误

**症状：** `*.freezed.dart` 或 `*.g.dart` 文件缺失

**解决方案：**
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 问题 5：输入不响应

**症状：** 鼠标和键盘输入不起作用

**解决方案：**
1. 检查数据通道是否已建立
2. 确认远程主机支持输入控制
3. 查看日志中是否有错误
4. 重新连接

## 调试技巧

### 查看日志

应用使用 `logger` 包记录日志。在调试模式下，日志会显示在控制台。

### 启用详细日志

在 `lib/app/di.dart` 中修改 Logger 配置：

```dart
locator.register<Logger>(Logger(
  level: Level.debug, // 或 Level.trace
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
));
```

### 使用 Flutter DevTools

```bash
flutter pub global activate devtools
flutter pub global run devtools
```

然后在浏览器中打开 DevTools 查看：
- 性能分析
- 网络请求
- 内存使用
- 日志输出

### 远程调试

对于移动设备，使用 ADB 或 Xcode 查看设备日志：

```bash
# Android
adb logcat -s flutter

# iOS (通过 Xcode)
# Window → Devices and Simulators → View Device Logs
```

## 性能测试

### 测量延迟

1. 启用统计信息显示
2. 观察 RTT 值
3. 进行快速鼠标移动测试
4. 观察响应速度

### 网络测试

使用不同的网络环境测试：
- 本地网络（LAN）
- Wi-Fi
- 移动数据（4G/5G）
- 跨区域网络

### 压力测试

1. 连续快速点击和移动
2. 大量键盘输入
3. 长时间运行（30分钟+）
4. 网络中断和恢复

## 构建发布版本

### Android APK

```bash
flutter build apk --release
```

生成的 APK 位于：`build/app/outputs/flutter-apk/app-release.apk`

### iOS IPA

```bash
flutter build ios --release
```

然后在 Xcode 中归档和导出。

### Windows EXE

```bash
flutter build windows --release
```

生成的可执行文件位于：`build/windows/runner/Release/`

### macOS App

```bash
flutter build macos --release
```

生成的应用位于：`build/macos/Build/Products/Release/`

## 下一步

- 阅读 [README.md](README.md) 了解详细功能
- 阅读 [ARCHITECTURE.md](ARCHITECTURE.md) 了解架构设计
- 查看源代码注释了解实现细节
- 贡献代码或报告问题

## 获取帮助

如遇到问题：
1. 查看本指南的常见问题部分
2. 查看项目文档
3. 提交 Issue 描述问题
4. 加入社区讨论

祝您使用愉快！

