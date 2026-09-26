import Foundation
import Compression

/// gzip decompression with Apple's Compression framework (v0.7.0). It replaces running /usr/bin/gunzip, which a
/// sandboxed app should not do. A gzip file is a header, raw DEFLATE data (Compression's ZLIB algorithm) and an
/// 8-byte trailer (CRC32, then the uncompressed size), both checked so a truncated or damaged download is rejected.
public enum Gzip {
    public static func decompress(_ gz: Data) -> Data? {
        let b = [UInt8](gz)
        guard b.count >= 18, b[0] == 0x1f, b[1] == 0x8b, b[2] == 8 else { return nil }
        let flags = b[3]
        var i = 10
        if flags & 0x04 != 0 {                                   // FEXTRA
            guard i + 2 <= b.count else { return nil }
            i += 2 + Int(b[i]) + Int(b[i + 1]) << 8
        }
        for bit: UInt8 in [0x08, 0x10] where flags & bit != 0 {  // FNAME, FCOMMENT: zero-terminated
            while i < b.count, b[i] != 0 { i += 1 }
            i += 1
        }
        if flags & 0x02 != 0 { i += 2 }                          // FHCRC
        guard i < b.count - 8 else { return nil }
        func le32(_ at: Int) -> UInt32 { b[at..<(at + 4)].reversed().reduce(0) { $0 << 8 | UInt32($1) } }
        guard let out = inflate(Array(b[i..<(b.count - 8)])),
              UInt32(truncatingIfNeeded: out.count) == le32(b.count - 4), crc32(out) == le32(b.count - 8) else { return nil }
        return out
    }

    private static let crcTable: [UInt32] = (0..<256).map { n in
        (0..<8).reduce(UInt32(n)) { c, _ in c & 1 == 1 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
    }
    /// The CRC-32 gzip uses (IEEE 802.3, reflected).
    static func crc32(_ data: Data) -> UInt32 {
        ~data.reduce(~UInt32(0)) { crcTable[Int(($0 ^ UInt32($1)) & 0xFF)] ^ ($0 >> 8) }
    }

    private static func inflate(_ input: [UInt8]) -> Data? {
        let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { stream.deallocate() }
        guard compression_stream_init(stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else { return nil }
        defer { compression_stream_destroy(stream) }
        let chunk = 64 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunk)
        defer { buffer.deallocate() }
        var out = Data()
        return input.withUnsafeBufferPointer { src -> Data? in
            stream.pointee.src_ptr = src.baseAddress!
            stream.pointee.src_size = src.count
            while true {
                stream.pointee.dst_ptr = buffer
                stream.pointee.dst_size = chunk
                let status = compression_stream_process(stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                out.append(buffer, count: chunk - stream.pointee.dst_size)
                switch status {
                case COMPRESSION_STATUS_END: return out
                // Input used up and nothing produced, with no end marker: a truncated stream. Stop rather than spin.
                case COMPRESSION_STATUS_OK where stream.pointee.src_size == 0 && stream.pointee.dst_size == chunk: return nil
                case COMPRESSION_STATUS_OK: continue
                default: return nil
                }
            }
        }
    }
}
