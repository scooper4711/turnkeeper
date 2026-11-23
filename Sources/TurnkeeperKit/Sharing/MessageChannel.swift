import Foundation
import Network

/// Sends and receives framed messages of one protocol, such as `TableMessage`, over one connection.
final class MessageChannel<Message: Codable & Sendable>: @unchecked Sendable {
    private let connection: NWConnection
    private let queue: DispatchQueue
    /// The longest message this side accepts.
    private let limit: Int
    /// Bytes received but not yet read as a message. Only touched on `queue`.
    private var buffer = Data()

    init(connection: NWConnection, queue: DispatchQueue, limit: Int = MessageFraming.maximumLength) {
        self.connection = connection
        self.queue = queue
        self.limit = limit
    }

    func open() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = Once()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: once.run { continuation.resume() }
                case let .failed(error), let .waiting(error):
                    once.run { continuation.resume(throwing: ChannelError.connectionFailed("\(error)")) }
                case .cancelled: once.run { continuation.resume(throwing: ChannelError.connectionFailed("cancelled")) }
                default: break
                }
            }
            connection.start(queue: queue)
        }
    }

    func send(_ message: Message) async throws {
        let data = try MessageFraming.encode(message)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: ChannelError.connectionFailed("\(error)"))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func receive() async throws -> Message {
        while true {
            if let message = try queue.sync(execute: { try MessageFraming.next(Message.self, from: &buffer,
                                                                              limit: limit) }) {
                return message
            }
            let chunk = try await receiveChunk()
            queue.sync { buffer.append(chunk) }
        }
    }

    func close() {
        connection.cancel()
    }

    private func receiveChunk() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: ChannelError.connectionFailed("\(error)"))
                } else if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(throwing: ChannelError.connectionFailed("closed early"))
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }
}

/// Runs a block only the first time, so a continuation is resumed exactly once.
final class Once: @unchecked Sendable {
    private var hasRun = false
    private let lock = NSLock()

    func run(_ block: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !hasRun else { return }
        hasRun = true
        block()
    }
}
