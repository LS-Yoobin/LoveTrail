import MapKit
import SwiftUI

/// Apple Maps view for picking a place by tapping POIs or the map (adapted from fastblog TappableMapView).
struct MemoryLocationMapView: UIViewRepresentable {
    let center: CLLocationCoordinate2D
    var title: String?
    var spanMeters: CLLocationDistance = 350
    var showsPin: Bool = true
    var showsUserLocation: Bool = false
    var onTap: (CLLocationCoordinate2D, MKCoordinateRegion) -> Void
    var onMapFeatureTap: (MKMapFeatureAnnotation, MKCoordinateRegion, @escaping () -> Void) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: spanMeters,
            longitudinalMeters: spanMeters
        )
        map.mapType = .standard
        map.showsUserLocation = showsUserLocation
        map.selectableMapFeatures = [.pointsOfInterest]

        if showsPin {
            let pin = MKPointAnnotation()
            pin.coordinate = center
            map.addAnnotation(pin)
        }

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let ctx = context.coordinator
        mapView.showsUserLocation = showsUserLocation

        if !coordinatesAreNear(ctx.lastRecenteredCenter, center, thresholdMeters: 20)
            || ctx.lastSpanMeters != spanMeters {
            mapView.setRegion(
                MKCoordinateRegion(center: center, latitudinalMeters: spanMeters, longitudinalMeters: spanMeters),
                animated: ctx.hasRecenteredOnce
            )
            ctx.lastRecenteredCenter = center
            ctx.lastSpanMeters = spanMeters
            ctx.hasRecenteredOnce = true
        }

        syncPin(on: mapView, context: ctx)
    }

    private func syncPin(on mapView: MKMapView, context ctx: Coordinator) {
        let existingPin = mapView.annotations.first(where: { $0 is MKPointAnnotation }) as? MKPointAnnotation

        if showsPin {
            let pin: MKPointAnnotation
            if let existingPin {
                pin = existingPin
            } else {
                pin = MKPointAnnotation()
                pin.coordinate = center
                mapView.addAnnotation(pin)
            }
            if pin.coordinate.latitude != center.latitude || pin.coordinate.longitude != center.longitude {
                UIView.animate(withDuration: 0.25) {
                    pin.coordinate = center
                }
            }
            pin.title = title
            if let title, !title.isEmpty {
                mapView.selectAnnotation(pin, animated: true)
            } else {
                mapView.deselectAnnotation(pin, animated: true)
            }
        } else if let existingPin {
            mapView.removeAnnotation(existingPin)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func coordinatesAreNear(
        _ a: CLLocationCoordinate2D?,
        _ b: CLLocationCoordinate2D,
        thresholdMeters: CLLocationDistance
    ) -> Bool {
        guard let a else { return false }
        let locA = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let locB = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return locA.distance(from: locB) < thresholdMeters
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        let parent: MemoryLocationMapView
        var lastRecenteredCenter: CLLocationCoordinate2D?
        var lastSpanMeters: CLLocationDistance?
        var hasRecenteredOnce = false
        private var pendingBareMapTap: DispatchWorkItem?

        init(_ parent: MemoryLocationMapView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended,
                  let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            pendingBareMapTap?.cancel()
            let region = mapView.region
            let work = DispatchWorkItem { [weak self] in
                self?.parent.onTap(coordinate, region)
            }
            pendingBareMapTap = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            if let feature = annotation as? MKMapFeatureAnnotation {
                guard feature.featureType == .pointOfInterest else {
                    mapView.deselectAnnotation(annotation, animated: false)
                    return
                }
                pendingBareMapTap?.cancel()
                pendingBareMapTap = nil
                let endSelection: () -> Void = { [weak mapView] in
                    guard let mapView else { return }
                    mapView.deselectAnnotation(feature, animated: false)
                }
                parent.onMapFeatureTap(feature, mapView.region, endSelection)
                return
            }
            if annotation is MKPointAnnotation {
                pendingBareMapTap?.cancel()
                pendingBareMapTap = nil
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is MKPointAnnotation else { return nil }
            let id = "Pin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.markerTintColor = UIColor(BabyTownTheme.accent)
            view.glyphImage = UIImage(systemName: "mappin.circle.fill")
            view.canShowCallout = true
            return view
        }
    }
}
