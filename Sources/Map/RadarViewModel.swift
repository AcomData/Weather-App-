import Foundation
import SwiftUI
import CoreLocation

@MainActor
final class RadarViewModel: ObservableObject {
    enum DataLevel: String, CaseIterable, Identifiable {
        case level2 = "Level 2", level3 = "Level 3"
        var id: String { rawValue }
    }
    struct TiltOption: Identifiable, Hashable { let id: Int; let label: String }

    @Published var site: RadarSite = NexradSites.byID["KAMA"] ?? NexradSites.all[0]
    @Published var level: DataLevel = .level2
    @Published var product: RadarProduct = .reflectivity
    @Published var tilt: Int = 1                 // L2: elevation number, L3: 0...3
    @Published var satellite: SatelliteLayer = .off
    @Published var mapStyle: MapStyle = .liberty
    @Published var opacity: Double = 0.85
    @Published var pitch: Double = 0

    @Published private(set) var tiltOptions: [TiltOption] = []
    @Published private(set) var activeTilt: Int = 1
    @Published private(set) var overlay: RadarOverlay?
    @Published private(set) var status = ""
    @Published private(set) var vcp: Int?
    @Published private(set) var elevation: Double?
    @Published private(set) var scanTime: Date?
    @Published private(set) var isLoading = false
    @Published var focusRequest: FocusRequest?

    var mapCenter = CLLocationCoordinate2D(latitude: 35.23, longitude: -101.7)

    private var generation = 0
    private var task: Task<Void, Never>?
    private var loop: Task<Void, Never>?
    private var l2Cache: (key: String, volume: L2Volume)?

    var availableProducts: [RadarProduct] {
        RadarProduct.allCases.filter { level == .level2 ? $0.l2Moment != nil : $0.l3Code(tilt: 0) != nil }
    }

    func start() {
        guard loop == nil else { return }
        focusRequest = FocusRequest(lat: site.lat, lon: site.lon)
        reload()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 120_000_000_000)
                self?.reload()
            }
        }
    }

    func siteChanged() {
        focusRequest = FocusRequest(lat: site.lat, lon: site.lon)
        l2Cache = nil
        reload()
    }

    func levelChanged() {
        if !availableProducts.contains(product) { product = .reflectivity }
        let t = level == .level2 ? 1 : 0
        if tilt != t { tilt = t } else { reload() }
    }

    func selectNearest() {
        let s = NexradSites.nearest(to: mapCenter)
        if s != site { site = s } else { focusRequest = FocusRequest(lat: s.lat, lon: s.lon) }
    }

    func reload() {
        generation += 1
        let gen = generation
        task?.cancel()
        task = Task { [weak self] in await self?.load(gen) }
    }

    private func load(_ gen: Int) async {
        isLoading = true
        status = "Loading…"
        do {
            let sweep = level == .level2 ? try await loadLevel2() : try await loadLevel3()
            guard gen == generation else { return }
            status = "Rendering…"
            let out = await Task.detached(priority: .userInitiated) { RadarRenderer.render(sweep) }.value
            guard gen == generation else { return }
            overlay = out
            vcp = sweep.vcp > 0 ? sweep.vcp : nil
            elevation = sweep.elevation
            scanTime = sweep.time
            status = ""
        } catch {
            guard gen == generation else { return }
            if (error as? URLError)?.code == .cancelled { return }
            overlay = nil
            status = error.localizedDescription
        }
        if gen == generation { isLoading = false }
    }

    private func loadLevel2() async throws -> Sweep {
        guard let moment = product.l2Moment else { throw RadarError("\(product.title) is Level 3 only") }
        guard let key = try await S3.latestLevel2Key(site: site.id) else {
            throw RadarError("No recent Level 2 volumes for \(site.id)")
        }
        let volume: L2Volume
        if let c = l2Cache, c.key == key {
            volume = c.volume
        } else {
            status = "Downloading Level 2…"
            let data = try await S3.download(bucket: S3.level2Bucket, key: key)
            status = "Decoding volume…"
            volume = try await Task.detached(priority: .userInitiated) { try Level2Decoder.decode(data) }.value
            l2Cache = (key, volume)
        }
        let cuts = volume.cuts.values.filter { $0.moments[moment] != nil }.sorted { $0.number < $1.number }
        tiltOptions = cuts.map { TiltOption(id: $0.number, label: String(format: "%.1f°", $0.angle)) }
        guard let cut = cuts.first(where: { $0.number == tilt }) ?? cuts.first else {
            throw RadarError("\(product.title) not present in this volume")
        }
        activeTilt = cut.number
        guard let sweep = Level2Decoder.sweep(from: volume, cut: cut, moment: moment, product: product) else {
            throw RadarError("Could not build sweep")
        }
        return sweep
    }

    private func loadLevel3() async throws -> Sweep {
        guard let code = product.l3Code(tilt: tilt) else { throw RadarError("\(product.title) is Level 2 only") }
        tiltOptions = product.tiltDependentL3 ? (0..<4).map { TiltOption(id: $0, label: "Tilt \($0 + 1)") } : []
        activeTilt = max(0, min(3, tilt))
        guard let key = try await S3.latestLevel3Key(site3: site.level3ID, code: code) else {
            throw RadarError("No \(code) file found for \(site.id)")
        }
        status = "Downloading \(code)…"
        let data = try await S3.download(bucket: S3.level3Bucket, key: key)
        let p = product
        return try await Task.detached(priority: .userInitiated) { try Level3Decoder.decode(data, product: p) }.value
    }
}
