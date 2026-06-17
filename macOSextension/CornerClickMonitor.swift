//
//  CornerClickMonitor.swift
//  macOSextension
//
//  Created by piednes on 2026-06-14.
//

   import AppKit
   import Combine
   import CoreGraphics

   final class CornerClickMonitor: ObservableObject {
  @Published var isEnabled: Bool = true {
      didSet {
          // 禁用时若正悬停在角落，及时收起提示，避免残留
          if !isEnabled && isHovering {
              isHovering = false
              hoverIndicator.hide()
          }
      }
	   }

    private let cornerSize: CGFloat = 30
    private var globalClickMonitor: Any?
    private var globalMoveMonitor: Any?

    private let whitelist: AppWhitelist
    private let flashOverlay = CornerFlashOverlay()
    private let hoverIndicator = CornerHoverIndicator()
    private var isHovering = false

    init(whitelist: AppWhitelist) {
        self.whitelist = whitelist
        requestAccessibilityPermission()
        startMonitoring()
    }

    deinit { stopMonitoring() }

    // MARK: - 权限

    private func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - 监听

    private func startMonitoring() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseDown) { [weak self] _ in
            self?.handleRightClick(at: NSEvent.mouseLocation)
        }
        globalMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleMouseMoved(at: NSEvent.mouseLocation)
        }
    }

    private func stopMonitoring() {
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        if let globalMoveMonitor { NSEvent.removeMonitor(globalMoveMonitor) }
        globalClickMonitor = nil
        globalMoveMonitor = nil
    }

    // MARK: - 悬停反馈

    private func handleMouseMoved(at location: NSPoint) {
        guard isEnabled, let screen = screen(containing: location) else {
            setHovering(false)
            return
        }
        setHovering(isInTopRightCorner(location, of: screen), on: screen)
    }

    /// 只在"进入/离开"状态切换时才触发显示/隐藏，避免每次mouseMoved都重建窗口
    private func setHovering(_ hovering: Bool, on screen: NSScreen? = nil) {
        guard hovering != isHovering else { return }
        isHovering = hovering
        if hovering, let screen {
            hoverIndicator.show(on: screen, size: cornerSize)
        } else {
            hoverIndicator.hide()
        }
    }

    // MARK: - 事件处理

    private func handleRightClick(at location: NSPoint) {
        guard isEnabled,
              let screen = screen(containing: location),
              isInTopRightCorner(location, of: screen) else { return }

       guard let frontApp = NSWorkspace.shared.frontmostApplication,
             let bundleID = frontApp.bundleIdentifier else { return }

       // 白名单内 → 最小化；非白名单 → 关闭
       if whitelist.contains(bundleID) {
           minimizeFocusedWindow(of: frontApp)
           flashOverlay.flash(on: screen, style: .minimized)
       } else {
           closeFocusedWindow(of: frontApp)
           flashOverlay.flash(on: screen, style: .closed)
       }
       focusNextWindow()
    }

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    private func isInTopRightCorner(_ point: NSPoint, of screen: NSScreen) -> Bool {
        let frame = screen.frame
        return point.x >= frame.maxX - cornerSize && point.y >= frame.maxY - cornerSize
    }

    // MARK: - 关闭窗口

    private func closeFocusedWindow(of app: NSRunningApplication) {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let window = focusedWindow else { return }

        var closeButton: CFTypeRef?
        if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXCloseButtonAttribute as CFString, &closeButton) == .success,
           let button = closeButton {
            AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
            return
        }

       // 兜底：没有标准关闭按钮的App，模拟Cmd+W
       sendCommandW(to: app.processIdentifier)
    }

   // MARK: - 最小化窗口

   /// 将当前最上层窗口最小化（到 Dock）
   private func minimizeFocusedWindow(of app: NSRunningApplication) {
       let axApp = AXUIElementCreateApplication(app.processIdentifier)

       var focusedWindow: CFTypeRef?
       guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
             let window = focusedWindow else { return }

       // 优先：点击最小化按钮
       var minimizeButton: CFTypeRef?
       if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXMinimizeButtonAttribute as CFString, &minimizeButton) == .success,
          let button = minimizeButton {
           AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
           return
       }

       // 兜底：直接设置 kAXMinimizedAttribute
       AXUIElementSetAttributeValue(
           window as! AXUIElement,
           kAXMinimizedAttribute as CFString,
           kCFBooleanTrue
       )
    }

   private func sendCommandW(to pid: pid_t) {
       let source = CGEventSource(stateID: .hidSystemState)
       let down = CGEvent(keyboardEventSource: source, virtualKey: 0x0D, keyDown: true)
       let up = CGEvent(keyboardEventSource: source, virtualKey: 0x0D, keyDown: false)
       down?.flags = .maskCommand
       up?.flags = .maskCommand
       down?.postToPid(pid)
       up?.postToPid(pid)
    }

   // MARK: - 自动聚焦下一个窗口

   /// 窗口关闭后，短暂延迟后找到下一个在 Z-order 中的窗口并激活，
   /// 使用户可以连续关闭窗口而无需手动点击每个窗口。
   private func focusNextWindow() {
       DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
           guard let windowInfos = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
                   as? [[String: Any]] else { return }

           let ourPID = ProcessInfo.processInfo.processIdentifier

           for info in windowInfos {
               guard
                   let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                   pid != ourPID,
                   let app = NSRunningApplication(processIdentifier: pid),
                   app.activationPolicy == .regular,
                   let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                   let width = bounds["Width"], width >= 100,
                   let height = bounds["Height"], height >= 50,
                   let layer = info[kCGWindowLayer as String] as? Int,
                   layer == 0,
                   // alpha >= 0.9 跳过正在淡出的残留窗口
                   let alpha = info[kCGWindowAlpha as String] as? Double,
                   alpha >= 0.9
               else { continue }

               app.activate(options: .activateIgnoringOtherApps)
               return
           }
       }
    }
}
