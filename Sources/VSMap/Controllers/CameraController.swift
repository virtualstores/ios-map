//
//  CameraController.swift
//  VSMap
//
//  Created by Hripsime on 2022-02-16.
//

import Foundation
import CoreGraphics
import VSFoundation
import MapboxMaps
import SwiftUI

class CameraController: ICameraController {
    let tag = "CameraController"
    var requestedCameraMode: CameraModes?
    var actualCameraMode: CameraMode? {
        didSet {
            actualCameraMode?.onEnter()
        }
    }
    
    private var mapView: MapView
    @Inject var mapRepository: MapRepository
    private var rtlsOptions: RtlsOptions?
    private var lastLocation: Location?
    private var revertCameraModeTimer: Timer?
    private var revertCameraInterval = 4.0
    private var overrideCameramode: CameraModes?
    private var getCameraMode: CameraModes? { overrideCameramode ?? requestedCameraMode }

    public init(mapView: MapView) {
        self.mapView = mapView
        if defaultCamera == nil {
            createCamera()
        }
    }

    deinit {
        print("\(tag).deinit")
        defaultCamera = nil
    }

    func setInitialCameraMode(for mode: CameraModes) {
        createCameraMode(for: mode)
    }
    
    public func updateLocation(with newLocation: CLLocationCoordinate2D, direction: Double, std: Double) {
        actualCameraMode?.onLocationUpdated(newLocation: newLocation, direction: direction, std: std)
    }
    
    public func updateCameraMode(with mode: CameraModes) {
        guard requestedCameraMode != mode else { return }
        requestedCameraMode = mode
        createCameraMode(for: overrideCameramode ?? mode)
    }
    
    public func setAutoCameraResetDelay(with milliseconds: Double) {
        revertCameraInterval = milliseconds
    }
    
    public func resetCameraMode() {
        actualCameraMode?.reset()
        resetCameraToMapMode()
    }

    func set(override mode: CameraModes?) {
        guard overrideCameramode != mode else { return }
        overrideCameramode = mode
        createCameraMode(for: getCameraMode ?? .free)
        if mode == .followUser3D() { hasFollowedUser = true }
    }

    private(set) var hasFollowedUser = false
    private func createCameraMode(for mode: CameraModes) {
        setCameraBounds(for: mode)
        switch mode {
        case .free:
            self.actualCameraMode = FreeMode()
        case .containMap:
            self.actualCameraMode = ContainMapMode(with: self)
        case .followUser3D(let zoomLevel):
            let rtls = mapRepository.mapData.rtlsOptions
            let squareMeters = rtls.boundingBoxInMeters?.squareMeters ?? rtls.squareMeters
            self.actualCameraMode = FollowUser3D(mapView: mapView, zoomLevel: zoomLevel ?? FollowUser3DOptions().getZoomLevelForArea(mapSquareMeters: squareMeters))
            //mapView.viewport.transition(to: mapView.viewport.makeFollowPuckViewportState(options: FollowPuckViewportStateOptions(zoom: 8, bearing: .heading, pitch: 25)))
        //case .containPoint(let point):
        //  self.actualCameraMode = ContainPoint(mapView: mapView, focusCoordinate: point.fromPixelToLatLng(converter: mapRepository.mapData.converter))
        }
    }
    
    func resetCameraToMapBounds() {
        guard let camera = defaultCamera else {
            createCamera()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.resetCameraToMapBounds() }
            return
        }
        mapView.camera.ease(
          to: mapView.mapboxMap.camera(for: camera.bounds, padding: .zero, bearing: camera.bearing, pitch: 0),
          duration: 0.4
        )
    }
    
    func resetCameraToMapMode() {
        if !(actualCameraMode is ContainMapMode), let cameraMode = getCameraMode {
            self.createCameraMode(for: cameraMode)
        } else {
            self.resetCameraToMapBounds()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.resetCameraToMapBounds()
            }
        }
    }

    var defaultCamera: (bounds: CoordinateBounds, bearing: Double)?
    func createCamera() {
        let rtls = mapRepository.mapData.rtlsOptions
        let converter = mapRepository.mapData.converter

        let width = converter.convertFromMetersToMapCoordinate(input: rtls.widthInMeters)
        let height = converter.convertFromMetersToMapCoordinate(input: rtls.heightInMeters)

        //print("Area", rtls.widthInMeters, rtls.heightInMeters, rtls.widthInMeters * rtls.heightInMeters, rtls.widthInMeters * rtls.heightInMeters / .pi)
        //Area 93.17 112.4 10472.308 3333.439167561601 IKEA delft markethall
        let cameraPadding = converter.convertFromMetersToMapCoordinate(input: 2)
        let cameraBounds: CoordinateBounds
        var bearing: Double = 0.0
        //var bearing: Double = 90.0
        if let boundingBox = rtls.boundingBoxInMeters {
            bearing = rtls.id == 76 ? 90 : 0
            var padding = bearing != 0 ? boundingBox.padding.multiply(with: 10) : boundingBox.padding
            if rtls.widthInMeters > rtls.heightInMeters && bearing == 0.0 {
                padding = padding.multiply(width: 12, height: 16)
            }
            let bottomLeft = boundingBox.bottomLeftPoint.add(x: -padding.left, y: -padding.bottom).convertFromMeterToLatLng(converter: converter)
            let topRight = boundingBox.topRightPoint.add(x: padding.right, y: padding.top).convertFromMeterToLatLng(converter: converter)
            cameraBounds = CoordinateBounds(southwest: bottomLeft, northeast: topRight)
        } else if rtls.widthInMeters > rtls.heightInMeters {
            cameraBounds = CoordinateBounds(rect: CGRect(origin: CGPoint(x: 0.0, y: -(height * 1.5)), size: CGSize(width: width, height: height * 4.0))).add(padding: cameraPadding)
        } else if rtls.widthInMeters > (rtls.heightInMeters * 0.6) {
            cameraBounds = CoordinateBounds(rect: CGRect(origin: CGPoint(x: 0.0, y: -(height * 0.8)), size: CGSize(width: width, height: height * 2.5))).add(padding: cameraPadding)
        } else {
            cameraBounds = CoordinateBounds(rect: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: height))).add(padding: cameraPadding)
        }
        defaultCamera = (cameraBounds, bearing)
    }

    func setCameraBounds(for mode: CameraModes) {
        let bounds: CoordinateBounds?
        switch mode {
        case .containMap, .free: bounds = defaultCamera?.bounds
        case .followUser3D(_)/*, .containPoint(_)*/: bounds = CoordinateBounds(southwest: CLLocationCoordinate2D(latitude: -90, longitude: -180), northeast: CLLocationCoordinate2D(latitude: 90, longitude: 180))
        }
        try? mapView.mapboxMap.setCameraBounds(with: createCameraBoundsOptions(bounds: bounds))
    }

    func createCameraBoundsOptions(bounds: CoordinateBounds?) -> CameraBoundsOptions {
        let options = mapRepository.mapOptions.mapStyle
        return CameraBoundsOptions(bounds: bounds, maxZoom: options.maxZoomLevel, minZoom: options.minZoomLevel)
    }

    private func revertCameraModeAfter(interval: Double) {
        self.revertCameraModeTimer?.invalidate()
        self.revertCameraModeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false, block: { [weak self] (_) in
            guard let self = self, let mode = getCameraMode else { return }

            createCameraMode(for: mode)
            revertCameraModeTimer?.invalidate()
            revertCameraModeTimer = nil
        })
    }

    func reset() {
      hasFollowedUser = false
    }
}

extension CameraController: LocationConsumer {
    public func locationUpdate(newLocation: Location) {
        self.lastLocation = newLocation
    }
}

extension CameraController: GestureManagerDelegate {
    public func gestureManager(_ gestureManager: GestureManager, didBegin gestureType: GestureType) {
        self.createCameraMode(for: .free)
        self.revertCameraModeTimer?.invalidate()
//        Logger.init(verbosity: .debug).log(message: "didBegin")
    }
    
    public func gestureManager(_ gestureManager: GestureManager, didEnd gestureType: GestureType, willAnimate: Bool) {
        self.revertCameraModeAfter(interval: revertCameraInterval)
//        Logger.init(verbosity: .debug).log(message: "didEnd")
    }
    
    public func gestureManager(_ gestureManager: GestureManager, didEndAnimatingFor gestureType: GestureType) {
//        Logger.init(verbosity: .debug).log(message: "didEndAnimatingFor")
    }
}

extension CoordinateBounds {
    func add(padding: Double) -> CoordinateBounds {
        CoordinateBounds(
            southwest: CLLocationCoordinate2D(latitude: southwest.latitude - padding, longitude: southwest.longitude - padding),
            northeast: CLLocationCoordinate2D(latitude: northeast.latitude + padding, longitude: northeast.longitude + padding)
        )
    }
}

extension RtlsOptions {
  var squareMeters: Double { widthInMeters * heightInMeters }
}

extension RtlsOptions.BoundingBox {
  var squareMeters: Double {
    let width = bottomLeftPoint.distance(to: bottomRightPoint)
    let height = bottomLeftPoint.distance(to: topLeftPoint)
    return width * height
  }
}
