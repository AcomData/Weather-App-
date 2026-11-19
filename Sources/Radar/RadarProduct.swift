import Foundation

enum RadarProduct: String, CaseIterable, Identifiable {
    case reflectivity, velocity, spectrumWidth, zdr, cc, kdp, phi, hca
    case compositeRef, echoTops, vil, precipRate, oneHourPrecip, stormTotalPrecip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reflectivity: return "Reflectivity"
        case .velocity: return "Velocity"
        case .spectrumWidth: return "Spectrum Width"
        case .zdr: return "ZDR"
        case .cc: return "CC"
        case .kdp: return "KDP"
        case .phi: return "PhiDP"
        case .hca: return "Hydro Class"
        case .compositeRef: return "Comp. Refl"
        case .echoTops: return "Echo Tops"
        case .vil: return "VIL"
        case .precipRate: return "Precip Rate"
        case .oneHourPrecip: return "1-hr Precip"
        case .stormTotalPrecip: return "Storm Total"
        }
    }

    var unit: String {
        switch self {
        case .reflectivity, .compositeRef: return "dBZ"
        case .velocity: return "kt"
        case .spectrumWidth: return "m/s"
        case .zdr: return "dB"
        case .cc: return "ρhv"
        case .kdp: return "°/km"
        case .phi: return "°"
        case .hca: return ""
        case .echoTops: return "kft"
        case .vil: return "kg/m²"
        case .precipRate, .oneHourPrecip, .stormTotalPrecip: return "in"
        }
    }

    /// Level 2 moment name in the Archive II type-31 message.
    var l2Moment: String? {
        switch self {
        case .reflectivity: return "REF"
        case .velocity: return "VEL"
        case .spectrumWidth: return "SW"
        case .zdr: return "ZDR"
        case .cc: return "RHO"
        case .phi: return "PHI"
        default: return nil
        }
    }

    /// Level 3 AWIPS product ID (N0B, N1B ... for tilt-dependent products).
    func l3Code(tilt: Int) -> String? {
        let t = max(0, min(3, tilt))
        switch self {
        case .reflectivity: return "N\(t)B"
        case .velocity: return "N\(t)G"
        case .zdr: return "N\(t)X"
        case .cc: return "N\(t)C"
        case .kdp: return "N\(t)K"
        case .hca: return "N\(t)H"
        case .spectrumWidth: return "NSW"
        case .compositeRef: return "NCR"
        case .echoTops: return "EET"
        case .vil: return "DVL"
        case .precipRate: return "DPR"
        case .oneHourPrecip: return "DAA"
        case .stormTotalPrecip: return "DTA"
        case .phi: return nil
        }
    }

    var tiltDependentL3: Bool {
        switch self {
        case .reflectivity, .velocity, .zdr, .cc, .kdp, .hca: return true
        default: return false
        }
    }

    /// Multiplier applied to decoded values before colouring (m/s -> knots for velocity).
    var multiplier: Float { self == .velocity ? 1.94384 : 1 }

    /// Legacy 16-level products: value = raw * legacyScale.
    var legacyScale: Float { self == .compositeRef ? 0.2 : 1 }   // NCR: level*5 dBZ

    var colorMap: ColorMap {
        switch self {
        case .reflectivity, .compositeRef:
            return ColorMap(palette: .gradient([
                (5,0x04E9E7),(10,0x019FF4),(15,0x0300F4),(20,0x02FD02),(25,0x01C501),(30,0x008E00),
                (35,0xFDF802),(40,0xE5BC00),(45,0xFD9500),(50,0xFD0000),(55,0xD40000),(60,0xBC0000),
                (65,0xF800FD),(70,0x9854C6),(75,0xFDFDFD)]))
        case .velocity:
            return ColorMap(palette: .gradient([
                (-100,0x00FFFF),(-50,0x00FF00),(-30,0x00B400),(-10,0x005000),(-1,0x2A3F2A),
                (1,0x4A2A2A),(10,0x640000),(30,0xB40000),(50,0xFF0000),(100,0xFFFF00)]),
                foldedColor: 0xA000FF)
        case .spectrumWidth:
            return ColorMap(palette: .gradient([(0,0x404040),(4,0x00C800),(8,0xFFFF00),(12,0xFF8000),(16,0xFF0000),(25,0xFF00FF)]),
                            foldedColor: 0xA000FF)
        case .zdr:
            return ColorMap(palette: .gradient([(-2,0x707070),(0,0x2E9BE8),(1,0x00D060),(2,0xFFFF00),(3,0xFF9900),(4,0xFF0000),(6,0xFF00FF)]))
        case .cc:
            return ColorMap(palette: .gradient([(0.2,0x4B0082),(0.5,0x0000FF),(0.8,0x00B4FF),(0.9,0x00FF00),(0.96,0xFFFF00),(0.98,0xFF8000),(1.05,0xFF0000)]))
        case .kdp:
            return ColorMap(palette: .gradient([(-1,0x5555FF),(0,0xBBBBBB),(0.5,0x00FFFF),(1,0x00FF00),(2,0xFFFF00),(4,0xFF9900),(6,0xFF0000),(10,0xFF00FF)]))
        case .phi:
            return ColorMap(palette: .gradient([(0,0x0000FF),(90,0x00FFFF),(180,0x00FF00),(270,0xFFFF00),(360,0xFF0000)]))
        case .hca:
            // 10=BI 20=GC 30=IC 40=DS 50=WS 60=RA 70=HR 80=BD 90=GR 100=HA
            return ColorMap(palette: .categories([nil,0x7B5EA7,0x808080,0xE0F0FF,0xA0C8FF,0x5AA0FF,0x40D040,0xFFE000,0xFF8000,0xFF0000,0xFF00FF,0x500050]))
        case .echoTops:
            return ColorMap(palette: .gradient([(5,0x4A90E2),(10,0x00A0FF),(20,0x00FF00),(30,0xFFFF00),(40,0xFF8000),(50,0xFF0000),(60,0xFF00FF),(70,0xFFFFFF)]))
        case .vil:
            return ColorMap(palette: .gradient([(1,0x00A0FF),(5,0x00FF00),(10,0xFFFF00),(20,0xFF9900),(35,0xFF0000),(50,0xFF00FF),(70,0xFFFFFF)]))
        case .precipRate, .oneHourPrecip, .stormTotalPrecip:
            return ColorMap(palette: .gradient([(0.01,0x98FB98),(0.25,0x00C800),(0.5,0x006400),(1,0xFFFF00),(2,0xFF9900),(3,0xFF0000),(5,0xFF00FF),(8,0xFFFFFF)]))
        }
    }
}
