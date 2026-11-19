import Foundation
import SwiftUI

enum Palette {
    case gradient([(Float, UInt32)])     // (value, 0xRRGGBB); below first stop = transparent
    case categories([UInt32?])           // index = Int(value / 10)
}

struct ColorMap {
    let palette: Palette
    var foldedColor: UInt32? = nil       // range-folded gates (velocity)

    static func pack(_ rgb: UInt32, alpha: Float = 1) -> UInt32 {
        let a = max(0, min(1, alpha))
        let r = UInt32(Float((rgb >> 16) & 255) * a)
        let g = UInt32(Float((rgb >> 8) & 255) * a)
        let b = UInt32(Float(rgb & 255) * a)
        let aa = UInt32(a * 255)
        return r | (g << 8) | (b << 16) | (aa << 24)   // RGBA bytes, premultiplied, little-endian
    }

    func color(_ v: Float) -> UInt32 {
        guard !v.isNaN else { return 0 }
        switch palette {
        case .categories(let cats):
            let i = Int((v / 10).rounded())
            guard i >= 0, i < cats.count, let c = cats[i] else { return 0 }
            return Self.pack(c)
        case .gradient(let s):
            guard let first = s.first, let last = s.last, v >= first.0 else { return 0 }
            if v >= last.0 { return Self.pack(last.1) }
            var i = 0
            while i + 1 < s.count - 1 && v >= s[i + 1].0 { i += 1 }
            let (v0, c0) = s[i], (v1, c1) = s[i + 1]
            let t = (v - v0) / (v1 - v0)
            func ch(_ shift: UInt32) -> UInt32 {
                let a = Float((c0 >> shift) & 255), b = Float((c1 >> shift) & 255)
                return UInt32(a + (b - a) * t)
            }
            return Self.pack((ch(16) << 16) | (ch(8) << 8) | ch(0))
        }
    }

    // MARK: - SwiftUI legend helpers
    var legendStops: [Gradient.Stop] {
        guard case .gradient(let s) = palette, let lo = s.first?.0, let hi = s.last?.0, hi > lo else { return [] }
        return s.map { Gradient.Stop(color: Color(hex: $0.1), location: CGFloat(($0.0 - lo) / (hi - lo))) }
    }
    var legendRange: (Float, Float)? {
        guard case .gradient(let s) = palette, let lo = s.first?.0, let hi = s.last?.0 else { return nil }
        return (lo, hi)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}
