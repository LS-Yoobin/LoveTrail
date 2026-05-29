import SwiftUI
import MapKit

struct MemoryMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var annotations: [MemoryMapAnnotation]
    var onSelect: (DaySection) -> Void
    var isInteractive: Bool = true
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isScrollEnabled = isInteractive
        mapView.isZoomEnabled = isInteractive
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        
        // Enable clustering
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        
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
            guard let memoryAnnotation = annotation as? MemoryMapAnnotation else { return nil }
            
            let identifier = "MemoryPin"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if view == nil {
                view = MKMarkerAnnotationView(annotation: memoryAnnotation, reuseIdentifier: identifier)
                view?.canShowCallout = false
            } else {
                view?.annotation = memoryAnnotation
            }
            
            // Clustering logic
            view?.clusteringIdentifier = "memoryCluster"
            view?.displayPriority = .required
            view?.markerTintColor = UIColor(red: 1.0, green: 0.4, blue: 0.5, alpha: 1.0) // BabyTown accent color
            view?.glyphImage = UIImage(systemName: "heart.fill")
            
            return view
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard parent.isInteractive else {
                mapView.deselectAnnotation(view.annotation, animated: false)
                return
            }
            if let annotation = view.annotation as? MemoryMapAnnotation {
                parent.onSelect(annotation.section)
                mapView.deselectAnnotation(annotation, animated: true)
            } else if let cluster = view.annotation as? MKClusterAnnotation {
                // If it's a cluster, zoom in
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
