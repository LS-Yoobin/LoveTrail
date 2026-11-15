import Foundation

/// Maps between iOS record ids (`UUID`) and couple-sync server ids (24-char ObjectId hex).
///
/// The sync contract (BAB-54 §4) requires client-supplied ids to be ObjectIds, while
/// every iOS model is keyed by `UUID`. Rather than migrate every model and media file:
///
/// - A local UUID's server id is its **first 12 bytes** (`objectId(for:)`).
/// - A server record created on the partner's phone gets a local UUID built from its
///   12 ObjectId bytes plus a fixed 4-byte suffix (`uuid(forObjectId:)`).
///
/// Both directions agree on the first 12 bytes, so records are always matched by
/// `objectId(for: localId) == serverId`, never by full UUID equality. UUIDv4 leaves 92
/// random bits in those 12 bytes, so prefix collisions are not a practical concern.
///
/// If the backend later accepts UUID strings directly, only this type needs to change.
enum SyncIDCodec {
    /// Marks UUIDs minted from a server id (bytes 12…15).
    private static let remoteSuffix: [UInt8] = [0xC0, 0x7E, 0x1A, 0x5C]

    static func objectId(for uuid: UUID) -> String {
        let bytes = withUnsafeBytes(of: uuid.uuid) { Array($0) }
        return bytes.prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    static func uuid(forObjectId objectId: String) -> UUID? {
        let hex = objectId.lowercased()
        guard hex.count == 24 else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(16)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        bytes.append(contentsOf: remoteSuffix)
        return bytes.withUnsafeBytes { raw in
            UUID(uuid: raw.load(as: uuid_t.self))
        }
    }

    static func matches(_ uuid: UUID, objectId: String) -> Bool {
        Self.objectId(for: uuid) == objectId.lowercased()
    }
}
