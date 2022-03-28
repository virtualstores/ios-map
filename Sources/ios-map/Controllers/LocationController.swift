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

class LocationController: ILocation, LocationProvider {
    // MARK: ILocation properties
    public var userMarkVisibility: UserMarkVisibility
    public var position: CLLocation?
    
    // MARK: LocationProvider properties
    public var locationProviderOptions = LocationOptions()
    public var authorizationStatus: CLAuthorizationStatus
    public var accuracyAuthorization: CLAccuracyAuthorization
    public var heading: CLHeading?
    public var headingOrientation: CLDeviceOrientation
    
    weak var delegate: LocationProviderDelegate?
    
    public init() {
        userMarkVisibility = .visible
        authorizationStatus = .authorizedAlways
        accuracyAuthorization = .fullAccuracy
        headingOrientation = .portrait
    }
    
    // MARK: ILocation implementation
    public func updateUserLocation(newLocation: CLLocationCoordinate2D, std: Float?) {
        guard let std = std else { return }
        
        // The CGPoint here is converted to LatLng, where x = lat, y = lng
        let accuracy = CLLocationAccuracy(Float(std * 1.645))
        
        let location = CLLocation(coordinate: newLocation, altitude: 1.0, horizontalAccuracy: 3000 * accuracy, verticalAccuracy: 1.0, timestamp: Date())
        
        delegate?.locationProvider(self, didUpdateLocations: [location])
    }
    
    public func updateUserDirection(newDirection: Double) {
        let heading = TT2CLHeading()
        heading._trueHeading = newDirection
        heading._magneticHeading = newDirection
        self.heading = heading
        delegate?.locationProvider(self, didUpdateHeading: heading)
    }
    
    public func reset() { }
    
    // MARK: LocationeProvider implementation
    public func setDelegate(_ delegate: LocationProviderDelegate) {
        self.delegate = delegate
    }
    
    public func requestAlwaysAuthorization() { }
    
    public func requestWhenInUseAuthorization() {
        authorizationStatus = .notDetermined
        accuracyAuthorization = .fullAccuracy
        delegate?.locationProviderDidChangeAuthorization(self)
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

// MARK: LocationProviderDelegate
extension LocationController: LocationProviderDelegate {
    public func locationProvider(_ provider: LocationProvider, didUpdateLocations locations: [CLLocation]) {
        Logger.init().log(message: "locationProvider didUpdateLocations")
    }
    
    public func locationProvider(_ provider: LocationProvider, didUpdateHeading newHeading: CLHeading) {
        Logger.init().log(message: "locationProvider didUpdateHeading")
    }
    
    public func locationProvider(_ provider: LocationProvider, didFailWithError error: Error) {
        Logger.init().log(message: "locationProvider didFailWithError")
    }
    
    public func locationProviderDidChangeAuthorization(_ provider: LocationProvider) {
        Logger.init().log(message: "locationProvider didFailWithError")
    }
}
