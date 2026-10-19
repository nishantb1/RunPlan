import SwiftUI
import MapKit
// SwiftUI's Map lives in this cross-import overlay; xtool's build does not pull it in on its own.
import _MapKit_SwiftUI
import RunCore

/// A run's route as orange lines on a zoom-only map, so a drag scrolls the surrounding list
/// instead of panning. The line breaks at each pause. Coordinates are converted in `init`, not
/// on every redraw of the map.
struct RouteMap: View {
    private let segments: [[CLLocationCoordinate2D]]

    init(route: [RoutePoint]) {
        segments = route.segments
            .filter { $0.count > 1 }
            .map { segment in segment.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) } }
    }

    var body: some View {
        Map(initialPosition: .automatic, interactionModes: [.zoom]) {
            ForEach(segments.indices, id: \.self) { index in
                MapPolyline(coordinates: segments[index])
                    .stroke(.orange, lineWidth: 4)
            }
        }
        .accessibilityLabel("Route map")
    }
}
