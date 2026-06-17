//
//  CornerFlashOverlay.swift
//  macOSextension
//
//  Created by piednes on 2026-06-14.
//

import AppKit

/// 在触发角落短暂显示一个色块，告知用户手势已被识别
final class CornerFlashOverlay {
   enum Style {
       case closed   // 窗口已关闭
       case ignored  // 手势识别到了，但当前App不在白名单中
       case minimized // 窗口已最小化

       var color: NSColor {
           switch self {
           case .closed: return .systemRed
           case .ignored: return .systemGray
           case .minimized: return .systemYellow
           }
       }
       var peakAlpha: CGFloat {
           switch self {
           case .closed: return 0.55
           case .ignored: return 0.3
           case .minimized: return 0.4
           }
       }
   }

    private var panel: NSWindow?

    func flash(on screen: NSScreen, style: Style) {
        // 快速连续触发时，先收起上一个，避免叠加残留
        panel?.orderOut(nil)

        let size: CGFloat = 30
        let frame = NSRect(
            x: screen.frame.maxX - size,
            y: screen.frame.maxY - size,
            width: size, height: size
        )

        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver        // 盖在所有窗口之上
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true   // 不拦截鼠标事件
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.alphaValue = 0

        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = style.color.cgColor
        view.layer?.cornerRadius = 10
        window.contentView = view

        window.orderFrontRegardless()
        panel = window

        // 淡入 -> 停留 -> 淡出
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            window.animator().alphaValue = style.peakAlpha
        }, completionHandler: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.35
                    window.animator().alphaValue = 0
                }, completionHandler: { window.orderOut(nil) })
            }
        })
    }
}
