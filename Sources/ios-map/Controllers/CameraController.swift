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
        case .threeDimensional(let zoomLevel, _):
            let mode =  ThreeDimensionalMode(mapView: mapView, zoomLevel: zoomLevel ?? 10)
            
            self.actualCameraMode = mode
        }
    }
    
    func resetCameraToMapBounds() {
        let width = mapRepository.mapData.converter.convertFromMetersToMapCoordinate(input: mapRepository.mapData.rtlsOptions.widthInMeters )
        
        let heightInMeters = mapRepository.mapData.rtlsOptions.widthInMeters > mapRepository.mapData.rtlsOptions.heightInMeters ? mapRepository.mapData.rtlsOptions.widthInMeters : mapRepository.mapData.rtlsOptions.heightInMeters
        
        let height = mapRepository.mapData.converter.convertFromMetersToMapCoordinate(input: heightInMeters)
        
        let mapBounds = CoordinateBounds(rect: CGRect(origin: CGPoint(x: -(width * 0.3), y: -(height * 0.8)), size: CGSize(width: width * 1.6, height: height * 2.0)))
        
        try? self.mapView.mapboxMap.setCameraBounds(with: CameraBoundsOptions(bounds: mapBounds, minZoom: 0.0))
        
        let camera = mapView.mapboxMap.camera(for: mapBounds, padding: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0), bearing: 0, pitch: 0)
        
        mapView.mapboxMap.setCamera(to: camera)
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

extension CameraController: GestureManagerDelegate {
    public func gestureManager(_ gestureManager: GestureManager, didBegin gestureType: GestureType) {
        self.createCameraMode(for: .free)
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
