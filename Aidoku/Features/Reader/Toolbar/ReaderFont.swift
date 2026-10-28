//
//  ReaderFont.swift
//  Aidoku
//

import CoreText
import UIKit

enum ReaderFont {
    private static let registerFonts: Void = {
        for ext in ["otf", "ttf"] {
            let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? []
            for url in urls where url.lastPathComponent.lowercased().contains("publico") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }()

    static func publico(size: CGFloat) -> UIFont {
        _ = registerFonts

        let families = UIFont.familyNames.filter { $0.lowercased().hasPrefix("publico") }
        let names = families.flatMap { UIFont.fontNames(forFamilyName: $0) }
        let preferred = names.first { $0.lowercased().contains("roman") || $0.lowercased().contains("regular") }
            ?? names.first { !$0.lowercased().contains("italic") }
            ?? names.first
        if let preferred, let font = UIFont(name: preferred, size: size) {
            return font
        }

        let base = UIFont.systemFont(ofSize: size)
        if let descriptor = base.fontDescriptor.withDesign(.serif) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
    }
}
