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
    static let backup = resolve("backup")
    static let libraryRefresh = resolve("libraryRefresh")

    // continued processing tasks must start with the real bundle id (which includes the team id when sideloaded)
    static let download: String? = continued("download")
    static let libraryRefreshContinued: String? = continued("libraryRefresh")

    private static var permitted: [String] {
        Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] ?? []
    }

    private static func isPermitted(_ identifier: String) -> Bool {
        let list = permitted
        return list.contains(identifier)
            || list.contains { $0.hasSuffix("*") && identifier.hasPrefix(String($0.dropLast())) }
    }

    private static func continued(_ suffix: String) -> String? {
        let identifier = (Bundle.main.bundleIdentifier ?? "") + "." + suffix
        return isPermitted(identifier) ? identifier : nil
    }

    // The plist is expanded at build time, but a sideloader can change the bundle id afterwards
    // (e.g. appending the team id), so the identifier is matched against what the plist really contains.
    // Wildcard entries are intentionally ignored here, they are only for continued processing tasks.
    private static func resolve(_ suffix: String) -> String {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let candidate = bundleID + "." + suffix
        let list = permitted

        if list.contains(candidate) {
            return candidate
        }
        if let match = list.first(where: { $0.hasSuffix("." + suffix) }) {
            return match
        }
        return candidate
    }
}
