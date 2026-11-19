import Foundation
import CoreLocation

struct RadarSite: Identifiable, Hashable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
    /// Level 3 bucket keys use the 3-letter ID (KAMA -> AMA).
    var level3ID: String { String(id.dropFirst()) }
}

/// Partial list of WSR-88D sites. Add more rows as needed; positions only need to be approximate
/// (the decoded files carry the exact radar coordinates).
enum NexradSites {
    private static let rows: [(String, String, Double, Double)] = [
        ("KAMA","Amarillo, TX",35.233,-101.709),("KLBB","Lubbock, TX",33.654,-101.814),
        ("KFDR","Frederick, OK",34.362,-98.977),("KTLX","Oklahoma City, OK",35.333,-97.278),
        ("KINX","Tulsa, OK",36.175,-95.564),("KVNX","Vance AFB, OK",36.741,-98.128),
        ("KICT","Wichita, KS",37.655,-97.443),("KDDC","Dodge City, KS",37.761,-99.969),
        ("KGLD","Goodland, KS",39.367,-101.700),("KTWX","Topeka, KS",38.997,-96.233),
        ("KFWS","Dallas/Fort Worth, TX",32.573,-97.303),("KEWX","Austin/San Antonio, TX",29.704,-98.029),
        ("KHGX","Houston, TX",29.472,-95.079),("KMAF","Midland, TX",31.943,-102.189),
        ("KSJT","San Angelo, TX",31.371,-100.492),("KCRP","Corpus Christi, TX",27.784,-97.511),
        ("KBRO","Brownsville, TX",25.916,-97.419),("KSHV","Shreveport, LA",32.451,-93.841),
        ("KLIX","New Orleans, LA",30.337,-89.826),("KLZK","Little Rock, AR",34.837,-92.262),
        ("KSGF","Springfield, MO",37.235,-93.400),("KEAX","Kansas City, MO",38.810,-94.264),
        ("KLOT","Chicago, IL",41.604,-88.085),("KDVN","Quad Cities, IA",41.612,-90.581),
        ("KMPX","Minneapolis, MN",44.849,-93.566),("KMKX","Milwaukee, WI",42.968,-88.551),
        ("KDTX","Detroit, MI",42.700,-83.472),("KGRR","Grand Rapids, MI",42.894,-85.545),
        ("KCLE","Cleveland, OH",41.413,-81.860),("KILN","Wilmington, OH",39.420,-83.822),
        ("KPAH","Paducah, KY",37.068,-88.772),("KOHX","Nashville, TN",36.247,-86.563),
        ("KMRX","Knoxville, TN",36.169,-83.402),("KNQA","Memphis, TN",35.345,-89.873),
        ("KHTX","Huntsville, AL",34.931,-86.083),("KBMX","Birmingham, AL",33.172,-86.770),
        ("KMOB","Mobile, AL",30.679,-88.240),("KDGX","Jackson, MS",32.280,-89.984),
        ("KFFC","Atlanta, GA",33.364,-84.566),("KJAX","Jacksonville, FL",30.485,-81.702),
        ("KTLH","Tallahassee, FL",30.398,-84.329),("KTBW","Tampa, FL",27.705,-82.402),
        ("KMLB","Melbourne, FL",28.113,-80.654),("KAMX","Miami, FL",25.611,-80.413),
        ("KGSP","Greer, SC",34.883,-82.220),("KRAX","Raleigh, NC",35.666,-78.490),
        ("KAKQ","Wakefield, VA",36.984,-77.007),("KLWX","Sterling, VA",38.976,-77.487),
        ("KDIX","Philadelphia, PA",39.947,-74.411),("KPBZ","Pittsburgh, PA",40.532,-80.218),
        ("KOKX","New York, NY",40.866,-72.864),("KBUF","Buffalo, NY",42.949,-78.737),
        ("KALY","Albany, NY",42.699,-74.064),("KBOX","Boston, MA",41.956,-71.137),
        ("KGYX","Portland, ME",43.891,-70.257),("KFSD","Sioux Falls, SD",43.588,-96.729),
        ("KOAX","Omaha, NE",41.320,-96.367),("KUEX","Hastings, NE",40.321,-98.442),
        ("KLNX","North Platte, NE",41.958,-100.576),("KBIS","Bismarck, ND",46.771,-100.760),
        ("KMVX","Grand Forks, ND",47.528,-97.325),("KFTG","Denver, CO",39.787,-104.546),
        ("KPUX","Pueblo, CO",38.460,-104.181),("KCYS","Cheyenne, WY",41.152,-104.806),
        ("KABX","Albuquerque, NM",35.150,-106.824),("KEPZ","El Paso, TX",31.873,-106.698),
        ("KIWA","Phoenix, AZ",33.289,-111.670),("KESX","Las Vegas, NV",35.701,-114.892),
        ("KMTX","Salt Lake City, UT",41.263,-112.448),("KTFX","Great Falls, MT",47.460,-111.385),
        ("KSOX","Santa Ana Mtns, CA",33.818,-117.636),("KVTX","Los Angeles, CA",34.412,-119.179),
        ("KMUX","San Francisco, CA",37.155,-121.898),("KDAX","Sacramento, CA",38.501,-121.678),
        ("KRTX","Portland, OR",45.715,-122.965),("KATX","Seattle, WA",48.195,-122.496),
    ]
    static let all: [RadarSite] = rows.map { RadarSite(id: $0.0, name: $0.1, lat: $0.2, lon: $0.3) }
    static let byID: [String: RadarSite] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func nearest(to c: CLLocationCoordinate2D) -> RadarSite {
        let here = CLLocation(latitude: c.latitude, longitude: c.longitude)
        return all.min { a, b in
            here.distance(from: CLLocation(latitude: a.lat, longitude: a.lon)) <
            here.distance(from: CLLocation(latitude: b.lat, longitude: b.lon))
        } ?? all[0]
    }
}
