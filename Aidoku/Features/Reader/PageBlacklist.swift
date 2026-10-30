//
//  PageBlacklist.swift
//  Aidoku
//

import UIKit

final class PageBlacklist: @unchecked Sendable {
    static let shared = PageBlacklist()

    private struct Fingerprint: Codable {
        let aspect: Double
        let pixels: Data
    }

    private static let storageKey = "Reader.blacklistedPages"
    private static let side = 64
    private static let pixelTolerance = 14
    private static let matchThreshold = 0.9
    private static let aspectTolerance = 0.12

    private let lock = NSLock()
    private var fingerprints: [Fingerprint] = []

    private init() {
        if
            let data = UserDefaults.standard.data(forKey: Self.storageKey),
            let stored = try? PropertyListDecoder().decode([Fingerprint].self, from: data)
        {
            fingerprints = stored
        }
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return fingerprints.isEmpty
    }

    func add(_ image: UIImage) async {
        let fingerprint = await Task.detached(priority: .userInitiated) {
            Self.makeFingerprint(from: image)
        }.value
        guard let fingerprint else { return }

        lock.lock()
        defer { lock.unlock() }
        guard !fingerprints.contains(where: { Self.isMatch($0, fingerprint) }) else { return }
        fingerprints.append(fingerprint)
        if let data = try? PropertyListEncoder().encode(fingerprints) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    func matches(_ image: UIImage) async -> Bool {
        lock.lock()
        let snapshot = fingerprints
        lock.unlock()
        guard !snapshot.isEmpty else { return false }

        return await Task.detached(priority: .userInitiated) {
            guard let fingerprint = Self.makeFingerprint(from: image) else { return false }
            return snapshot.contains { Self.isMatch($0, fingerprint) }
        }.value
    }

    private static func makeFingerprint(from image: UIImage) -> Fingerprint? {
        guard
            let cgImage = image.cgImage,
            cgImage.width > 0,
            cgImage.height > 0
        else { return nil }

        let side = Self.side
        var buffer = [UInt8](repeating: 0, count: side * side)
        let drawn = buffer.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }

        return Fingerprint(
            aspect: Double(cgImage.width) / Double(cgImage.height),
            pixels: Data(buffer)
        )
    }

    private static func isMatch(_ first: Fingerprint, _ second: Fingerprint) -> Bool {
        let count = first.pixels.count
        guard count > 0, count == second.pixels.count, second.aspect > 0 else { return false }
        guard abs(first.aspect / second.aspect - 1) <= aspectTolerance else { return false }

        var matching = 0
        first.pixels.withUnsafeBytes { firstBytes in
            second.pixels.withUnsafeBytes { secondBytes in
                for index in 0..<count where abs(Int(firstBytes[index]) - Int(secondBytes[index])) <= pixelTolerance {
                    matching += 1
                }
            }
        }
        return Double(matching) / Double(count) >= matchThreshold
    }
}
