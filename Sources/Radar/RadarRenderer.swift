import Foundation
import UIKit
import CoreLocation

struct RadarOverlay {
    let id = UUID()
    let image: UIImage
    let topLeft: CLLocationCoordinate2D
    let bottomLeft: CLLocationCoordinate2D
    let bottomRight: CLLocationCoordinate2D
    let topRight: CLLocationCoordinate2D
}

/// Rasterises a polar sweep into a Web-Mercator-aligned RGBA image that MapLibre drapes on the map.
enum RadarRenderer {
    static let size = 2048

    static func render(_ sweep: Sweep) -> RadarOverlay? {
        let n = size
        let R = 6371.0
        let lat0 = sweep.lat, lon0 = sweep.lon
        let maxR = sweep.maxRangeKm
        let dLatDeg = (maxR / R) * 180 / .pi
        let dLonDeg = dLatDeg / cos(lat0 * .pi / 180)
        let latTop = lat0 + dLatDeg, latBot = lat0 - dLatDeg
        let lonL = lon0 - dLonDeg, lonR = lon0 + dLonDeg
        func merc(_ lat: Double) -> Double { log(tan(.pi / 4 + lat * .pi / 360)) }
        let yTop = merc(latTop), yBot = merc(latBot)

        // 256-entry colour LUT
        var lut = [UInt32](repeating: 0, count: 256)
        let cmap = sweep.product.colorMap
        for raw in 1..<256 {
            if let f = sweep.foldedRaw, raw == f {
                if let c = cmap.foldedColor { lut[raw] = ColorMap.pack(c, alpha: 0.9) }
                continue
            }
            let v = (Float(raw) - sweep.offset) / sweep.scale * sweep.product.multiplier
            lut[raw] = cmap.color(v)
        }

        var pixels = [UInt32](repeating: 0, count: n * n)
        let stride = sweep.stride
        sweep.data.withUnsafeBufferPointer { dp in
        sweep.counts.withUnsafeBufferPointer { cp in
        sweep.firsts.withUnsafeBufferPointer { fp in
        sweep.gates.withUnsafeBufferPointer { gp in
        lut.withUnsafeBufferPointer { lp in
        pixels.withUnsafeMutableBufferPointer { out in
            let base = out.baseAddress!
            DispatchQueue.concurrentPerform(iterations: n) { row in
                let y = yTop + (yBot - yTop) * (Double(row) + 0.5) / Double(n)
                let lat = (2 * atan(exp(y)) - .pi / 2) * 180 / .pi
                let north = R * (lat - lat0) * .pi / 180
                let kx = R * cos((lat + lat0) / 2 * .pi / 180) * .pi / 180
                for col in 0..<n {
                    let lon = lonL + (lonR - lonL) * (Double(col) + 0.5) / Double(n)
                    let east = (lon - lon0) * kx
                    let rng = (east * east + north * north).squareRoot()
                    if rng > maxR { continue }
                    var az = atan2(east, north) * 180 / .pi
                    if az < 0 { az += 360 }
                    let slot = Int(az * 2) % Sweep.slots
                    let cnt = Int(cp[slot])
                    if cnt == 0 { continue }
                    let gi = Int((Float(rng) - fp[slot]) / gp[slot])
                    if gi < 0 || gi >= cnt { continue }
                    base[row * n + col] = lp[Int(dp[slot * stride + gi])]
                }
            }
        }}}}}}

        let cs = CGColorSpaceCreateDeviceRGB()
        let data = pixels.withUnsafeBufferPointer { Data(buffer: $0) }
        guard let provider = CGDataProvider(data: data as CFData),
              let cg = CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4,
                               space: cs, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }

        return RadarOverlay(image: UIImage(cgImage: cg),
                            topLeft: .init(latitude: latTop, longitude: lonL),
                            bottomLeft: .init(latitude: latBot, longitude: lonL),
                            bottomRight: .init(latitude: latBot, longitude: lonR),
                            topRight: .init(latitude: latTop, longitude: lonR))
    }
}
