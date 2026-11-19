import Foundation
import CoreLocation

enum MapStyle: String, CaseIterable, Identifiable {
    case liberty = "Liberty", bright = "Bright", positron = "Positron"
    var id: String { rawValue }
    /// OpenFreeMap hosted vector styles (no API key required).
    var url: URL { URL(string: "https://tiles.openfreemap.org/styles/\(rawValue.lowercased())")! }
}

/// GOES imagery via NASA GIBS WMTS (EPSG:3857). If a layer shows no tiles, check its format/time
/// in GIBS GetCapabilities and adjust `ext` / `maxZoom` / `latencyMinutes` here.
enum SatelliteLayer: String, CaseIterable, Identifiable {
    case off = "Off"
    case eastGeoColor = "GOES-East GeoColor"
    case eastVisible = "GOES-East Visible"
    case eastIR = "GOES-East Clean IR"
    case eastAirMass = "GOES-East Air Mass"
    case westGeoColor = "GOES-West GeoColor"
    case westVisible = "GOES-West Visible"
    case westIR = "GOES-West Clean IR"

    var id: String { rawValue }

    var gibsLayer: String? {
        switch self {
        case .off: return nil
        case .eastGeoColor: return "GOES-East_ABI_GeoColor"
        case .eastVisible: return "GOES-East_ABI_Band2_Red_Visible_1km"
        case .eastIR: return "GOES-East_ABI_Band13_Clean_Infrared"
        case .eastAirMass: return "GOES-East_ABI_Air_Mass"
        case .westGeoColor: return "GOES-West_ABI_GeoColor"
        case .westVisible: return "GOES-West_ABI_Band2_Red_Visible_1km"
        case .westIR: return "GOES-West_ABI_Band13_Clean_Infrared"
        }
    }
    var ext: String {
        switch self {
        case .eastIR, .westIR, .eastVisible, .westVisible: return "png"
        default: return "jpg"
        }
    }
    var maxZoom: Int { (self == .eastVisible || self == .westVisible) ? 7 : 6 }
    var latencyMinutes: Double { 45 }

    var tileTemplate: String? {
        guard let layer = gibsLayer else { return nil }
        let t = Date().addingTimeInterval(-latencyMinutes * 60)
        let rounded = Date(timeIntervalSince1970: floor(t.timeIntervalSince1970 / 600) * 600)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return "https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/\(layer)/default/\(f.string(from: rounded))/GoogleMapsCompatible_Level\(maxZoom)/{z}/{y}/{x}.\(ext)"
    }
}

struct FocusRequest: Equatable {
    let id = UUID()
    let lat: Double
    let lon: Double
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }
}
