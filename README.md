# Teigi

精致、高效的桌面端媒体格式转换工具（Flutter）。

## 功能

- 不限预设格式，支持自定义目标格式（可保存配置为快捷格式）
- 完整队列管理：批量导入、拖拽导入、单文件/批量目标格式指定
- 实时进度、剩余时间估算、多并发、GPU 加速（硬件编码器自动检测）
- 根据目标格式动态展示配置项
- Material You 设计 + 自适应窗口（紧凑 / 中等 / 宽屏三档布局）
- 多语言：简体中文 / 日本語 / English

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.22+（桌面优先） |
| 状态管理 | Riverpod 2.x |
| 路由 | go_router |
| 文件选择 | file_picker / desktop_drop |
| 持久化 | shared_preferences |
| 转换核心 | ffmpeg（系统 PATH 或自定义路径） |

## 环境要求

- Flutter SDK（stable）
- Windows：Visual Studio 2022（含 C++ 桌面工作负载）
- ffmpeg（`where ffmpeg` 可找到，或在设置中指定路径）
- Windows 开发者模式（插件构建需要 symlink 支持）

## 开发

```bash
flutter pub get
flutter test       # 运行全部单元/组件测试
flutter build windows --debug
```

## 项目结构

```
lib/
├── main.dart               # 入口（窗口初始化 + 设置加载）
├── app.dart                # 根组件 + 路由
├── core/
│   ├── ffmpeg/             # 检测、命令行构造、进度解析、硬件加速
│   ├── models/             # 任务/选项/格式/设置模型
│   └── utils/              # 输出文件命名
├── features/
│   ├── home/               # 主界面（自适应布局）
│   ├── queue/              # 队列面板
│   ├── settings/           # 设置页 + 关于页
│   └── format_config/      # 格式选择与转码配置
├── i18n/                   # 本地化（zh / ja / en）
├── providers/              # Riverpod 状态（设置/队列/引擎/ffmpeg/快捷格式）
├── theme/                  # Material 3 主题
└── widgets/                # 通用组件
```

## 测试

```bash
flutter test
```

覆盖：进度解析、队列状态流转、文件命名、应用冒烟测试、设置页导航。


