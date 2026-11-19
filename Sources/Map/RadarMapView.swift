import SwiftUI
import MapLibre

struct RadarMapView: UIViewRepresentable {
    @ObservedObject var vm: RadarViewModel

    func makeCoordinator() -> Coordinator { Coordinator(vm) }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: vm.mapStyle.url)
        map.delegate = context.coordinator
        map.setCenter(vm.site.coordinate, zoomLevel: 6.5, animated: false)
        map.allowsTilting = true          // two-finger drag = tilt
        map.allowsRotating = true
        map.showsUserLocation = true
        context.coordinator.map = map
        context.coordinator.appliedStyleURL = vm.mapStyle.url
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        context.coordinator.sync()
    }

    @MainActor
    final class Coordinator: NSObject, MLNMapViewDelegate {
        let vm: RadarViewModel
        weak var map: MLNMapView?
        var appliedStyleURL: URL?
        var styleReady = false
        var lastOverlayID: UUID?
        var lastSatTemplate: String?
        var lastFocus: UUID?

        init(_ vm: RadarViewModel) { self.vm = vm }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            styleReady = true
            lastOverlayID = nil
            lastSatTemplate = nil
            sync()
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            vm.mapCenter = mapView.centerCoordinate
            let p = Double(mapView.camera.pitch)
            if abs(p - vm.pitch) > 1 { DispatchQueue.main.async { self.vm.pitch = p } }
        }

        func sync() {
            guard let map else { return }
            if appliedStyleURL != vm.mapStyle.url {
                appliedStyleURL = vm.mapStyle.url
                styleReady = false
                map.styleURL = vm.mapStyle.url
                return
            }
            if let f = vm.focusRequest, f.id != lastFocus {
                lastFocus = f.id
                map.setCenter(f.coordinate, zoomLevel: 7, animated: true)
            }
            let cam = map.camera
            if abs(Double(cam.pitch) - vm.pitch) > 1 {
                cam.pitch = CGFloat(vm.pitch)
                map.setCamera(cam, animated: true)
            }
            guard styleReady, let style = map.style else { return }
            syncSatellite(style)
            syncRadar(style)
        }

        // Insert below the first label layer so place names stay readable over the data.
        private func insert(_ layer: MLNStyleLayer, style: MLNStyle, below: MLNStyleLayer? = nil) {
            if let below { style.insertLayer(layer, below: below); return }
            if let sym = style.layers.first(where: { $0 is MLNSymbolStyleLayer }) {
                style.insertLayer(layer, below: sym)
            } else {
                style.addLayer(layer)
            }
        }

        private func syncRadar(_ style: MLNStyle) {
            guard let o = vm.overlay else {
                if lastOverlayID != nil {
                    if let l = style.layer(withIdentifier: "radar-layer") { style.removeLayer(l) }
                    if let s = style.source(withIdentifier: "radar-src") { style.removeSource(s) }
                    lastOverlayID = nil
                }
                return
            }
            let quad = MLNCoordinateQuad(topLeft: o.topLeft, bottomLeft: o.bottomLeft,
                                         bottomRight: o.bottomRight, topRight: o.topRight)
            if let src = style.source(withIdentifier: "radar-src") as? MLNImageSource,
               style.layer(withIdentifier: "radar-layer") != nil {
                if o.id != lastOverlayID { src.coordinates = quad; src.image = o.image }
            } else {
                if let l = style.layer(withIdentifier: "radar-layer") { style.removeLayer(l) }
                if let s = style.source(withIdentifier: "radar-src") { style.removeSource(s) }
                let src = MLNImageSource(identifier: "radar-src", coordinateQuad: quad, image: o.image)
                style.addSource(src)
                let layer = MLNRasterStyleLayer(identifier: "radar-layer", source: src)
                layer.rasterFadeDuration = NSExpression(forConstantValue: 0)
                insert(layer, style: style)
            }
            lastOverlayID = o.id
            (style.layer(withIdentifier: "radar-layer") as? MLNRasterStyleLayer)?.rasterOpacity =
                NSExpression(forConstantValue: vm.opacity)
        }

        private func syncSatellite(_ style: MLNStyle) {
            let template = vm.satellite.tileTemplate
            guard template != lastSatTemplate else { return }
            lastSatTemplate = template
            if let l = style.layer(withIdentifier: "sat-layer") { style.removeLayer(l) }
            if let s = style.source(withIdentifier: "sat-src") { style.removeSource(s) }
            guard let template else { return }
            let src = MLNRasterTileSource(identifier: "sat-src", tileURLTemplates: [template],
                                          options: [.tileSize: 256, .maximumZoomLevel: vm.satellite.maxZoom])
            style.addSource(src)
            let layer = MLNRasterStyleLayer(identifier: "sat-layer", source: src)
            // Keep satellite beneath the radar layer.
            insert(layer, style: style, below: style.layer(withIdentifier: "radar-layer"))
        }
    }
}
