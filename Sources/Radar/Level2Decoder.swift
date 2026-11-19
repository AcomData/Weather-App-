import Foundation
import SWCompression

struct L2Radial: Sendable {
    var azimuth: Float
    var spacing: Float          // degrees
    var firstGateKm: Float
    var gateKm: Float
    var scale: Float
    var offset: Float
    var raw: [UInt8]
}

struct L2Cut: Sendable {
    var number: Int
    var angle: Float
    var moments: [String: [L2Radial]] = [:]
}

struct L2Volume: Sendable {
    var site: String
    var lat: Double
    var lon: Double
    var vcp: Int
    var time: Date
    var cuts: [Int: L2Cut]
}

/// Decoder for WSR-88D Archive II volume files (message type 31, 8-bit moments).
enum Level2Decoder {
    static func decode(_ file: Data) throws -> L2Volume {
        guard file.count > 28, String(data: file.prefix(4), encoding: .ascii) == "AR2V" else {
            throw RadarError("Not an Archive II file")
        }
        // 1. Concatenate bzip2-compressed LDM records.
        var stream = [UInt8]()
        var pos = 24
        let bytes = [UInt8](file)
        let r0 = ByteReader(b: bytes)
        while pos + 4 <= bytes.count {
            let size = abs(r0.s32(pos))
            pos += 4
            guard size > 0, pos + size <= bytes.count else { break }
            let chunk = Data(bytes[pos ..< pos + size])
            pos += size
            if let out = try? BZip2.decompress(data: chunk) { stream.append(contentsOf: out) }
        }
        guard stream.count > 2432 else { throw RadarError("Level 2 volume was empty or truncated") }
        let r = ByteReader(b: stream)

        // 2. Walk messages.
        var cuts: [Int: L2Cut] = [:]
        var site = "", lat = 0.0, lon = 0.0, vcp = 0
        var time: Date?
        var p = 0
        while p + 12 + 16 <= stream.count {
            let hdr = p + 12
            let sizeHW = r.u16(hdr)
            let type = r.u8(hdr + 3)
            if type != 31 { p += 2432; continue }
            if sizeHW < 20 { break }
            let body = hdr + 16
            defer { p += 12 + sizeHW * 2 }
            guard body + 72 <= stream.count else { break }

            if site.isEmpty { site = String(bytes: stream[body ..< body + 4], encoding: .ascii) ?? "" }
            let ms = r.u32(body + 4), days = r.u16(body + 8)
            if time == nil { time = Date(timeIntervalSince1970: Double(days - 1) * 86400 + Double(ms) / 1000) }
            let az = r.f32(body + 12)
            let spacing: Float = r.u8(body + 20) == 2 ? 1.0 : 0.5
            let elevNum = r.u8(body + 22)
            let elev = r.f32(body + 24)
            let blocks = min(r.u16(body + 30), 10)

            for i in 0..<blocks {
                let off = r.u32(body + 32 + 4 * i)
                let bp = body + off
                guard off > 0, bp + 28 <= stream.count else { continue }
                let name = String(bytes: stream[bp + 1 ..< bp + 4], encoding: .ascii)?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                if name == "VOL" {
                    if vcp == 0 { lat = Double(r.f32(bp + 8)); lon = Double(r.f32(bp + 12)); vcp = r.u16(bp + 40) }
                } else if r.u8(bp) == 68 && ["REF","VEL","SW","ZDR","PHI","RHO"].contains(name) {
                    let gates = r.u16(bp + 8)
                    let first = Float(r.u16(bp + 10)) / 1000
                    let interval = Float(r.u16(bp + 12)) / 1000
                    let wordSize = r.u8(bp + 19)
                    let scale = r.f32(bp + 20), offset = r.f32(bp + 24)
                    guard wordSize == 8, gates > 0, scale != 0, interval > 0, bp + 28 + gates <= stream.count else { continue }
                    let radial = L2Radial(azimuth: az, spacing: spacing, firstGateKm: first, gateKm: interval,
                                          scale: scale, offset: offset, raw: Array(stream[bp + 28 ..< bp + 28 + gates]))
                    var cut = cuts[elevNum] ?? L2Cut(number: elevNum, angle: elev)
                    cut.moments[name, default: []].append(radial)
                    cuts[elevNum] = cut
                }
            }
        }
        guard !cuts.isEmpty else { throw RadarError("No radial data found in volume") }
        return L2Volume(site: site, lat: lat, lon: lon, vcp: vcp, time: time ?? Date(), cuts: cuts)
    }

    static func sweep(from vol: L2Volume, cut: L2Cut, moment: String, product: RadarProduct) -> Sweep? {
        guard let rads = cut.moments[moment], let f = rads.first else { return nil }
        let inputs = rads.map { r -> RadialInput in
            let start = Int(((r.azimuth - r.spacing / 2) * 2).rounded())
            return RadialInput(startSlot: start, slotCount: Int(r.spacing * 2), firstGateKm: r.firstGateKm,
                               gateKm: r.gateKm, raw: r.raw)
        }
        return Sweep.build(product: product, lat: vol.lat, lon: vol.lon, elevation: Double(cut.angle), vcp: vol.vcp,
                           time: vol.time, scale: f.scale, offset: f.offset, foldedRaw: 1, radials: inputs)
    }
}
