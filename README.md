# macOS extension

一个常驻在 macOS 菜单栏的小工具：**鼠标移到屏幕右上角，右键单击，即可关闭当前最前App的焦点窗口**——作为系统"热角"功能里缺失的"关闭窗口"动作的补全。

## 功能特性

- **角落手势触发**：鼠标进入屏幕右上角约 30×30 像素区域并右键单击，关闭当前最前App的焦点窗口
- **App白名单**：默认对所有App关闭，仅对用户在设置中勾选过的App生效，避免误触造成数据丢失
- **视觉反馈**：触发瞬间在角落短暂闪烁色块
  - 红色：窗口已关闭
  - 灰色：手势已识别，但当前App不在白名单中，未执行任何操作
- **多屏支持**：基于鼠标当前所在的 `NSScreen` 判断角落区域，每个屏幕独立生效
- **后台运行**：以 `.accessory` 模式运行，不出现在 Dock 和 Cmd+Tab 切换器中，仅保留菜单栏图标


## 系统要求

- macOS 14.0+（菜单栏中的"管理白名单..."使用了 `SettingsLink`，为 macOS 14+ API）
  - 若部署目标为 macOS 13，需将 `SettingsLink` 替换为 `NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)`
- Xcode 15+

## 配置步骤

项目首次构建运行前，必须完成以下配置，否则核心功能无法工作：

### 1. 关闭 App Sandbox

`Signing & Capabilities` → 移除 `App Sandbox` capability（或将其关闭）。

> 全局鼠标监听 + 操控其他App窗口都依赖辅助功能（Accessibility）API，沙盒环境下无法获得相应权限。

### 2. 配置 Info.plist

添加以下键值：

| Key | Value |
|---|---|
| `NSAccessibilityUsageDescription` | 例如："需要辅助功能权限来监听鼠标手势并关闭窗口" |
| `LSUIElement` | `YES`（若代码中已用 `setActivationPolicy(.accessory)`，二者保留一个即可） |

### 3. 授予辅助功能权限

首次运行时，系统会弹出辅助功能授权提示。前往：

```
系统设置 → 隐私与安全性 → 辅助功能
```

勾选本App。**未授权状态下，全局右键事件无法被监听到，功能完全不生效。**

## 使用说明

1. 启动App后，菜单栏出现图标（已启用为实心图标，已暂停为空心图标）
2. 点击图标 → "管理白名单..." 打开设置窗口，勾选需要响应该手势的App
   - **默认白名单为空**，即默认对任何App都不执行关闭操作，需要主动配置
3. 将鼠标移到目标App所在屏幕的右上角，右键单击：
   - 若该App在白名单中：焦点窗口被关闭，角落闪一下红色
   - 若该App不在白名单中：角落闪一下灰色，不执行任何操作
4. 菜单栏中的"启用右上角关闭"开关可临时整体暂停/恢复该功能
5. "退出"彻底关闭本App

## 关闭窗口的实现方式

优先通过 Accessibility API 模拟点击目标窗口的关闭按钮（`kAXCloseButtonAttribute` + `kAXPressAction`），效果等同于用户手动点击红色关闭按钮。若目标App的焦点窗口没有标准关闭按钮，则降级为向该App发送 `Cmd+W` 按键事件。

## 已知限制

- **触发时目标App自身的右键菜单可能仍会弹出。** 当前使用 `NSEvent.addGlobalMonitorForEvents` 监听，该方式只能"观察"事件而无法拦截/消费，因此目标App可能同时响应这次右键点击，弹出自己的上下文菜单。若需要彻底消费该次点击，需改用 `CGEventTap`（同样需要辅助功能权限，但需要额外维护一个 RunLoop）。
- 角落触发区大小（30×30）写死在代码中，未提供UI调节入口。
- 白名单界面仅列出当前正在运行、`activationPolicy == .regular` 的App；未运行的App无法预先加入白名单。

## 后续可优化方向

- [ ] 将 `NSEvent.addGlobalMonitorForEvents` 替换为 `CGEventTap`，彻底拦截角落点击，避免目标App弹出自身菜单
- [ ] 设置中增加触发区大小、是否显示"ignored"灰色反馈等可调选项
- [ ] 首次安装且白名单为空时，引导用户完成配置
