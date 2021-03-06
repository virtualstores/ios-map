//
//  CameraModes.swift
//  VSMap
//
//  Created by Hripsime on 2022-02-16.
//

import Foundation
import CoreGraphics
import CoreLocation
@_implementationOnly import MapboxMaps
import VSFoundation

/// CameraMode protacol which will be used for creating any type of mode
protocol CameraMode {
    var rtlsOptions: RtlsOptions? { get }
    
    func reset()
    func onEnter()
    func onLocationLost()
    func onLocationUpdated(newLocation: CLLocationCoordinate2D, direction: Double)
    func calculateMapEdge(centerCoordinate: CLLocationCoordinate2D, padding: Double?) -> CoordinateBounds?
}

internal extension CameraMode {
    func reset() {}
    
    func onEnter() {}
    
    func onLocationLost() {}
    
    func onLocationUpdated(newLocation: CLLocationCoordinate2D, direction: Double) { }
    
    func calculateMapEdge(centerCoordinate: CLLocationCoordinate2D, padding: Double? = nil) -> CoordinateBounds? {
        guard let rtlsOptions = rtlsOptions else { return nil }

        let factor = 1.0 //1.0 / TT2Position.pixelsPerMeterFactor
        let padding = 11.1 //TT2.shared.converter.convertToMapCoordinate(padding ?? store.mapOptions.camera.cameraModePadding)

        let height = rtlsOptions.heightInMeters * factor
        let width = rtlsOptions.widthInMeters * factor

        var west = centerCoordinate.longitude - padding
        var east = centerCoordinate.longitude + padding
        var north = centerCoordinate.latitude + padding
        var south = centerCoordinate.latitude - padding
        
        if west < 0 {
            east = east - west
            west = 0.0 - 0.05
        }
        
        if east > width {
            west = west + (width - east)
            east = width + 0.05
        }
        
        if south < 0.0 {
            north = north - south
            south = 0.0 + (padding * 0.4)
        } else if south < padding / 2 {
            north = north - south
            south = 0.0
        }
        
        if north > height {
            south = south + (height - north)
            north = height
        }
        
        let bounds = CoordinateBounds(
            southwest: CLLocationCoordinate2D(latitude: south, longitude: west),
            northeast: CLLocationCoordinate2D(latitude: north, longitude: east)
        )
        
        return bounds
    }
}

// MARK: FreeMode
internal class FreeMode: CameraMode {
    public var rtlsOptions: RtlsOptions?
    
    public init() {
    }
}

// MARK: ContainMapMode
internal class ContainMapMode: CameraMode {
    var rtlsOptions: RtlsOptions?
    
    public init() { }
    
    func onEnter() {
        //resetCameraToMapMode
    }
}

// MARK: ThreeDimensionalMode
internal class ThreeDimensionalMode: CameraMode {
    let mapView: MapView
    var rtlsOptions: RtlsOptions?
    let zoomLevel: Double
    let degree: Double
    let lastLocation: CLLocationCoordinate2D

    init(mapView: MapView, zoomLevel: Double, degree: Double, location: CLLocationCoordinate2D) {
        self.mapView = mapView
        self.zoomLevel = zoomLevel
        self.degree = degree
        self.lastLocation = location
    }
    
    func onEnter() {
        self.moveCameraToUser()
    }
    
    func onLocationUpdated(newLocation: CLLocationCoordinate2D) {
        self.moveCameraToUser()
    }
    
    func onLocationUpdated(newLocation: CLLocationCoordinate2D, direction: Double) {
        let state = CameraState(center: newLocation, padding: .zero, zoom: 8, bearing: direction, pitch: 25)
        self.mapView.mapboxMap.setCamera(to: CameraOptions(cameraState: state))
    }
    
    private func moveCameraToUser() {
        var camera = self.mapView.cameraState
        
        camera.center = lastLocation
        camera.pitch = 25
        
        camera.bearing = degree < 0 ? 360 + degree : degree

        if camera.zoom != self.zoomLevel {
            camera.zoom = self.zoomLevel
        }
        
        DispatchQueue.main.async {
            self.mapView.camera.ease(to: CameraOptions(cameraState: camera), duration: 0.1)
        }
    }
}
