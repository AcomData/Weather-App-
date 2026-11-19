import Foundation

struct RadialInput {
    var startSlot: Int          // 0.5° slot index (0..<720)
    var slotCount: Int          // how many 0.5° slots this radial covers
    var firstGateKm: Float
    var gateKm: Float
    var raw: [UInt8]
}

/// One elevation sweep of one moment/product, flattened into fixed-stride arrays for fast rendering.
struct Sweep: Sendable {
    static let slots = 720

    var product: RadarProduct
    var lat: Double
    var lon: Double
    var maxRangeKm: Double
    var elevation: Double
    var vcp: Int
    var time: Date
    var scale: Float            // value = (raw - offset) / scale
    var offset: Float
    var foldedRaw: Int?         // raw value meaning "range folded"
    var stride: Int
    var data: [UInt8]
    var counts: [Int32]
    var firsts: [Float]
    var gates: [Float]

    static func build(product: RadarProduct, lat: Double, lon: Double, elevation: Double, vcp: Int, time: Date,
                      scale: Float, offset: Float, foldedRaw: Int?, radials: [RadialInput]) -> Sweep? {
        guard let stride = radials.map({ $0.raw.count }).max(), stride > 0 else { return nil }
        var data = [UInt8](repeating: 0, count: slots * stride)
        var counts = [Int32](repeating: 0, count: slots)
        var firsts = [Float](repeating: 0, count: slots)
        var gates = [Float](repeating: 1, count: slots)
        var maxR = 0.0
        for r in radials {
            for k in 0..<max(1, r.slotCount) {
                let s = (((r.startSlot + k) % slots) + slots) % slots
                data.replaceSubrange(s * stride ..< s * stride + r.raw.count, with: r.raw)
                counts[s] = Int32(r.raw.count)
                firsts[s] = r.firstGateKm
                gates[s] = r.gateKm
            }
            maxR = max(maxR, Double(r.firstGateKm + Float(r.raw.count) * r.gateKm))
        }
        return Sweep(product: product, lat: lat, lon: lon, maxRangeKm: min(maxR, 470), elevation: elevation, vcp: vcp,
                     time: time, scale: scale, offset: offset, foldedRaw: foldedRaw, stride: stride,
                     data: data, counts: counts, firsts: firsts, gates: gates)
    }
}

/// Big-endian byte reader.
struct ByteReader {
    let b: [UInt8]
    func u8(_ o: Int) -> Int { Int(b[o]) }
    func u16(_ o: Int) -> Int { Int(b[o]) << 8 | Int(b[o + 1]) }
    func s16(_ o: Int) -> Int { let v = u16(o); return v >= 32768 ? v - 65536 : v }
    func u32(_ o: Int) -> Int { Int(b[o]) << 24 | Int(b[o + 1]) << 16 | Int(b[o + 2]) << 8 | Int(b[o + 3]) }
    func s32(_ o: Int) -> Int { let v = u32(o); return v >= 0x8000_0000 ? v - 0x1_0000_0000 : v }
    func f32(_ o: Int) -> Float { Float(bitPattern: UInt32(u32(o))) }
}
