//
//  FirstLaunchSetupView.swift
//  macOSextension
//
//  Created by piednes on 2026-06-17.
//

import SwiftUI
import AppKit

/// 首次启动引导 / 重新引导界面
struct FirstLaunchSetupView: View {
    @ObservedObject var gestureConfig: AppGestureConfig
    @State private var runningApps: [NSRunningApplication] = []

    private let setupKey = "TopRightCloser.hasCompletedFirstLaunchSetup"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.1))
                        .frame(width: 64, height: 64)
                    Image(systemName: "xmark.square.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.blue)
                }
                .padding(.top, 28)

                Text("欢迎使用 Minimize")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("将鼠标移到屏幕右上角，使用右键手势快速操作当前窗口。\n单击与双击可分别设定不同行为。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)

                Text("下方可为每个 App 单独配置单击和双击行为。\n未设定的 App 将使用默认设定（单击最小化，双击关闭）。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 20)

            // App list
            if runningApps.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "app.dashed")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("没有可用的 App")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("请先打开一些应用程序")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(height: 280)
            } else {
                SetupColumnHeader()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)

                Divider()
                    .padding(.horizontal, 16)

                List(runningApps, id: \.processIdentifier) { app in
                    SetupAppRow(app: app, gestureConfig: gestureConfig)
                }
                .listStyle(.plain)
                .frame(height: 280)
            }

            Divider()
                .padding(.horizontal, 20)

            // Footer
            Button(action: completeSetup) {
                Text("开始使用")
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
        .frame(width: 600, height: 560)
        .onAppear(perform: refresh)
        .onDisappear { NSApp.setActivationPolicy(.accessory) }
    }

    private func refresh() {
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func completeSetup() {
        UserDefaults.standard.set(true, forKey: setupKey)
        NSApp.keyWindow?.close()
    }
}

// MARK: - Setup Column Header

private struct SetupColumnHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Color.clear.frame(width: 20, height: 1)
                Text("App")
            }
            .frame(width: 150, alignment: .leading)

            Spacer()

            Text("单击右键")
                .frame(width: 180)

            Text("双击右键")
                .frame(width: 180)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Setup App Row

private struct SetupAppRow: View {
    let app: NSRunningApplication
    @ObservedObject var gestureConfig: AppGestureConfig

    private var bundleID: String { app.bundleIdentifier ?? "" }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                Text(app.localizedName ?? "未知 App")
                    .font(.body)
                    .lineLimit(1)
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
            .frame(width: 180)

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
            .frame(width: 180)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
    }
}
