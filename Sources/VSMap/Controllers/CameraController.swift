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
    public var requestedCameraMode: CameraModes?
    public var actualCameraMode: CameraMode? {
        didSet {
            actualCameraMode?.onEnter()
        }
    }
    
    private var mapView: MapView
    private var mapRepository: MapRepository
    private var rtlsOptions: RtlsOptions?
    private var lastLocation: Location?
    private var revertCameraModeTimer: Timer?
    private var revertCameraInterval = 4.0
    
    public init(mapView: MapView, mapRepository: MapRepository) {
        self.mapView = mapView
        self.mapRepository = mapRepository
    }
    
    func setInitialCameraMode(for mode: CameraModes) {
        createCameraMode(for: mode)
    }
    
    public func updateLocation(with newLocation: CLLocationCoordinate2D, direction: Double) {
        actualCameraMode?.onLocationUpdated(newLocation: newLocation, direction: direction)
    }
    
    public func updateCameraMode(with mode: CameraModes) {
        requestedCameraMode = mode
        createCameraMode(for: mode)
    }
    
    public func setAutoCameraResetDelay(with milliseconds: Double) {
        revertCameraInterval = milliseconds
    }
    
    public func resetCameraMode() {
        actualCameraMode?.reset()
    }
    
    private func createCameraMode(for mode: CameraModes) {
        switch mode {
        case .free:
            self.actualCameraMode = FreeMode()
        case .containMap:
            self.actualCameraMode = ContainMapMode(with: self)
        case .threeDimensional(let zoomLevel):
            let mode =  ThreeDimensionalMode(mapView: mapView, zoomLevel: zoomLevel ?? 8)
            let rtls = mapRepository.mapData.rtlsOptions
            let converter = mapRepository.mapData.converter

            let width = converter.convertFromMetersToMapCoordinate(input: rtls.widthInMeters)
            let height = converter.convertFromMetersToMapCoordinate(input: rtls.heightInMeters)

            let mapBounds = CoordinateBounds(rect: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: height)))
            let cameraPadding = converter.convertFromMetersToMapCoordinate(input: 10)
            let cameraBounds: CoordinateBounds
            let sw = mapBounds.southwest
            let ne = mapBounds.northeast
            cameraBounds = CoordinateBounds(
                southwest: CLLocationCoordinate2D(latitude: sw.latitude - cameraPadding, longitude: sw.longitude - cameraPadding),
                northeast: CLLocationCoordinate2D(latitude: ne.latitude + cameraPadding, longitude: ne.longitude + cameraPadding)
            )
            try? self.mapView.mapboxMap.setCameraBounds(with: CameraBoundsOptions(bounds: cameraBounds, minZoom: 0.0))
            
            self.actualCameraMode = mode
        }
    }
    
    func resetCameraToMapBounds() {
        let rtls = mapRepository.mapData.rtlsOptions
        let converter = mapRepository.mapData.converter

        let width = converter.convertFromMetersToMapCoordinate(input: rtls.widthInMeters)
        let height = converter.convertFromMetersToMapCoordinate(input: rtls.heightInMeters)

        let mapBounds = CoordinateBounds(rect: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: height)))
//      print("Area", rtls.widthInMeters, rtls.heightInMeters, rtls.widthInMeters * rtls.heightInMeters, rtls.widthInMeters * rtls.heightInMeters / .pi)
      //Area 93.17 112.4 10472.308 3333.439167561601 IKEA delft markethall
        let cameraPadding = converter.convertFromMetersToMapCoordinate(input: 10)
        let cameraBounds: CoordinateBounds

        if rtls.widthInMeters > rtls.heightInMeters {
            let modifiedMapBounds = CoordinateBounds(rect: CGRect(origin: CGPoint(x: 0.0, y: -(height * 1.5)), size: CGSize(width: width, height: height * 4.0)))
            let sw = modifiedMapBounds.southwest
            let ne = modifiedMapBounds.northeast
            cameraBounds = CoordinateBounds(
                southwest: CLLocationCoordinate2D(latitude: sw.latitude - cameraPadding, longitude: sw.longitude - cameraPadding),
                northeast: CLLocationCoordinate2D(latitude: ne.latitude + cameraPadding, longitude: ne.longitude + cameraPadding)
            )
        } else if rtls.widthInMeters > (rtls.heightInMeters * 0.8) {
            let modifiedMapBounds = CoordinateBounds(rect: CGRect(origin: CGPoint(x: 0.0, y: -(height * 1.2)), size: CGSize(width: width, height: height * 3.0)))
            let sw = modifiedMapBounds.southwest
            let ne = modifiedMapBounds.northeast
            cameraBounds = CoordinateBounds(
                southwest: CLLocationCoordinate2D(latitude: sw.latitude - cameraPadding, longitude: sw.longitude - cameraPadding),
                northeast: CLLocationCoordinate2D(latitude: ne.latitude + cameraPadding, longitude: ne.longitude + cameraPadding)
            )
        } else {
            let sw = mapBounds.southwest
            let ne = mapBounds.northeast
            cameraBounds = CoordinateBounds(
                southwest: CLLocationCoordinate2D(latitude: sw.latitude - cameraPadding, longitude: sw.longitude - cameraPadding),
                northeast: CLLocationCoordinate2D(latitude: ne.latitude + cameraPadding, longitude: ne.longitude + cameraPadding)
            )
        }
        
        try? self.mapView.mapboxMap.setCameraBounds(with: CameraBoundsOptions(bounds: cameraBounds, minZoom: 0.0))

        let padding = 20.0
        let camera = mapView.mapboxMap.camera(for: mapBounds, padding: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding), bearing: 0, pitch: 0)

        mapView.camera.ease(to: camera, duration: 0.4)
    }
    
    func resetCameraToMapMode() {
        if let cameraMode = requestedCameraMode, !(actualCameraMode is ContainMapMode) {
            self.createCameraMode(for: cameraMode)
        } else {
            self.resetCameraToMapBounds()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.resetCameraToMapBounds()
            }
        }
    }
    
    private func revertCameraModeAfter(interval: Double) {
        self.revertCameraModeTimer?.invalidate()
        self.revertCameraModeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false, block: { (_) in
            guard let mode = self.requestedCameraMode else {
                return
            }
            
            self.createCameraMode(for: mode)
            self.revertCameraModeTimer?.invalidate()
            self.revertCameraModeTimer = nil
        })
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
