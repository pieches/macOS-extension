//
//  CornerHoverIndicator.swift
//  macOSextension
//
//  Created by piednes on 2026-06-14.
//

import AppKit

/// 鼠标进入右上角触发区时显示淡色高亮，离开时淡出
final class CornerHoverIndicator {
    private var panel: NSWindow?

    /// 显示高亮。size传入与点击判定区一致的尺寸，让用户看到的范围=实际生效范围
    func show(on screen: NSScreen, size: CGFloat) {
        if panel == nil {
            let frame = NSRect(
                x: screen.frame.maxX - size,
                y: screen.frame.maxY - size,
                width: size, height: size
            )
            let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.alphaValue = 0

            let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.22).cgColor
            view.layer?.cornerRadius = 10
            window.contentView = view

            panel = window
        }

        panel?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            panel?.animator().alphaValue = 1
        }
    }

    /// 隐藏高亮（淡出后移除窗口）
    func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            if self?.panel === panel { self?.panel = nil }
        })
    }
}
