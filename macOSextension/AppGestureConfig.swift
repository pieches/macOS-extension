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

    @Published private(set) var singleClickConfig: [String: Mode] = [:]
    @Published private(set) var doubleClickConfig: [String: Mode] = [:]
    @Published var singleClickDefaultMode: Mode = .minimize
    @Published var doubleClickDefaultMode: Mode = .close
    private let singleClickStorageKey = "TopRightCloser.singleClickConfig"
    private let doubleClickStorageKey = "TopRightCloser.doubleClickConfig"
    private let legacyStorageKey = "TopRightCloser.gestureConfig"
    private let singleClickDefaultKey = "TopRightCloser.singleClickDefaultMode"
    private let doubleClickDefaultKey = "TopRightCloser.doubleClickDefaultMode"
    private let legacyDefaultModeKey = "TopRightCloser.defaultMode"

    init() {
        load()
    }

    /// 单击手势模式（优先 per-app 配置，否则回退到全局单击默认）
    func singleClickMode(for bundleID: String) -> Mode {
        singleClickConfig[bundleID] ?? singleClickDefaultMode
    }

    /// 双击手势模式（优先 per-app 配置，否则回退到全局双击默认）
    func doubleClickMode(for bundleID: String) -> Mode {
        doubleClickConfig[bundleID] ?? doubleClickDefaultMode
    }

    /// 便捷方法：保持旧 API 兼容，等同 singleClickMode
    func mode(for bundleID: String) -> Mode {
        singleClickMode(for: bundleID)
    }

    /// 设置单击手势模式
    func setSingleClickMode(_ mode: Mode, for bundleID: String) {
        singleClickConfig[bundleID] = mode
        save()
    }

    /// 设置双击手势模式
    func setDoubleClickMode(_ mode: Mode, for bundleID: String) {
        doubleClickConfig[bundleID] = mode
        save()
    }

    /// 设置手势模式（兼容旧 API，同时设置单击和双击）
    func setMode(_ mode: Mode, for bundleID: String) {
        setSingleClickMode(mode, for: bundleID)
        setDoubleClickMode(mode, for: bundleID)
    }

    /// 重置单个 App 的单击/双击设定为全局默认
    func reset(for bundleID: String) {
        singleClickConfig.removeValue(forKey: bundleID)
        doubleClickConfig.removeValue(forKey: bundleID)
        save()
    }

    /// 清除所有 per-app 单独配置，使所有 App 使用全局默认
    func setAllApps() {
        singleClickConfig.removeAll()
        doubleClickConfig.removeAll()
        save()
    }

    /// 恢复初始设定：全局默认 + 清除所有 per-app 配置
    func resetAll() {
        singleClickConfig.removeAll()
        doubleClickConfig.removeAll()
        singleClickDefaultMode = .minimize
        doubleClickDefaultMode = .close
        save()
    }

    /// 是否有任何自定义配置
    var hasCustomConfig: Bool {
        !singleClickConfig.isEmpty || !doubleClickConfig.isEmpty
    }

    /// 指定 App 是否有任何自定义手势设定（区别于全局默认）
    func isCustomized(for bundleID: String) -> Bool {
        singleClickConfig[bundleID] != nil || doubleClickConfig[bundleID] != nil
    }

    private func load() {
        // 加载单击默认模式（兼容旧版 key）
        if let raw = UserDefaults.standard.string(forKey: singleClickDefaultKey),
           let mode = Mode(rawValue: raw) {
            singleClickDefaultMode = mode
        } else if let raw = UserDefaults.standard.string(forKey: legacyDefaultModeKey),
                  let mode = Mode(rawValue: raw) {
            // 从旧版 key 迁移
            singleClickDefaultMode = mode
            UserDefaults.standard.removeObject(forKey: legacyDefaultModeKey)
        }

        // 加载双击默认模式
        if let raw = UserDefaults.standard.string(forKey: doubleClickDefaultKey),
           let mode = Mode(rawValue: raw) {
            doubleClickDefaultMode = mode
        }

        // 加载 per-app 单击配置（兼容旧版 key 迁移）
        if let data = UserDefaults.standard.data(forKey: singleClickStorageKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            singleClickConfig = decoded.compactMapValues { Mode(rawValue: $0) }
        } else if let data = UserDefaults.standard.data(forKey: legacyStorageKey),
                  let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            // 从旧版 key 迁移
            singleClickConfig = decoded.compactMapValues { Mode(rawValue: $0) }
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        } else {
            singleClickConfig = [:]
        }

        // 加载 per-app 双击配置
        if let data = UserDefaults.standard.data(forKey: doubleClickStorageKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            doubleClickConfig = decoded.compactMapValues { Mode(rawValue: $0) }
        } else {
            doubleClickConfig = [:]
        }
    }

    private func save() {
        UserDefaults.standard.set(singleClickDefaultMode.rawValue, forKey: singleClickDefaultKey)
        UserDefaults.standard.set(doubleClickDefaultMode.rawValue, forKey: doubleClickDefaultKey)

        if let data = try? JSONEncoder().encode(singleClickConfig.mapValues { $0.rawValue }) {
            UserDefaults.standard.set(data, forKey: singleClickStorageKey)
        }
        if let data = try? JSONEncoder().encode(doubleClickConfig.mapValues { $0.rawValue }) {
            UserDefaults.standard.set(data, forKey: doubleClickStorageKey)
        }
    }
}
