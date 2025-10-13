//
//  LocationController.swift
//  VSMap
//
//  Created by Hripsime on 2022-02-13.
//

import Foundation
import CoreLocation
import VSFoundation
import MapboxMaps

class LocationController: ILocation {
    let tag = "LocationController"
    // MARK: ILocation properties
    public var userMarkVisibility: UserMarkVisibility
    public var position: CLLocation?
    
    // MARK: LocationProvider properties
    public var locationProviderOptions = LocationOptions()
    public var authorizationStatus: CLAuthorizationStatus
    public var accuracyAuthorization: CLAccuracyAuthorization
    public var heading: CLHeading?
    public var headingOrientation: CLDeviceOrientation
    
//    weak var delegate: LocationProviderDelegate?

    weak var locationObserver: LocationObserver?
    weak var headingObserver: HeadingObserver?

    private let converter: ICoordinateConverter
    private let mapOptions: VSFoundation.MapOptions

    public init(coordinateConverter: ICoordinateConverter, mapOptions: VSFoundation.MapOptions) {
        self.converter = coordinateConverter
        self.mapOptions = mapOptions
        userMarkVisibility = .visible
        authorizationStatus = .authorizedAlways
        accuracyAuthorization = .fullAccuracy
        headingOrientation = .portrait
    }

    deinit {
      Logger(verbosity: .info).log(tag: tag, message: "deinit")
    }

    // MARK: ILocation implementation
    var accuracyOverride: Double?
    public func updateUserLocation(newLocation: CLLocationCoordinate2D, std: Double) {
        let accuracy: Double
        switch mapOptions.userMark.userMarkerType {
        case .bullsEye, .custom(_): accuracy = max(1.5, std * 1.645)
        case .heading: accuracy = max(5.0, min(7.0, std * 1.645))
        case .accuracy: accuracy = max(1.5, min(5.0, std * 1.645))//1.5
        //case .accuracy: accuracy = std
        }
        let location = CLLocation(
          coordinate: newLocation,
          altitude: 0.0,
          horizontalAccuracy: CLLocationAccuracy(converter.convertFromMetersToMapMeters(input: accuracyOverride ?? accuracy)),
          verticalAccuracy: 0.0,
          timestamp: Date()
        )

        locationObserver?.onLocationUpdateReceived(for: [.init(clLocation: location)])
    }

    public func updateUserLocation(location: VPSOutputSignal.LatLngPosition.Location) {
        let location = CLLocation(
          coordinate: location.coordinate,
          altitude: location.altitude ?? 0.0,
          horizontalAccuracy: location.accuracy ?? 0.0,
          verticalAccuracy: 1.0,
          timestamp: Date()
        )

        locationObserver?.onLocationUpdateReceived(for: [.init(clLocation: location)])
    }
  
    public func updateUserLocation(latLng: VPSOutputSignal.LatLngPosition) {
        let location: CLLocation
        switch latLng.reliableSource {
        case .gps, .undefined:
          location = CLLocation(
            coordinate: latLng.gpsLocation.coordinate,
            altitude: latLng.gpsLocation.altitude ?? 0.0,
            horizontalAccuracy: latLng.gpsLocation.accuracy ?? 0.0,
            verticalAccuracy: 1.0,
            timestamp: Date()
          )
        case .vpsML:
          location = CLLocation(
            coordinate: latLng.mlLocation.coordinate,
            altitude: latLng.mlLocation.altitude ?? 0.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 1.0,
            timestamp: Date()
          )
        }

        locationObserver?.onLocationUpdateReceived(for: [.init(clLocation: location)])
    }

    public func updateUserDirection(newDirection: Double) {
        let heading = TT2CLHeading()
        heading._trueHeading = newDirection
        heading._magneticHeading = newDirection
        self.heading = heading
        headingObserver?.onHeadingUpdate(.init(direction: newDirection, accuracy: .zero, timestamp: .init()))
    }
    
    public func reset() { }
    
    // MARK: LocationeProvider implementation
    public func requestAlwaysAuthorization() { }
    
    public func requestWhenInUseAuthorization() {
        authorizationStatus = .notDetermined
        accuracyAuthorization = .fullAccuracy
    }
    
    public func requestTemporaryFullAccuracyAuthorization(withPurposeKey purposeKey: String) { }
    
    public func startUpdatingLocation() { }
    
    public func stopUpdatingLocation() { }
    
    public func startUpdatingHeading() {}
    
    public func stopUpdatingHeading() { }
    
    public func dismissHeadingCalibrationDisplay() { }
    
    func setOptions(options: LocationOptions) {
        self.locationProviderOptions = options
    }
}

extension LocationController: LocationProvider {
  func addLocationObserver(for observer: LocationObserver) {
    locationObserver = observer
  }

  func removeLocationObserver(for observer: LocationObserver) {
    locationObserver = nil
  }

  func getLastObservedLocation() -> Location? {
    // TODO: Do
    return nil
  }
}

extension LocationController: HeadingProvider {
  var latestHeading: MapboxMaps.Heading? {
    guard let heading = heading else { return nil }
    return .init(direction: heading.headingDirection, accuracy: heading.headingAccuracy)
  }
  
  func add(headingObserver: HeadingObserver) {
    self.headingObserver = headingObserver
  }
  
  func remove(headingObserver: HeadingObserver) {
    self.headingObserver = nil
  }
}
