//
//  SettingsView.swift
//  macOSextension
//
//  Created by piednes on 2026-06-17.
//

import SwiftUI
import AppKit
import Combine

/// 统一设置页：为每个 App 选择右上角手势行为
struct SettingsView: View {
    @ObservedObject var gestureConfig: AppGestureConfig
    @State private var runningApps: [NSRunningApplication] = []
    @State private var batchMode: AppGestureConfig.Mode = .minimize

    var body: some View {
        VStack(alignment:.leading, spacing: 0) {
            globalSection
            Divider()
            appListSection
        }
        .frame(width: 540, height: 460)
        .onAppear(perform: refresh)
        .onAppear {
            batchMode = gestureConfig.defaultMode
            DispatchQueue.main.async {
                if NSApp.activationPolicy() != .regular {
                    NSApp.setActivationPolicy(.regular)
                }
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)
                .receive(on: DispatchQueue.main)
        ) { notification in
            guard let window = notification.object as? NSWindow,
                  window.identifier?.rawValue.hasPrefix("com_apple_SwiftUI") == true
            else { return }
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - 全局设定

    private var globalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("全局手势设定", systemImage: "gearshape.2.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("默认行为")
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)

                Picker("", selection: $batchMode) {
                    ForEach(AppGestureConfig.Mode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 264)
            }

            HStack(spacing: 8) {
                Button {
                    gestureConfig.setAllApps(mode: batchMode)
                    refresh()
                } label: {
                    Label("应用到所有 App", systemImage: "checklist")
                }
                .buttonStyle(.bordered)

                Button {
                    gestureConfig.resetAll()
                    batchMode = .minimize
                    refresh()
                } label: {
                    Label("恢复初始设定", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
    }

    // MARK: - App 列表

    private var appListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("App 单独设定", systemImage: "app.badge.fill")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if runningApps.isEmpty {
                emptyAppList
            } else {
                List(runningApps, id: \.processIdentifier) { app in
                    AppRow(app: app, gestureConfig: gestureConfig)
                }
                .listStyle(.plain)
            }
        }
    }

    private var emptyAppList: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "app.dashed")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("没有正在运行的应用")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Helpers

    private func refresh() {
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
}

// MARK: - App Row

private struct AppRow: View {
    let app: NSRunningApplication
    @ObservedObject var gestureConfig: AppGestureConfig

    var body: some View {
        HStack(spacing: 10) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 22, height: 22)
            }
            Text(app.localizedName ?? "未知 App")
                .font(.body)
                .lineLimit(1)

            Spacer()

            Picker("", selection: Binding(
                get: { gestureConfig.mode(for: app.bundleIdentifier ?? "") },
                set: { gestureConfig.setMode($0, for: app.bundleIdentifier ?? "") }
            )) {
                ForEach(AppGestureConfig.Mode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 10)
    }
}
