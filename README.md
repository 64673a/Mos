<p align="center">
  <a href="https://mos.caldis.me/">
    <img width="140" src="assets/readme/app-icon.png" alt="Mos app icon">
  </a>
</p>

<h1 align="center">Mos Enhanced</h1>

<p align="center">
  基于 <a href="https://github.com/Caldis/Mos">Caldis/Mos</a> 的个人增强版，保留 Mos 的平滑滚动能力，并加入更完整的鼠标按键与手势工作流。
</p>

<p align="center">
  <img alt="macOS 10.13+" src="https://img.shields.io/badge/macOS-10.13%2B-black?style=flat-square&logo=apple">
  <img alt="Swift 5" src="https://img.shields.io/badge/Swift-5.0-orange?style=flat-square&logo=swift">
  <a href="LICENSE"><img alt="License: CC BY-NC 4.0" src="https://img.shields.io/badge/license-CC%20BY--NC%204.0-lightgrey?style=flat-square"></a>
</p>

## 关于这个分支

这个仓库以原版 Mos 为基础继续开发。原作者 README 已完整保留：

- [原中文 README](README.upstream.zh-CN.md)
- [Original English README](README.enUS.md)
- [Deutsch](README.de.md)
- [日本語](README.ja.md)
- [한국어](README.ko.md)
- [Русский](README.ru.md)
- [Bahasa Indonesia](README.id.md)

原项目由 Caldis 创建和维护。这个分支的目标不是替代原项目，而是在保留平滑滚动核心体验的基础上，探索更适合多键鼠标、Logitech 设备和高频快捷操作的交互方式。

## 我的主要工作

### 鼠标手势

新增一套全局鼠标手势系统，适合侧键或 Logi 手势键：

- 独立的“鼠标手势”设置页，不混入普通按钮绑定列表。
- 固定上、右、下、左四向手势，每个方向可单独绑定 trigger 型动作。
- 按下手势键时在鼠标所在屏幕显示无焦点 overlay，不抢当前 App 焦点。
- 圆环会在靠近屏幕边缘时整体平移，保证完整可见，但不会移动系统鼠标指针。
- 只有移动超过 20pt 后才进入方向选择；回到中心区域或松开时未命中已绑定方向会取消。
- 松开手势键时才触发动作，手势过程中只接管手势键和鼠标移动，其他输入放行。
- 支持 Escape 取消当前手势会话。
- 手势键和普通按钮绑定互斥，保存或录制时会阻止同一个鼠标按钮被重复使用。
- 方向圆环只展示已绑定动作的方向，未绑定方向不参与命中。

### 按钮绑定与动作展示

围绕现有 ButtonBinding 体系做了多项增强：

- 复用现有系统动作、打开目标、Logi 动作和自定义快捷键执行逻辑。
- 对手势方向动作过滤 stateful action，只允许一次性 trigger action。
- 为动作选择器整理图标与展示模型，让普通按钮绑定和手势圆环各自使用合适的展示方式。
- 加强鼠标按钮录制时的冲突检查，避免“已经作为手势入口的按键”继续被添加到普通绑定。

### Logitech / HID 集成

继续沿用原有 Logi 边界，新增手势使用来源：

- 通过 `UsageSource.mouseGesture` 注册手势键使用，避免与普通按钮绑定的 usage 混淆。
- 维持 Logi/HID 细节在 `Mos/Logi` 与 `Mos/Integration` 边界内，不让 UI 层直接处理设备协议。

### 设置界面与视觉体验

- 新增独立鼠标手势偏好设置页。
- 按 macOS 风格调整圆环 overlay：无焦点浮层、轻量中心提示、选中扇形外扩、淡入淡出与高亮动效。
- 设置页预览和运行时 overlay 使用一致的方向、图标和命中语义。
- UI 文案已接入 `Localizable.xcstrings`。

### 测试与质量

新增 `MouseGestureTests`，覆盖：

- 手势启用条件。
- 鼠标触发键限制。
- 方向命中和 20pt 启动阈值。
- 未知方向/未知字段 decode 兼容。
- open target 数据一致性校验。
- stateful action 过滤。

已做过的主要验证：

```bash
git diff --check
swiftc -frontend -parse Mos/InputEvent/MouseGesture.swift Mos/InputEvent/MouseGestureOverlayWindow.swift MosTests/MouseGestureTests.swift
xcodebuild -scheme Debug -configuration Debug -destination 'platform=macOS' build
```

当前本机运行 `MosTests` 时会被测试 bundle 和宿主 App 的 Team ID 签名不一致拦住；这是本地签名环境问题，测试目标可以编译，但无法在当前签名配置下加载运行。

## 构建

```bash
xcodebuild -scheme Debug -configuration Debug -destination 'platform=macOS' build
```

项目仍是 Swift 5 / AppKit / Xcode 工程，最低支持 macOS 10.13。新增 macOS 新 API 时需要保留 availability gate 或 fallback。

## 与原项目的关系

- 原作者：Caldis
- 原项目：[Caldis/Mos](https://github.com/Caldis/Mos)
- 原官网：[mos.caldis.me](https://mos.caldis.me/)
- 原中文 README：[README.upstream.zh-CN.md](README.upstream.zh-CN.md)

请继续尊重原项目的授权和贡献历史。本分支中的增强工作建立在原 Mos 的长期维护基础之上。

## License

Copyright (c) 2017-2026 Caldis. All rights reserved.

Mos 使用 [CC BY-NC 4.0](http://creativecommons.org/licenses/by-nc/4.0/) 授权。请不要将 Mos 上传到 App Store。
