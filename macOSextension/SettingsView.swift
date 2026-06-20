//
//  SettingsView.swift
//  macOSextension
//
//  Created by piednes on 2026-06-17.
//

import SwiftUI
import AppKit
import Combine

/// 统一设置页：为每个 App 分别设定右上角手势行为
struct SettingsView: View {
    @ObservedObject var gestureConfig: AppGestureConfig
    @State private var runningApps: [NSRunningApplication] = []
    @State private var batchSingleMode: AppGestureConfig.Mode = .minimize
    @State private var batchDoubleMode: AppGestureConfig.Mode = .close

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            globalSection
            Divider()
                .padding(.horizontal)
            appListSection
        }
        .frame(width: 620, height: 640)
        .onAppear(perform: refresh)
        .onAppear {
            batchSingleMode = gestureConfig.singleClickDefaultMode
            batchDoubleMode = gestureConfig.doubleClickDefaultMode
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "gearshape.2.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text("全局手势设定")
                    .font(.headline)
            }

            Text("移动到屏幕右上角，右键单击或双击即可触发操作。\n以下设定对所有未单独配置的 App 生效。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            settingRow(icon: "1.circle.fill", color: .blue,
                       label: "单击右键", selection: $batchSingleMode)

            settingRow(icon: "2.circle.fill", color: .purple,
                       label: "双击右键", selection: $batchDoubleMode)

            Divider()

            HStack(spacing: 8) {
                Button {
                    gestureConfig.singleClickDefaultMode = batchSingleMode
                    gestureConfig.doubleClickDefaultMode = batchDoubleMode
                    gestureConfig.setAllApps()
                    refresh()
                } label: {
                    Label("应用并清除单独设定", systemImage: "checklist")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    gestureConfig.resetAll()
                    batchSingleMode = .minimize
                    batchDoubleMode = .close
                    refresh()
                } label: {
                    Label("恢复出厂设定", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(12)
    }

    private func settingRow(icon: String, color: Color, label: String,
                            selection: Binding<AppGestureConfig.Mode>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(color)
                .frame(width: 18)
            Text(label)
                .font(.callout)
                .frame(width: 36, alignment: .leading)

            Picker("", selection: selection) {
                ForEach(AppGestureConfig.Mode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                        .font(.callout)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
        }
    }

    // MARK: - App 列表

    private var appListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("App 单独设定", systemImage: "app.badge.fill")
                    .font(.headline)
                Spacer()
                if !runningApps.isEmpty {
                    Text("\(runningApps.count) 个 App")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 6)

            if runningApps.isEmpty {
                emptyAppList
            } else {
                columnHeader
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(runningApps.enumerated()), id: \.element.processIdentifier) { index, app in
                            AppRow(app: app, gestureConfig: gestureConfig)
                                .background(index.isMultiple(of: 2)
                                    ? Color.primary.opacity(0.04)
                                    : Color.clear)
                        }
                    }
                }
            }
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Color.clear.frame(width: 20, height: 1)
                Text("App")
            }
            .frame(width: 150, alignment: .leading)

            Spacer()

            Text("单击右键")
                .frame(width: 190)

            Text("双击右键")
                .frame(width: 190)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var emptyAppList: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "app.dashed")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("没有正在运行的应用")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("打开一些 App 后即可在此单独设定。")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 170)
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
    @State private var isHovering = false

    private var bundleID: String { app.bundleIdentifier ?? "" }
    private var isCustomized: Bool { gestureConfig.isCustomized(for: bundleID) }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                Text(app.localizedName ?? "未知 App")
                    .font(.body)
                    .lineLimit(1)

                if isCustomized {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(.blue)
                }
            }
            .frame(width: 150, alignment: .leading)

            Spacer()

            Picker("", selection: Binding(
                get: { gestureConfig.singleClickMode(for: bundleID) },
                set: { gestureConfig.setSingleClickMode($0, for: bundleID) }
            )) {
                ForEach(AppGestureConfig.Mode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(width: 190)

            Picker("", selection: Binding(
                get: { gestureConfig.doubleClickMode(for: bundleID) },
                set: { gestureConfig.setDoubleClickMode($0, for: bundleID) }
            )) {
                ForEach(AppGestureConfig.Mode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(width: 190)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 16)
        .background(isHovering ? Color.primary.opacity(0.06) : Color.clear)
        .onHover { isHovering = $0 }
        .contextMenu {
            if isCustomized {
                Button {
                    gestureConfig.reset(for: bundleID)
                } label: {
                    Label("恢复默认设定", systemImage: "arrow.counterclockwise")
                }
            }
            Button {
                gestureConfig.reset(for: bundleID)
            } label: {
                Label("清除此 App 设定", systemImage: "eraser")
            }
            .disabled(!isCustomized)
        }
    }
}
