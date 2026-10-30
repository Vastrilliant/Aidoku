//
//  PageBlacklist.swift
//  Aidoku
//

import CryptoKit
import Nuke
import UIKit

struct PageBlacklistedError: Error {}

extension ImagePipeline.Error {
    var isBlacklisted: Bool {
        switch self {
            case .dataLoadingFailed(let error): error is PageBlacklistedError
            case .processingFailed(_, _, let error): error is PageBlacklistedError
            default: false
        }
    }
}

final class PageBlacklist: @unchecked Sendable {
    static let shared = PageBlacklist()

    struct Entry: Identifiable {
        let id: UUID
        let aspect: Double
        let thumbnail: UIImage?
    }

    struct ByteSignature: Codable, Equatable {
        let length: Int64
        let digest: Data

        func matches(_ other: ByteSignature) -> Bool {
            digest == other.digest && (length < 0 || other.length < 0 || length == other.length)
        }
    }

    private struct Fingerprint: Codable {
        let id = UUID()
        let aspect: Double
        let pixels: Data
        var signatures: [ByteSignature]

        private enum CodingKeys: String, CodingKey {
            case aspect
            case pixels
            case signatures
        }

        init(aspect: Double, pixels: Data, signatures: [ByteSignature] = []) {
            self.aspect = aspect
            self.pixels = pixels
            self.signatures = signatures
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            aspect = try container.decode(Double.self, forKey: .aspect)
            pixels = try container.decode(Data.self, forKey: .pixels)
            signatures = try container.decodeIfPresent([ByteSignature].self, forKey: .signatures) ?? []
        }
    }

    private static let storageKey = "Reader.blacklistedPages"
    private static let side = 64
    private static let pixelTolerance = 14
    private static let matchThreshold = 0.9
    private static let aspectTolerance = 0.12
    private static let maxSignaturesPerEntry = 16

    static let signaturePrefixLength = 8192

    private let lock = NSLock()
    private var fingerprints: [Fingerprint] = []
    private var signatures: [ByteSignature] = []
    private var knownURLs: Set<URL> = []

    private init() {
        if
            let data = UserDefaults.standard.data(forKey: Self.storageKey),
            let stored = try? PropertyListDecoder().decode([Fingerprint].self, from: data)
        {
            fingerprints = stored
            signatures = stored.flatMap(\.signatures)
        }
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return fingerprints.isEmpty
    }

    var entries: [Entry] {
        lock.lock()
        let snapshot = fingerprints
        lock.unlock()
        return snapshot.map { Entry(id: $0.id, aspect: $0.aspect, thumbnail: Self.makeThumbnail(from: $0)) }
    }

    var hasSignatures: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !signatures.isEmpty
    }

    func remove(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        fingerprints.removeAll { $0.id == id }
        signatures = fingerprints.flatMap(\.signatures)
        knownURLs.removeAll()
        persist()
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        fingerprints.removeAll()
        signatures.removeAll()
        knownURLs.removeAll()
        persist()
    }

    func isKnown(url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return knownURLs.contains(url)
    }

    func remember(url: URL) {
        lock.lock()
        defer { lock.unlock() }
        knownURLs.insert(url)
    }

    func matches(signature: ByteSignature) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return signatures.contains { $0.matches(signature) }
    }

    static func makeSignature(of data: Data) -> ByteSignature {
        makeSignature(prefix: data.prefix(signaturePrefixLength), length: Int64(data.count))
    }

    static func makeSignature(prefix: Data, length: Int64) -> ByteSignature {
        ByteSignature(length: length, digest: Data(SHA256.hash(data: prefix)))
    }

    func add(_ image: UIImage, data: Data? = nil, url: URL? = nil) async {
        let fingerprint = await Task.detached(priority: .userInitiated) {
            Self.makeFingerprint(from: image)
        }.value
        guard let fingerprint else { return }
        insert(fingerprint, signature: data.map { Self.makeSignature(of: $0) }, url: url)
    }

    private func insert(_ fingerprint: Fingerprint, signature: ByteSignature?, url: URL?) {
        lock.lock()
        defer { lock.unlock() }
        if let url {
            knownURLs.insert(url)
        }
        if let index = fingerprints.firstIndex(where: { Self.isMatch($0, fingerprint) }) {
            guard let signature, !fingerprints[index].signatures.contains(signature) else { return }
            fingerprints[index].signatures.append(signature)
            if fingerprints[index].signatures.count > Self.maxSignaturesPerEntry {
                fingerprints[index].signatures.removeFirst()
            }
        } else {
            var fingerprint = fingerprint
            if let signature {
                fingerprint.signatures = [signature]
            }
            fingerprints.append(fingerprint)
        }
        signatures = fingerprints.flatMap(\.signatures)
        persist()
    }

    func matches(_ image: UIImage) async -> Bool {
        guard !isEmpty else { return false }
        return await Task.detached(priority: .userInitiated) {
            self.matchesNow(image)
        }.value
    }

    func matchesNow(_ image: UIImage) -> Bool {
        lock.lock()
        let snapshot = fingerprints
        lock.unlock()
        guard !snapshot.isEmpty, let fingerprint = Self.makeFingerprint(from: image) else { return false }
        return snapshot.contains { Self.isMatch($0, fingerprint) }
    }

    private func persist() {
        if fingerprints.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        } else if let data = try? PropertyListEncoder().encode(fingerprints) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
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

    private static func makeThumbnail(from fingerprint: Fingerprint) -> UIImage? {
        let side = Self.side
        guard
            fingerprint.pixels.count == side * side,
            let provider = CGDataProvider(data: fingerprint.pixels as CFData),
            let cgImage = CGImage(
                width: side,
                height: side,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: side,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )
        else { return nil }
        return UIImage(cgImage: cgImage)
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
