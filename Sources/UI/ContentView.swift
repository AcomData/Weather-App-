import SwiftUI

struct ContentView: View {
    @StateObject private var vm = RadarViewModel()
    @State private var panelOpen = true

    var body: some View {
        ZStack {
            RadarMapView(vm: vm).ignoresSafeArea()
            VStack(spacing: 8) {
                StatusBar(vm: vm)
                HStack {
                    Spacer()
                    LegendView(product: vm.product)
                }
                Spacer()
                Button {
                    withAnimation { panelOpen.toggle() }
                } label: {
                    Image(systemName: panelOpen ? "chevron.down" : "slider.horizontal.3")
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                if panelOpen { ControlPanel(vm: vm) }
            }
            .padding(8)
        }
        .onAppear { vm.start() }
        .onChange(of: vm.site) { _ in vm.siteChanged() }
        .onChange(of: vm.level) { _ in vm.levelChanged() }
        .onChange(of: vm.product) { _ in vm.reload() }
        .onChange(of: vm.tilt) { _ in vm.reload() }
    }
}

struct StatusBar: View {
    @ObservedObject var vm: RadarViewModel

    private var timeText: String {
        guard let t = vm.scanTime else { return "—" }
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "d MMM HH:mm'Z'"
        let mins = Int(Date().timeIntervalSince(t) / 60)
        return "\(f.string(from: t)) (\(mins) min ago)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(vm.site.id).font(.headline)
                Text(vm.site.name).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if vm.isLoading { ProgressView().scaleEffect(0.8) }
            }
            HStack(spacing: 10) {
                Label(vm.vcp.map { "VCP \($0)" } ?? "VCP —", systemImage: "dot.radiowaves.left.and.right")
                if let e = vm.elevation { Text(String(format: "%.2f°", e)) }
                Text(vm.level.rawValue)
                Text(vm.product.title)
            }.font(.caption.monospacedDigit())
            Text(timeText).font(.caption2).foregroundStyle(.secondary)
            if !vm.status.isEmpty { Text(vm.status).font(.caption2).foregroundStyle(.orange) }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct LegendView: View {
    let product: RadarProduct
    var body: some View {
        let cmap = product.colorMap
        if let (lo, hi) = cmap.legendRange {
            VStack(spacing: 2) {
                Text(product.unit).font(.caption2)
                Text(fmt(hi)).font(.caption2.monospacedDigit())
                LinearGradient(stops: cmap.legendStops.reversed().map {
                    Gradient.Stop(color: $0.color, location: 1 - $0.location)
                }, startPoint: .top, endPoint: .bottom)
                    .frame(width: 14, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Text(fmt(lo)).font(.caption2.monospacedDigit())
            }
            .padding(6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
    private func fmt(_ v: Float) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v) }
}

struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.caption.weight(.medium))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(selected ? Color.accentColor : Color.gray.opacity(0.25), in: Capsule())
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
    }
}

struct ControlPanel: View {
    @ObservedObject var vm: RadarViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Site", selection: $vm.site) {
                    ForEach(NexradSites.all) { Text("\($0.id) – \($0.name)").tag($0) }
                }.pickerStyle(.menu)
                Button { vm.selectNearest() } label: { Image(systemName: "location.magnifyingglass") }
                Button { vm.reload() } label: { Image(systemName: "arrow.clockwise") }
                Spacer()
                Picker("Level", selection: $vm.level) {
                    ForEach(RadarViewModel.DataLevel.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(width: 170)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(vm.availableProducts) { p in
                        Chip(title: p.title, selected: vm.product == p) { vm.product = p }
                    }
                }
            }

            if !vm.tiltOptions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Text("Tilt").font(.caption).foregroundStyle(.secondary)
                        ForEach(vm.tiltOptions) { t in
                            Chip(title: t.label, selected: vm.activeTilt == t.id) { vm.tilt = t.id }
                        }
                    }
                }
            }

            HStack {
                Image(systemName: "circle.lefthalf.filled")
                Slider(value: $vm.opacity, in: 0.2...1)
                Image(systemName: "view.3d")
                Slider(value: $vm.pitch, in: 0...60)
            }

            HStack {
                Picker("Satellite", selection: $vm.satellite) {
                    ForEach(SatelliteLayer.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.menu)
                Spacer()
                Picker("Map", selection: $vm.mapStyle) {
                    ForEach(MapStyle.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.menu)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
