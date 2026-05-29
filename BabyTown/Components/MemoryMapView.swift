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

        // Enable clustering
        mapView.register(
            MemoryMapMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier
        )
        mapView.register(
            MemoryMapMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier
        )
        mapView.register(MemoryMapMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "MemoryPin")
        mapView.register(MemoryMapMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "MemoryCluster")
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Update annotations if they've changed
        let currentAnnotations = uiView.annotations.compactMap { $0 as? MemoryMapAnnotation }
        
        if currentAnnotations.count != annotations.count || 
           Set(currentAnnotations.map { $0.id }) != Set(annotations.map { $0.id }) {
            uiView.removeAnnotations(uiView.annotations)
            uiView.addAnnotations(annotations)
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
            let isCluster = annotation is MKClusterAnnotation
            guard isCluster || annotation is MemoryMapAnnotation else { return nil }

            let identifier = isCluster ? "MemoryCluster" : "MemoryPin"
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: identifier,
                for: annotation
            ) as? MemoryMapMarkerAnnotationView
                ?? MemoryMapMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            view.annotation = annotation
            return view
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard parent.isInteractive else {
                mapView.deselectAnnotation(view.annotation, animated: false)
                return
            }
            if let feature = view.annotation as? MKMapFeatureAnnotation {
                parent.onSelectPOI(feature.title ?? "", feature.coordinate)
                mapView.deselectAnnotation(feature, animated: false)
            } else if let annotation = view.annotation as? MemoryMapAnnotation {
                parent.onSelect(annotation.section)
                mapView.deselectAnnotation(annotation, animated: true)
            } else if let cluster = view.annotation as? MKClusterAnnotation {
                let rect = cluster.memberAnnotations.reduce(MKMapRect.null) { rect, annotation in
                    let point = MKMapPoint(annotation.coordinate)
                    return rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
                }
                mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50), animated: true)
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
    }
}
