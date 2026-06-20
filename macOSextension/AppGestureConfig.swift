//
//  AppGestureConfig.swift
//  macOSextension
//
//  Created by piednes on 2026-06-17.
//

import Foundation
import Combine

/// 每个 App 的手势行为配置，持久化到 UserDefaults
final class AppGestureConfig: ObservableObject {
    enum Mode: String, CaseIterable, Codable {
        case ignore   = "ignore"
        case minimize = "minimize"
        case close    = "close"

        var label: String {
            switch self {
            case .ignore:   return "无操作"
            case .minimize: return "最小化App"
            case .close:    return "关闭App"
            }
        }
    }

    @Published private(set) var config: [String: Mode] = [:]
    @Published var defaultMode: Mode = .minimize
    private let storageKey = "TopRightCloser.gestureConfig"
    private let defaultModeKey = "TopRightCloser.defaultMode"

    init() {
        load()
    }

    /// 获取指定 bundleID 的手势模式（无单独配置时使用 defaultMode）
    func mode(for bundleID: String) -> Mode {
        config[bundleID] ?? defaultMode
    }

    /// 设置手势模式
    func setMode(_ mode: Mode, for bundleID: String) {
        config[bundleID] = mode
        save()
    }

    /// 重置单个 App 为默认
    func reset(for bundleID: String) {
        config.removeValue(forKey: bundleID)
        save()
    }

    /// 将所有 App 统一设置为同一模式（清除所有单独配置）
    func setAllApps(mode: Mode) {
        config.removeAll()
        defaultMode = mode
        save()
    }

    /// 恢复初始设定：默认模式回到最小化，清除所有 App 单独配置
    func resetAll() {
        config.removeAll()
        defaultMode = .minimize
        save()
    }

    /// 是否有任何自定义配置
    var hasCustomConfig: Bool { !config.isEmpty }

    private func load() {
        if let raw = UserDefaults.standard.string(forKey: defaultModeKey),
           let mode = Mode(rawValue: raw) {
            defaultMode = mode
        }

        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { config = [:]; return }
        config = decoded.compactMapValues { Mode(rawValue: $0) }
    }

    private func save() {
        UserDefaults.standard.set(defaultMode.rawValue, forKey: defaultModeKey)

        let dict = config.mapValues { $0.rawValue }
        guard let data = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
