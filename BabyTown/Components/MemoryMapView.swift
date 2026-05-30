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

        // App-controlled clustering only (no native MapKit clustering): register the
        // individual pin and the count marker under their own identifiers.
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
        // We cluster ourselves at the current span instead of relying on MapKit's automatic
        // clustering, which re-evaluates (and visibly reshuffles) whenever annotations are
        // added. Recomputing here means a filter change just adds/removes the delta of plain
        // pins/clusters, and grouping only changes when the span changes (i.e. the user zooms).
        let displayAnnotations = clusterMemoryAnnotations(annotations, span: region.span)

        let currentManaged = uiView.annotations.filter {
            $0 is MemoryMapAnnotation || $0 is MemoryClusterAnnotation
        }
        let currentIDs = Set(currentManaged.compactMap(memoryMapAnnotationID))
        let newIDs = Set(displayAnnotations.compactMap(memoryMapAnnotationID))

        if currentIDs != newIDs {
            let toRemove = currentManaged.filter {
                guard let id = memoryMapAnnotationID($0) else { return false }
                return !newIDs.contains(id)
            }
            let toAdd = displayAnnotations.filter {
                guard let id = memoryMapAnnotationID($0) else { return false }
                return !currentIDs.contains(id)
            }
            uiView.removeAnnotations(toRemove)
            uiView.addAnnotations(toAdd)
        }
        
        // Update region if it's significantly different
        let currentRegion = uiView.region
        let regionChanged = abs(currentRegion.center.latitude - region.center.latitude) > 0.001 ||
                           abs(currentRegion.center.longitude - region.center.longitude) > 0.001 ||
                           abs(currentRegion.span.latitudeDelta - region.span.latitudeDelta) > 0.001
        
        if regionChanged {
            uiView.setRegion(region, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MemoryMapView
        
        init(_ parent: MemoryMapView) {
            self.parent = parent
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
        
        // Apple Maps POI features have no custom annotation view, so the
        // view-based didSelect never fires for them — the annotation-based
        // variant does, and it also fires for our pins and clusters.
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
                mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 80, left: 80, bottom: 80, right: 80), animated: true)
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
    }
}
