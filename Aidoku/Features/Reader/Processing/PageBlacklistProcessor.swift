//
//  PageBlacklistProcessor.swift
//  Aidoku
//

import Nuke
import UIKit

struct PageBlacklistProcessor: ImageProcessing {
    var identifier: String {
        "com.github.Aidoku/Aidoku/pageBlacklist"
    }

    func process(_ image: PlatformImage) -> PlatformImage? {
        image
    }

    func process(_ container: ImageContainer, context: ImageProcessingContext) throws -> ImageContainer {
        guard PageBlacklist.shared.matchesNow(container.image) else { return container }
        if let url = context.request.url {
            PageBlacklist.shared.remember(url: url)
        }
        throw PageBlacklistedError()
    }
}
