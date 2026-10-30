//
//  PageBlacklistDataLoader.swift
//  Aidoku
//

import Foundation
import Nuke

final class PageBlacklistDataLoader: DataLoading, @unchecked Sendable {
    private let base: any DataLoading

    init(base: any DataLoading) {
        self.base = base
    }

    func loadData(
        with request: URLRequest,
        didReceiveData: @escaping @Sendable (Data, URLResponse) -> Void,
        completion: @escaping @Sendable (Error?) -> Void
    ) -> any Cancellable {
        let blacklist = PageBlacklist.shared
        guard let url = request.url, !url.isFileURL, !blacklist.isEmpty else {
            return base.loadData(with: request, didReceiveData: didReceiveData, completion: completion)
        }
        if blacklist.isKnown(url: url) {
            completion(PageBlacklistedError())
            return NoopCancellable()
        }
        guard blacklist.hasSignatures else {
            return base.loadData(with: request, didReceiveData: didReceiveData, completion: completion)
        }

        let probe = Probe(url: url, didReceiveData: didReceiveData, completion: completion)
        let task = base.loadData(
            with: request,
            didReceiveData: { probe.receive($0, response: $1) },
            completion: { probe.finish(error: $0) }
        )
        probe.attach(task)
        return probe
    }
}

private struct NoopCancellable: Cancellable {
    func cancel() {}
}

private final class Probe: Cancellable, @unchecked Sendable {
    private let url: URL
    private let didReceiveData: @Sendable (Data, URLResponse) -> Void
    private let completion: @Sendable (Error?) -> Void

    private let lock = NSLock()
    private var task: (any Cancellable)?
    private var buffer = Data()
    private var response: URLResponse?
    private var decided = false
    private var completed = false

    init(
        url: URL,
        didReceiveData: @escaping @Sendable (Data, URLResponse) -> Void,
        completion: @escaping @Sendable (Error?) -> Void
    ) {
        self.url = url
        self.didReceiveData = didReceiveData
        self.completion = completion
    }

    func attach(_ task: any Cancellable) {
        lock.lock()
        self.task = task
        let shouldCancel = completed
        lock.unlock()
        if shouldCancel {
            task.cancel()
        }
    }

    func cancel() {
        lock.lock()
        let task = task
        lock.unlock()
        task?.cancel()
    }

    func receive(_ chunk: Data, response: URLResponse) {
        lock.lock()
        if completed {
            lock.unlock()
            return
        }
        if decided {
            lock.unlock()
            didReceiveData(chunk, response)
            return
        }

        buffer.append(chunk)
        self.response = response
        guard buffer.count >= PageBlacklist.signaturePrefixLength else {
            lock.unlock()
            return
        }

        decided = true
        let data = buffer
        buffer = Data()
        if Self.isBlacklisted(data, response: response) {
            completed = true
            let task = task
            lock.unlock()
            reject(cancelling: task)
        } else {
            lock.unlock()
            didReceiveData(data, response)
        }
    }

    func finish(error: Error?) {
        lock.lock()
        if completed {
            lock.unlock()
            return
        }
        completed = true

        if decided {
            lock.unlock()
            completion(error)
            return
        }

        decided = true
        let data = buffer
        let received = response
        buffer = Data()

        guard let received, !data.isEmpty else {
            lock.unlock()
            completion(error)
            return
        }
        if error == nil, Self.isBlacklisted(data, response: received) {
            lock.unlock()
            reject(cancelling: nil)
            return
        }
        lock.unlock()
        didReceiveData(data, received)
        completion(error)
    }

    private func reject(cancelling task: (any Cancellable)?) {
        PageBlacklist.shared.remember(url: url)
        task?.cancel()
        completion(PageBlacklistedError())
    }

    private static func isBlacklisted(_ data: Data, response: URLResponse) -> Bool {
        let http = response as? HTTPURLResponse
        if http?.statusCode == 206 {
            return false
        }
        let encoded = http?.value(forHTTPHeaderField: "Content-Encoding").map {
            !$0.isEmpty && $0.lowercased() != "identity"
        } ?? false
        let expected = response.expectedContentLength
        let length: Int64 = encoded || expected <= 0 ? -1 : expected
        let signature = PageBlacklist.makeSignature(
            prefix: data.prefix(PageBlacklist.signaturePrefixLength),
            length: length
        )
        return PageBlacklist.shared.matches(signature: signature)
    }
}
