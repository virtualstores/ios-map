//
//  CameraModes.swift
//  VSMap
//
//  Created by Hripsime on 2022-02-16.
//

import Foundation
import CoreGraphics
import CoreLocation
import MapboxMaps
import VSFoundation

/// CameraMode protacol which will be used for creating any type of mode
protocol CameraMode {
    var camera: CameraController? { get }
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
    public var camera: CameraController?
    public var rtlsOptions: RtlsOptions?
    
    public init() {}
}

// MARK: ContainMapMode
internal class ContainMapMode: CameraMode {
    var camera: CameraController?
    var rtlsOptions: RtlsOptions?
    
    public init(with camera: CameraController) {
        self.camera = camera
    }
    
    func onEnter() {
        camera?.resetCameraToMapMode()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.camera?.resetCameraToMapMode()
        }
    }
}

// MARK: ThreeDimensionalMode
internal class FollowUser3D: CameraMode {
    let mapView: MapView
    var camera: CameraController?
    var rtlsOptions: RtlsOptions?
    let zoomLevel: Double
    var direction: Double = .zero
    var lastLocation: CLLocationCoordinate2D?

    init(mapView: MapView, zoomLevel: Double) {
        self.mapView = mapView
        self.zoomLevel = zoomLevel
    }
    
    func onEnter() {
        self.moveCameraToUser()
    }
    
    func onLocationUpdated(newLocation: CLLocationCoordinate2D) {
        self.moveCameraToUser()
    }
    
    func onLocationUpdated(newLocation: CLLocationCoordinate2D, direction: Double) {
        self.lastLocation = newLocation
        self.direction = direction
        self.moveCameraToUser()
    }
    
    private func moveCameraToUser() {
        guard let lastLocation = lastLocation else { return }
        var camera = self.mapView.cameraState
        
        camera.center = lastLocation
        camera.pitch = 25
        
        camera.bearing = direction < 0 ? 360 + direction : direction

        if camera.zoom != self.zoomLevel {
            camera.zoom = self.zoomLevel
        }
        
        DispatchQueue.main.async {
            self.mapView.camera.ease(to: CameraOptions(cameraState: camera), duration: 1.1)
        }
    }
}

struct FollowUser3DOptions {
  let zoomLevels: [SquareMeterRange] = [
    SquareMeterRange(range: Range(uncheckedBounds: (0.0, 500.0)), zoomLevel: 8.5),
    SquareMeterRange(range: Range(uncheckedBounds: (501.0, 1000.0)), zoomLevel: 8.0)
  ]
  let defaultZoomLevel: Double = 7.5
  let cameraTilt: Double = 25.0

  func getZoomLevelForArea(mapSquareMeters: Double) -> Double {
    zoomLevels.first(where: { $0.range.contains(mapSquareMeters) })?.zoomLevel ?? defaultZoomLevel
  }

  struct SquareMeterRange {
    let range: Range<Double>
    let zoomLevel: Double
  }
}

class ContainPoint: CameraMode {
  let mapView: MapView
  let focusCoordinate: CLLocationCoordinate2D
  var camera: CameraController?
  var rtlsOptions: RtlsOptions?
  var lastLocation: CLLocationCoordinate2D?

  init(mapView: MapView, focusCoordinate: CLLocationCoordinate2D) {
    self.mapView = mapView
    self.focusCoordinate = focusCoordinate
  }

  func onEnter() {
    showUserAndPoint()
  }

  func onLocationUpdated(newLocation: CLLocationCoordinate2D, direction: Double) {
    lastLocation = newLocation
    showUserAndPoint()
  }

  private func showUserAndPoint() {
    guard let lastLocation = lastLocation else { return }
    let options = mapView.mapboxMap.camera(for: .multiPoint(.init([lastLocation, focusCoordinate])), padding: .init(top: 0.0, left: 0.0, bottom: 0.0, right: 4.0), bearing: 90, pitch: 0)
    //let options = mapView.mapboxMap.camera(for: .init(coordinates: [lastLocation, focusCoordinate]), padding: .zero, bearing: 90, pitch: 0)
    DispatchQueue.main.async {
      self.mapView.camera.ease(to: options, duration: 1)
    }
  }
}
