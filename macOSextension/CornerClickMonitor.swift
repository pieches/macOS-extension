//
//  CornerClickMonitor.swift
//  macOSextension
//
//  Created by piednes on 2026-06-14.
//

import AppKit
import Combine

final class CornerClickMonitor: ObservableObject {
    @Published var isEnabled: Bool = true

    private let cornerSize: CGFloat = 30
    private var globalMonitor: Any?

    private let whitelist: AppWhitelist
    private let flashOverlay = CornerFlashOverlay()

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
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseDown) { [weak self] _ in
            self?.handleRightClick(at: NSEvent.mouseLocation)
        }
    }

    private func stopMonitoring() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        globalMonitor = nil
    }

    // MARK: - 事件处理

    private func handleRightClick(at location: NSPoint) {
        guard isEnabled,
              let screen = screen(containing: location),
              isInTopRightCorner(location, of: screen) else { return }

        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier else { return }

        // 不在白名单：给一个低调的灰色反馈，表示"手势识别到了，但本App不响应"
        guard whitelist.contains(bundleID) else {
            flashOverlay.flash(on: screen, style: .ignored)
            return
        }

        closeFocusedWindow(of: frontApp)
        flashOverlay.flash(on: screen, style: .closed)
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

    private func sendCommandW(to pid: pid_t) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 0x0D, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0x0D, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.postToPid(pid)
        up?.postToPid(pid)
    }
}
