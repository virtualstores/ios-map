//
//  CameraController.swift
//  VSMap
//
//  Created by Hripsime on 2022-02-16.
//

import Foundation
import CoreGraphics
import VSFoundation
@_implementationOnly import MapboxMaps
import SwiftUI

class CameraController: ICameraController {
    public var requestedCameraMode: CameraModes?
    public var actualCameraMode: CameraMode? {
        didSet {
            actualCameraMode?.onEnter()
        }
    }
        
    private var mapView: MapView
    private var mapData: MapData
    private var rtlsOptions: RtlsOptions?
    private var lastLocation: Location?
    private var revertCameraModeTimer: Timer?
    private var revertCameraInterval = 4.0

    public init(mapView: MapView, mapData: MapData) {
        self.mapView = mapView
        self.mapData = mapData
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
        case .threeDimensional(let zoomLevel, let degree):
            guard let location = self.lastLocation else { return }
            let mode =  ThreeDimensionalMode(mapView: mapView, zoomLevel: zoomLevel ?? 8, degree: degree, location: location.coordinate)
            
            self.actualCameraMode = mode
        }
    }
    
    func resetCameraToMapBounds() {
        let width = mapData.converter.convertFromMetersToMapCoordinate(input: mapData.rtlsOptions.widthInMeters)
        let height = mapData.converter.convertFromMetersToMapCoordinate(input: mapData.rtlsOptions.heightInMeters)
        
        let mapBounds = CoordinateBounds(rect: CGRect(origin: .zero, size: CGSize(width: width, height: height)))
        
        try? self.mapView.mapboxMap.setCameraBounds(with: CameraBoundsOptions(bounds: nil,  minZoom: 0.0))
    }
    
    func resetCameraToMapMode() {
        if let cameraMode = requestedCameraMode, !(actualCameraMode is ContainMapMode) {
            self.createCameraMode(for: cameraMode)

        } else {
            self.resetCameraToMapBounds()
            DispatchQueue.main.asyncAfter(deadline: .now() + revertCameraInterval) {
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

/// Was not possible to use the delegate in BaseMapController as it's public
extension CameraController: GestureManagerDelegate {
    public func gestureManager(_ gestureManager: GestureManager, didBegin gestureType: GestureType) {
        self.createCameraMode(for: .free)
        self.resetCameraToMapMode()
        Logger.init(verbosity: .debug).log(message: "didBegin")
    }
    
    public func gestureManager(_ gestureManager: GestureManager, didEnd gestureType: GestureType, willAnimate: Bool) {
        self.revertCameraModeAfter(interval: revertCameraInterval)

        Logger.init(verbosity: .debug).log(message: "didEnd")
    }
    
    public func gestureManager(_ gestureManager: GestureManager, didEndAnimatingFor gestureType: GestureType) {
        Logger.init(verbosity: .debug).log(message: "didEndAnimatingFor")
    }
}
