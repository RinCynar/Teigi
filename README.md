# Teigi

跨平台媒体格式转换工具（Flutter + FFmpeg），支持桌面端（Windows / macOS / Linux）与 Android 移动端。

## 功能

- 拖入文件 / 选取文件 / 系统分享（Android Share Sheet），推荐目标格式，批量选择与配置
- 队列：进度、速度、ETA、重试、清除已完成
- 自定义任意目标扩展名，可保存为预设
- Material 3 自适应布局（紧凑手机端 / 中等平板 / 宽屏桌面）
- Android 前台服务后台转码与通知栏实时进度控制（支持直接取消）
- 简体中文 / 日本語 / English

## 环境

- Flutter SDK（stable，Dart SDK ^3.12.2）
- Windows：Visual Studio 2022（C++ 桌面工作负载）+ ffmpeg（PATH，或安装目录 `data/ffmpeg`，或在设置中指定）
- Android：JDK 17、Android SDK（minSdkVersion 24，即 Android 7.0+）

## 开发与构建

### 桌面端

```bash
flutter pub get
flutter test
flutter build windows --release
```

### Android 移动端

```bash
# 调试构建
flutter build apk --debug

# 发布构建（推荐按 ABI 架构拆分产物）
flutter build apk --release --split-per-abi
```

构建产物位于 `build/app/outputs/flutter-apk/`：
- `app-arm64-v8a-release.apk`（主流 64 位手机）
- `app-armeabi-v7a-release.apk`（32 位老旧设备）
- `app-x86_64-release.apk`（模拟器 / 64 位 x86 平板）

## 分发

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_dist.ps1
```

产物在 `build/outputdir/`：

| 文件 | 说明 |
|------|------|
| `windows-{x64,arm64}-release.zip` | 仅应用 |
| `windows-{x64,arm64}-ffmpeg-release.zip` | 应用 + 构建机 PATH 中的 ffmpeg |
| `windows-{x64,arm64}-installer.exe` | Inno Setup 安装包（可不嵌入 / 嵌入 / 安装时下载 ffmpeg） |

只打某一架构：

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_dist.ps1 -Arch x64
```

安装包需要本机安装 [Inno Setup](https://jrsoftware.org/isinfo.php)。

当前 Flutter 的 `flutter build windows` **没有** `--target-platform`，只编译本机 CPU：在 x64 电脑上得到 x64 产物，在 ARM64 电脑上得到 arm64 产物。要出另一套架构，请在对应架构的 Windows（或 CI runner）上再跑一遍脚本。
