//
//  AppWhitelist.swift
//  macOSextension
//
//  Created by piednes on 2026-06-14.
//

import Foundation
import Combine

/// 基于Bundle ID的白名单，持久化到UserDefaults
final class AppWhitelist: ObservableObject {
    @Published private(set) var bundleIDs: Set<String>

    private let storageKey = "TopRightCloser.whitelistedBundleIDs"

    init() {
        bundleIDs = Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? [])
    }

    func contains(_ bundleID: String) -> Bool {
        bundleIDs.contains(bundleID)
    }

    func toggle(_ bundleID: String) {
        if bundleIDs.contains(bundleID) {
            bundleIDs.remove(bundleID)
        } else {
            bundleIDs.insert(bundleID)
        }
        UserDefaults.standard.set(Array(bundleIDs), forKey: storageKey)
    }
}
