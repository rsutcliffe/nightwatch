import Foundation
import Compression

/// gzip decompression with Apple's Compression framework (v0.7.0). It replaces running /usr/bin/gunzip, which a
/// sandboxed app should not do. A gzip file is a header, raw DEFLATE data (Compression's ZLIB algorithm) and an
/// 8-byte trailer ending in the uncompressed size, which is checked so a truncated download is rejected.
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
        let size = b[(b.count - 4)...].reversed().reduce(0) { $0 << 8 | Int($1) }   // ISIZE, little-endian
        guard let out = inflate(Array(b[i..<(b.count - 8)])), out.count & 0xFFFF_FFFF == size else { return nil }
        return out
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
                case COMPRESSION_STATUS_OK: continue
                default: return nil
                }
            }
        }
    }
}
