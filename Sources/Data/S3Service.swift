import Foundation

struct RadarError: LocalizedError {
    let message: String
    init(_ m: String) { message = m }
    var errorDescription: String? { message }
}

private final class KeyParser: NSObject, XMLParserDelegate {
    var keys: [String] = []
    var truncated = false
    var token: String?
    private var current = ""
    func parser(_ p: XMLParser, didStartElement e: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) { current = "" }
    func parser(_ p: XMLParser, foundCharacters s: String) { current += s }
    func parser(_ p: XMLParser, didEndElement e: String, namespaceURI: String?, qualifiedName: String?) {
        switch e {
        case "Key": keys.append(current)
        case "IsTruncated": truncated = (current == "true")
        case "NextContinuationToken": token = current
        default: break
        }
    }
}

/// Anonymous access to NOAA's public Open Data buckets on AWS.
enum S3 {
    static let level2Bucket = "unidata-nexrad-level2"
    static let level3Bucket = "unidata-nexrad-level3"

    private static func enc(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s
    }

    static func list(bucket: String, prefix: String) async throws -> [String] {
        var all: [String] = []
        var token: String?
        repeat {
            var q = "list-type=2&prefix=\(enc(prefix))"
            if let t = token { q += "&continuation-token=\(enc(t))" }
            guard let url = URL(string: "https://\(bucket).s3.amazonaws.com/?\(q)") else { break }
            let (data, resp) = try await URLSession.shared.data(from: url)
            if let h = resp as? HTTPURLResponse, h.statusCode != 200 { throw RadarError("S3 listing failed (HTTP \(h.statusCode))") }
            let delegate = KeyParser()
            let parser = XMLParser(data: data)
            parser.delegate = delegate
            parser.parse()
            all += delegate.keys
            token = delegate.truncated ? delegate.token : nil
        } while token != nil
        return all
    }

    private static func utcString(daysAgo: Int, format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = format
        return f.string(from: Date().addingTimeInterval(-Double(daysAgo) * 86400))
    }

    static func latestLevel2Key(site: String) async throws -> String? {
        for d in 0...1 {
            let prefix = "\(utcString(daysAgo: d, format: "yyyy/MM/dd"))/\(site)/"
            let keys = try await list(bucket: level2Bucket, prefix: prefix)
                .filter { !$0.hasSuffix("_MDM") && $0.contains("_V0") }
            if let k = keys.sorted().last { return k }
        }
        return nil
    }

    static func latestLevel3Key(site3: String, code: String) async throws -> String? {
        for d in 0...1 {
            let prefix = "\(site3)_\(code)_\(utcString(daysAgo: d, format: "yyyy_MM_dd"))"
            let keys = try await list(bucket: level3Bucket, prefix: prefix)
            if let k = keys.sorted().last { return k }
        }
        return nil
    }

    static func download(bucket: String, key: String) async throws -> Data {
        guard let url = URL(string: "https://\(bucket).s3.amazonaws.com/\(key)") else { throw RadarError("Bad URL") }
        let (data, resp) = try await URLSession.shared.data(from: url)
        if let h = resp as? HTTPURLResponse, h.statusCode != 200 { throw RadarError("Download failed (HTTP \(h.statusCode))") }
        return data
    }
}
