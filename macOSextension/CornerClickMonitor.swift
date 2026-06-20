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
            if !isEnabled && isHovering {
                isHovering = false
                hoverIndicator.hide()
            }
        }
    }

    private let cornerSize: CGFloat = 30
    private let doubleClickInterval: TimeInterval = 0.3
    private var globalClickMonitor: Any?
    private var globalMoveMonitor: Any?

    private let gestureConfig: AppGestureConfig
    private let flashOverlay = CornerFlashOverlay()
    private let hoverIndicator = CornerHoverIndicator()
    private var isHovering = false

    // 双击检测状态
    private struct PendingClick {
        let screen: NSScreen
        let frontApp: NSRunningApplication
        let bundleID: String
        let timer: Timer
    }
    private var pendingClick: PendingClick?

    init(gestureConfig: AppGestureConfig) {
        self.gestureConfig = gestureConfig
        requestAccessibilityPermission()
        startMonitoring()
    }

    deinit { stopMonitoring() }

    private func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }

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

    private func handleMouseMoved(at location: NSPoint) {
        guard isEnabled, let screen = screen(containing: location) else {
            setHovering(false)
            return
        }
        setHovering(isInTopRightCorner(location, of: screen), on: screen)
    }

    private func setHovering(_ hovering: Bool, on screen: NSScreen? = nil) {
        guard hovering != isHovering else { return }
        isHovering = hovering
        if hovering, let screen {
            hoverIndicator.show(on: screen, size: cornerSize)
        } else {
            hoverIndicator.hide()
        }
    }

    private func handleRightClick(at location: NSPoint) {
        guard isEnabled,
              let screen = screen(containing: location),
              isInTopRightCorner(location, of: screen) else { return }

        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier else { return }

        // 双击检测
        if let pending = pendingClick {
            pending.timer.invalidate()
            pendingClick = nil
            execute(mode: gestureConfig.doubleClickMode(for: bundleID),
                    on: screen, app: frontApp, bundleID: bundleID)
        } else {
            let timer = Timer.scheduledTimer(withTimeInterval: doubleClickInterval, repeats: false) { [weak self] _ in
                guard let self, let pending = self.pendingClick else { return }
                self.pendingClick = nil
                self.execute(mode: self.gestureConfig.singleClickMode(for: pending.bundleID),
                             on: pending.screen, app: pending.frontApp, bundleID: pending.bundleID)
            }
            pendingClick = PendingClick(screen: screen, frontApp: frontApp,
                                        bundleID: bundleID, timer: timer)
        }
    }

    private func execute(mode: AppGestureConfig.Mode, on screen: NSScreen,
                         app: NSRunningApplication, bundleID: String) {
        switch mode {
        case .ignore:
            flashOverlay.flash(on: screen, style: .ignored)
        case .minimize:
            minimizeFocusedWindow(of: app)
            flashOverlay.flash(on: screen, style: .minimized)
            focusNextWindow()
        case .close:
            closeFocusedWindow(of: app)
            flashOverlay.flash(on: screen, style: .closed)
            focusNextWindow()
        }
    }

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    private func isInTopRightCorner(_ point: NSPoint, of screen: NSScreen) -> Bool {
        let frame = screen.frame
        return point.x >= frame.maxX - cornerSize && point.y >= frame.maxY - cornerSize
    }

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
        sendCommandW(to: app.processIdentifier)
    }

    private func minimizeFocusedWindow(of app: NSRunningApplication) {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let window = focusedWindow else { return }

        var minimizeButton: CFTypeRef?
        if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXMinimizeButtonAttribute as CFString, &minimizeButton) == .success,
           let button = minimizeButton {
            AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
            return
        }
        AXUIElementSetAttributeValue(window as! AXUIElement, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }

    private func sendCommandW(to pid: pid_t) {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x0D, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: 0x0D, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.postToPid(pid)
        up?.postToPid(pid)
    }

    private func focusNextWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard let infos = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
                    as? [[String: Any]] else { return }
            let ourPID = ProcessInfo.processInfo.processIdentifier
            for info in infos {
                guard
                    let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                    pid != ourPID,
                    let app = NSRunningApplication(processIdentifier: pid),
                    app.activationPolicy == .regular,
                    let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                    let w = bounds["Width"], w >= 100,
                    let h = bounds["Height"], h >= 50,
                    let layer = info[kCGWindowLayer as String] as? Int,
                    layer == 0,
                    let alpha = info[kCGWindowAlpha as String] as? Double,
                    alpha >= 0.9
                else { continue }
                app.activate(options: .activateIgnoringOtherApps)
                return
            }
        }
    }
}
