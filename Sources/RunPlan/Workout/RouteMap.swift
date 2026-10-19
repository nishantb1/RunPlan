import SwiftUI
import MapKit
// SwiftUI's Map lives in this cross-import overlay; xtool's build does not pull it in on its own.
import _MapKit_SwiftUI
import RunCore

/// A run's route as an orange line on a zoom-only map, so a drag scrolls the surrounding list
/// instead of panning. Coordinates are converted once, when the view is made.
struct RouteMap: View {
    private let coordinates: [CLLocationCoordinate2D]

    init(route: [RoutePoint]) {
        coordinates = route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        Map(initialPosition: .automatic, interactionModes: [.zoom]) {
            MapPolyline(coordinates: coordinates)
                .stroke(.orange, lineWidth: 4)
        }
    }
}
