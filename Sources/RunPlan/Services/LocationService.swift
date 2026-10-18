import CoreLocation
import Observation
import RunCore

/// Wraps CoreLocation for outdoor runs: fitness activity type, best accuracy, and updates that
/// keep coming with the screen locked. Each fix is handed on as a plain `LocationSample`.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {

    private(set) var authorization: CLAuthorizationStatus
    /// True when Precise Location is off, so fixes are too coarse to measure a run.
    private(set) var isReducedAccuracy: Bool
    /// The newest fix, good or bad. The outdoor start sheet watches it to know when GPS is ready.
    private(set) var latest: LocationSample?
    /// Receives every fix while updates are running.
    @ObservationIgnored var onSample: ((LocationSample) -> Void)?

    private let manager: CLLocationManager
    @ObservationIgnored private var isUpdating = false

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorization = manager.authorizationStatus
        self.isReducedAccuracy = manager.accuracyAuthorization == .reducedAccuracy
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
    }

    var needsPermission: Bool { authorization == .notDetermined }
    var isAuthorized: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }
    var isDenied: Bool { authorization == .denied || authorization == .restricted }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Starts updates. The start sheet only needs them in the foreground; a running workout asks
    /// for background updates too, so recording continues with the screen locked. Does nothing
    /// without permission, and is safe to call again (for example to add background updates).
    func start(inBackground: Bool) {
        guard isAuthorized else { return }
        if inBackground, !manager.allowsBackgroundLocationUpdates {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        guard !isUpdating else { return }
        manager.startUpdatingLocation()
        isUpdating = true
    }

    func stop() {
        guard isUpdating else { return }
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        isUpdating = false
        latest = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let reduced = manager.accuracyAuthorization == .reducedAccuracy
        Task { @MainActor in
            self.authorization = status
            self.isReducedAccuracy = reduced
            // CoreLocation stops delivering when permission is withdrawn, so a later start()
            // must not think updates are still running.
            if !self.isAuthorized {
                self.isUpdating = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let samples = locations.map {
            LocationSample(
                latitude: $0.coordinate.latitude,
                longitude: $0.coordinate.longitude,
                timestamp: $0.timestamp,
                horizontalAccuracy: $0.horizontalAccuracy
            )
        }
        Task { @MainActor in
            for sample in samples {
                self.latest = sample
                self.onSample?(sample)
            }
        }
    }
}
