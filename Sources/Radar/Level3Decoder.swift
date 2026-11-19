import Foundation
import SWCompression

/// Decoder for NEXRAD Level 3 products with radial data packets (0x10 digital radial, 0xAF1F run-length radial).
/// Handles the WMO/AWIPS text headers and bzip2-compressed symbology blocks.
enum Level3Decoder {
    private static let floatScaleCodes: Set<Int> = [134, 135, 138, 159, 161, 163, 165, 170, 172, 173, 174, 175, 176, 177]
    private static let minIncCodes: Set<Int> = [94, 99, 153, 154, 155]
    private static let fineGateCodes: Set<Int> = [99, 153, 154, 155, 159, 161, 163, 165, 170, 172, 176]

    static func decode(_ file: Data, product: RadarProduct) throws -> Sweep {
        let bytes = [UInt8](file)
        guard bytes.count > 130 else { throw RadarError("Level 3 file too short") }

        // Skip WMO + AWIPS header lines (each ends with CR CR LF).
        var msg = 0, found = 0, i = 0
        while i + 2 < min(bytes.count, 160) {
            if bytes[i] == 13 && bytes[i + 1] == 13 && bytes[i + 2] == 10 { found += 1; i += 3; if found == 2 { msg = i; break } }
            else { i += 1 }
        }
        let r = ByteReader(b: bytes)
        guard r.s16(msg + 18) == -1 else { throw RadarError("Unrecognised Level 3 header") }

        let code = r.u16(msg + 30)
        let lat = Double(r.s32(msg + 20)) / 1000
        let lon = Double(r.s32(msg + 24)) / 1000
        let vcp = r.u16(msg + 34)
        let days = r.u16(msg + 40), secs = r.u32(msg + 42)
        let time = Date(timeIntervalSince1970: Double(days - 1) * 86400 + Double(secs))
        let elev = Double(r.s16(msg + 58)) / 10

        // Calibration
        var scale: Float = product.legacyScale, offset: Float = 0
        var foldedRaw: Int? = nil
        if floatScaleCodes.contains(code) {
            scale = r.f32(msg + 60); offset = r.f32(msg + 64); foldedRaw = 1
        } else if minIncCodes.contains(code) {
            let minV = Double(r.s16(msg + 60)) / 10, inc = Double(r.s16(msg + 62)) / 10
            guard inc != 0 else { throw RadarError("Bad threshold block") }
            scale = Float(1 / inc); offset = Float(2 - minV / inc); foldedRaw = 1
        }
        guard scale != 0 else { throw RadarError("Bad scale in product") }

        // Symbology block (bzip2-compressed in newer products)
        var buf = r
        let S: Int
        let dataStart = msg + 120
        if dataStart + 3 < bytes.count, bytes[dataStart] == 0x42, bytes[dataStart + 1] == 0x5A, bytes[dataStart + 2] == 0x68 {
            let dec = try BZip2.decompress(data: Data(bytes[dataStart...]))
            buf = ByteReader(b: [UInt8](dec))
            S = 0
        } else {
            S = msg + r.u32(msg + 108) * 2
        }
        guard S + 20 < buf.b.count, buf.s16(S) == -1, buf.u16(S + 2) == 1 else { throw RadarError("Symbology block not found") }

        let L = S + 16   // first packet of first layer
        guard buf.s16(S + 10) == -1 else { throw RadarError("Layer divider missing") }
        let packet = buf.u16(L)
        guard packet == 0x10 || packet == 0xAF1F else { throw RadarError("Unsupported packet type 0x\(String(packet, radix: 16))") }

        let firstBin = buf.u16(L + 2)
        let gate: Float = fineGateCodes.contains(code) ? 0.25 : 1.0
        let nRadials = buf.u16(L + 12)
        var q = L + 14
        var inputs: [RadialInput] = []
        for _ in 0..<nRadials {
            guard q + 6 <= buf.b.count else { break }
            let nBytes = packet == 0x10 ? buf.u16(q) : buf.u16(q) * 2
            let start = Double(buf.u16(q + 2)) / 10, delta = Double(buf.u16(q + 4)) / 10
            q += 6
            guard q + nBytes <= buf.b.count else { break }
            var raw: [UInt8]
            if packet == 0x10 {
                raw = Array(buf.b[q ..< q + nBytes])
            } else {
                raw = []
                for k in 0..<nBytes {
                    let v = buf.b[q + k]
                    raw.append(contentsOf: repeatElement(v & 0x0F, count: Int(v >> 4)))
                }
            }
            q += nBytes
            inputs.append(RadialInput(startSlot: Int((start * 2).rounded()), slotCount: max(1, Int((delta * 2).rounded())),
                                      firstGateKm: Float(firstBin) * gate, gateKm: gate, raw: raw))
        }
        guard let sweep = Sweep.build(product: product, lat: lat, lon: lon, elevation: elev, vcp: vcp, time: time,
                                      scale: scale, offset: offset, foldedRaw: foldedRaw, radials: inputs)
        else { throw RadarError("No radials decoded") }
        return sweep
    }
}
