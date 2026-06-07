import SwiftUI
import MapKit

struct MemoryMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var annotations: [MemoryMapAnnotation]
    var onSelect: (DaySection) -> Void
    var isInteractive: Bool = true
    var onSelectPOI: (_ title: String, _ coordinate: CLLocationCoordinate2D) -> Void = { _, _ in }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isScrollEnabled = isInteractive
        mapView.isZoomEnabled = isInteractive
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.selectableMapFeatures = [.pointsOfInterest]

        mapView.register(
            MemoryPhotoMarkerView.self,
            forAnnotationViewWithReuseIdentifier: "MemoryPin"
        )
        mapView.register(
            MemoryMapMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: "MemoryCluster"
        )

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.scheduleSourceAnnotationSync(annotations, on: uiView)

        if coordinator.shouldApplyBindingRegion(region) {
            coordinator.isProgrammaticRegionChange = true
            uiView.setRegion(sanitizedMapRegion(region), animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MemoryMapView
        private var sourceAnnotations: [MemoryMapAnnotation] = []
        private var sourceAnnotationIDs: Set<String> = []
        private var lastClusteredSpan: MKCoordinateSpan?
        private var lastAppliedBindingRegion: MKCoordinateRegion?
        private var syncTask: Task<Void, Never>?
        private var clusteringTask: Task<Void, Never>?
        var isProgrammaticRegionChange = false

        private let annotationBatchSize = 25

        init(_ parent: MemoryMapView) {
            self.parent = parent
        }

        func scheduleSourceAnnotationSync(_ annotations: [MemoryMapAnnotation], on mapView: MKMapView) {
            let newIDs = Set(annotations.map(\.id))
            guard newIDs != sourceAnnotationIDs else { return }

            syncTask?.cancel()
            syncTask = Task { @MainActor in
                await Task.yield()
                guard !Task.isCancelled else { return }

                sourceAnnotations = annotations
                sourceAnnotationIDs = newIDs
                await applyClustering(on: mapView, span: mapView.region.span)
            }
        }

        func shouldApplyBindingRegion(_ region: MKCoordinateRegion) -> Bool {
            guard let last = lastAppliedBindingRegion else {
                lastAppliedBindingRegion = region
                return true
            }

            let centerChanged =
                abs(last.center.latitude - region.center.latitude) > 0.001 ||
                abs(last.center.longitude - region.center.longitude) > 0.001
            let spanChanged =
                abs(last.span.latitudeDelta - region.span.latitudeDelta) > 0.001 ||
                abs(last.span.longitudeDelta - region.span.longitudeDelta) > 0.001

            guard centerChanged || spanChanged else { return false }
            lastAppliedBindingRegion = region
            return true
        }

        private func applyClustering(on mapView: MKMapView, span: MKCoordinateSpan) async {
            clusteringTask?.cancel()
            let displayAnnotations = clusterMemoryAnnotations(sourceAnnotations, span: span)
            lastClusteredSpan = span

            let currentManaged = mapView.annotations.filter {
                $0 is MemoryMapAnnotation || $0 is MemoryClusterAnnotation
            }
            let currentIDs = Set(currentManaged.compactMap(memoryMapAnnotationID))
            let newIDs = Set(displayAnnotations.compactMap(memoryMapAnnotationID))

            guard currentIDs != newIDs else { return }

            let toRemove = currentManaged.filter {
                guard let id = memoryMapAnnotationID($0) else { return false }
                return !newIDs.contains(id)
            }
            let toAdd = displayAnnotations.filter {
                guard let id = memoryMapAnnotationID($0) else { return false }
                return !currentIDs.contains(id)
            }

            mapView.removeAnnotations(toRemove)

            guard !toAdd.isEmpty else { return }

            clusteringTask = Task { @MainActor in
                for start in stride(from: 0, to: toAdd.count, by: annotationBatchSize) {
                    guard !Task.isCancelled else { return }
                    let end = min(start + annotationBatchSize, toAdd.count)
                    mapView.addAnnotations(Array(toAdd[start..<end]))
                    if end < toAdd.count {
                        await Task.yield()
                    }
                }
            }
            await clusteringTask?.value
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MemoryClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: "MemoryCluster",
                    for: annotation
                ) as? MemoryMapMarkerAnnotationView
                    ?? MemoryMapMarkerAnnotationView(annotation: annotation, reuseIdentifier: "MemoryCluster")
                view.annotation = annotation
                return view
            } else if annotation is MemoryMapAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: "MemoryPin",
                    for: annotation
                ) as? MemoryPhotoMarkerView
                    ?? MemoryPhotoMarkerView(annotation: annotation, reuseIdentifier: "MemoryPin")
                view.annotation = annotation
                return view
            }
            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard parent.isInteractive else {
                mapView.deselectAnnotation(annotation, animated: false)
                return
            }
            if let feature = annotation as? MKMapFeatureAnnotation {
                parent.onSelectPOI(feature.title ?? "", feature.coordinate)
                mapView.deselectAnnotation(feature, animated: false)
            } else if let annotation = annotation as? MemoryMapAnnotation {
                parent.onSelect(annotation.section)
                mapView.deselectAnnotation(annotation, animated: true)
            } else if let cluster = annotation as? MemoryClusterAnnotation {
                mapView.deselectAnnotation(cluster, animated: false)
                let rect = cluster.members.reduce(MKMapRect.null) { rect, member in
                    let point = MKMapPoint(member.coordinate)
                    return rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
                }
                isProgrammaticRegionChange = true
                mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 80, left: 80, bottom: 80, right: 80), animated: true)
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            if isProgrammaticRegionChange {
                isProgrammaticRegionChange = false
                let span = mapView.region.span
                guard mapSpanChangedSignificantly(from: lastClusteredSpan, to: span) else { return }
                clusteringTask = Task { @MainActor in
                    await applyClustering(on: mapView, span: span)
                }
                return
            }

            let span = mapView.region.span
            guard mapSpanChangedSignificantly(from: lastClusteredSpan, to: span) else { return }
            clusteringTask = Task { @MainActor in
                await applyClustering(on: mapView, span: span)
            }
        }
    }
}
