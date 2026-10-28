//
//  BGTaskScheduler.swift
//  Aidoku
//
//  Created by skitty on 8/16/26.
//

import BackgroundTasks

extension BGTaskScheduler {
    func submit(request: BGTaskRequest) async throws {
       if #available(iOS 27.0, *) {
           try await submitTaskRequest(request)
       } else {
            try submit(request)
       }
    }
}

enum BackgroundTaskIdentifier {
    static let download = resolve("download")
    static let backup = resolve("backup")
    static let libraryRefresh = resolve("libraryRefresh")

    private static var permitted: [String] {
        Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] ?? []
    }

    // The plist is expanded at build time, but a sideloader can change the bundle id afterwards
    // (e.g. appending the team id), so the identifier is matched against what the plist really contains.
    private static func resolve(_ suffix: String) -> String {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let candidate = bundleID + "." + suffix
        let list = permitted

        if list.contains(candidate) {
            return candidate
        }
        if list.contains(where: { $0.hasSuffix("*") && candidate.hasPrefix(String($0.dropLast())) }) {
            return candidate
        }
        if let match = list.first(where: { $0.hasSuffix("." + suffix) }) {
            return match
        }
        return candidate
    }
}
