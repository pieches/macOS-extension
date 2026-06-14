//
//  macOSextensionApp.swift
//  macOSextension
//
//  Created by piednes on 2026-06-14.
//

import SwiftUI

@main
struct macOSextensionApp: App {
    @StateObject private var whitelist: AppWhitelist
    @StateObject private var monitor: CornerClickMonitor

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        let wl = AppWhitelist()
        _whitelist = StateObject(wrappedValue: wl)
        _monitor = StateObject(wrappedValue: CornerClickMonitor(whitelist: wl))
    }

    var body: some Scene {
        MenuBarExtra(monitor.isEnabled ? "已启用" : "已暂停",
                     systemImage: monitor.isEnabled ? "xmark.square.fill" : "xmark.square") {
            Toggle("启用右上角关闭", isOn: $monitor.isEnabled)
            Divider()
            SettingsLink {
                Text("管理白名单...")
            }
            .simultaneousGesture(TapGesture().onEnded {
                NSApp.activate(ignoringOtherApps: true)
            })
            Divider()
            Button("退出") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            WhitelistSettingsView(whitelist: whitelist)
        }
    }
}
