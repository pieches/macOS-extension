//
//  macOSextensionApp.swift
//  macOSextension
//
//  Created by piednes on 2026-06-14.
//

import SwiftUI

@main
struct macOSextensionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var whitelist: AppWhitelist
    @StateObject private var monitor: CornerClickMonitor
    fileprivate static var setupWindowDelegate: SetupWindowDelegate?

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        let wl = AppWhitelist()
        _whitelist = StateObject(wrappedValue: wl)
        _monitor = StateObject(wrappedValue: CornerClickMonitor(whitelist: wl))
        // Bridge whitelist reference to the AppDelegate
        AppDelegate.pendingWhitelist = wl

        // 升级兼容：已有白名单数据的老用户直接标记完成，不弹出引导
        let hasCompletedSetup = UserDefaults.standard.bool(
            forKey: "TopRightCloser.hasCompletedFirstLaunchSetup"
        )
        if !hasCompletedSetup && !wl.bundleIDs.isEmpty {
            UserDefaults.standard.set(true, forKey: "TopRightCloser.hasCompletedFirstLaunchSetup")
        }
    }

    var body: some Scene {
        MenuBarExtra(monitor.isEnabled ? "已启用" : "已暂停",
                     systemImage: monitor.isEnabled ? "xmark.square.fill" : "xmark.square") {
          Toggle("启用右上角关闭", isOn: $monitor.isEnabled)
          Divider()
           SettingsLink {
                Text("管理白名单")
            }
            Button("重新引导设置") {
                Self.openSetupWindow(with: whitelist)
            }
            Divider()
            Button("退出") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            WhitelistSettingsView(whitelist: whitelist)
        }
    }

    // MARK: - First Launch Setup Window

    fileprivate static func openSetupWindow(with whitelist: AppWhitelist) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let hostingController = NSHostingController(
            rootView: FirstLaunchSetupView(whitelist: whitelist)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "👋 欢迎使用"
        window.setContentSize(NSSize(width: 400, height: 480))
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false

        let delegate = SetupWindowDelegate()
        setupWindowDelegate = delegate
        window.delegate = delegate

        window.makeKeyAndOrderFront(nil)
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Temporary bridge: set during App.init(), consumed in applicationDidFinishLaunching
    static var pendingWhitelist: AppWhitelist?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let wl = Self.pendingWhitelist else { return }
        // Clear the bridge so it doesn't linger
        Self.pendingWhitelist = nil

        let hasCompletedSetup = UserDefaults.standard.bool(
            forKey: "TopRightCloser.hasCompletedFirstLaunchSetup"
        )
        if !hasCompletedSetup && wl.bundleIDs.isEmpty {
            macOSextensionApp.openSetupWindow(with: wl)
        }
    }
}

// MARK: - Setup Window Delegate

private final class SetupWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
