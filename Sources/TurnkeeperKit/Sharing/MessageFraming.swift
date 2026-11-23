import Foundation

/// Splits a TCP byte stream into messages: each is a 4-byte big-endian length followed by JSON.
public enum MessageFraming {
    /// Messages larger than this are refused, so a bad peer can't make us allocate without limit.
    public static let maximumLength = 64 * 1024 * 1024

    /// Frames a message of any of the app's protocols.
    public static func encode<Message: Encodable>(_ message: Message) throws -> Data {
        let body = try JSONEncoder().encode(message)
        var length = UInt32(body.count).bigEndian
        return Data(bytes: &length, count: 4) + body
    }

    /// Takes one complete message of `type` off the front of `buffer`, or returns nil if it hasn't all arrived
    /// yet. A frame longer than `limit` is refused.
    public static func next<Message: Decodable>(
        _ type: Message.Type, from buffer: inout Data, limit: Int = maximumLength
    ) throws -> Message? {
        guard buffer.count >= 4 else { return nil }
        let length = buffer.prefix(4).reduce(0) { $0 << 8 | Int($1) }
        guard length <= limit else { throw ChannelError.messageTooLarge(length) }
        guard buffer.count >= 4 + length else { return nil }
        let body = buffer.dropFirst(4).prefix(length)
        buffer = Data(buffer.dropFirst(4 + length))
        return try JSONDecoder().decode(type, from: Data(body))
    }
}

/// A 4-digit code shown on the sharing device and typed on the one following it.
public enum PairingCode {
    public static func make<Generator: RandomNumberGenerator>(using generator: inout Generator) -> String {
        String(format: "%04d", Int.random(in: 0...9999, using: &generator))
    }

    public static func matches(_ entered: String, _ expected: String) -> Bool {
        entered.filter(\.isNumber) == expected
    }
}

public enum ChannelError: Error, LocalizedError, Equatable {
    case messageTooLarge(Int)
    case connectionFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .messageTooLarge(length): return "Receiving failed: the other device sent \(length) bytes at once."
        case let .connectionFailed(reason): return "Connecting failed: the connection broke (\(reason))."
        }
    }
}
