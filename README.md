# Teigi

桌面端媒体格式转换工具（Flutter + FFmpeg）。

## 功能

- 拖入文件，推荐目标格式，批量选择与配置
- 队列：进度、速度、ETA、重试、清除已完成
- 自定义任意目标扩展名，可保存为预设
- Material 3 自适应布局（紧凑 / 中等 / 宽屏）
- 简体中文 / 日本語 / English

## 环境

- Flutter SDK（stable）
- Windows：Visual Studio 2022（C++ 桌面工作负载）
- ffmpeg（PATH，或安装目录 `data/ffmpeg`，或在设置中指定）

## 开发

```bash
flutter pub get
flutter test
flutter build windows --release
```

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
