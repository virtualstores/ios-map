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

class CameraController: ICameraController {
    public var requestedCameraMode: CameraMode?
    public var actualCameraMode: CameraMode? {
        didSet {
            actualCameraMode?.onEnter()
        }
    }
    
    public var dragDidBegin: (() -> Void)? = nil
    public var dragDidEnd: (() -> Void)? = nil
    
    private var mapView: MapView
    private var mapData: MapData
    private var rtlsOptions: RtlsOptions?
    private var lastLocation: Location?
    private var revertCameraModeTimer: Timer?

    public init(mapView: MapView, mapData: MapData) {
        self.mapView = mapView
        self.mapData = mapData
    }
    
    func setInitialCameraMode(for mode: CameraModes) {
        createCameraMode(for: mode)
    }
    
    func setupInitialCamera() {
        let width = mapData.converter.convertFromMetersToMapCoordinate(input: mapData.rtlsOptions.widthInMeters)
        let height = mapData.converter.convertFromMetersToMapCoordinate(input: mapData.rtlsOptions.heightInMeters)
        
        let mapBounds = CoordinateBounds(rect: CGRect(origin: .zero, size: CGSize(width: width, height: height)))
        
        try? self.mapView.mapboxMap.setCameraBounds(with: CameraBoundsOptions(bounds: mapBounds,  minZoom: 0.0))
    }
    
    public func updateLocation(with newLocation: CLLocationCoordinate2D, direction: Double) {
        actualCameraMode?.onLocationUpdated(newLocation: newLocation, direction: direction)
    }
    
    public func updateCameraMode(with mode: CameraModes) {
        createCameraMode(for: mode)
    }
    
    public func setAutoCameraResetDelay(with milliseconds: Int64) { }
    
    public func resetCameraMode() {
        actualCameraMode?.reset()
    }
    
    private func createCameraMode(for mode: CameraModes) {
        switch mode {
        case .free:
            actualCameraMode = FreeMode()
        case .containMap:
            actualCameraMode = ContainMapMode()
        case .threeDimensional(let zoomLevel, let degree):
            guard let location = self.lastLocation else { return }
            actualCameraMode = ThreeDimensionalMode(mapView: mapView, zoomLevel: zoomLevel ?? 8, degree: degree, location: location.coordinate)
        }
    }
    
    private func resetCameraToMapMode() { }
    
    private func revertCameraModeAfter(interval: Double) {
        self.revertCameraModeTimer?.invalidate()
//        self.revertCameraModeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false, block: { (_) in
//            guard let mode = self.mapController?.camera?.getRequestedCameraMode() else {
//                return
//            }
//
//            self.mapController?.camera?.updateCameraMode(with: mode)
//            self.revertCameraModeTimer?.invalidate()
//            self.revertCameraModeTimer = nil
//        })
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
        self.updateCameraMode(with: .free)
        self.resetCameraToMapMode()
        
        //self.dragDidBegin?()
        Logger.init(verbosity: .debug).log(message: "didBegin")
    }
    
    public func gestureManager(_ gestureManager: GestureManager, didEnd gestureType: GestureType, willAnimate: Bool) {
        self.revertCameraModeAfter(interval: 4.0)

        self.dragDidEnd?()
        Logger.init(verbosity: .debug).log(message: "didEnd")
    }
    
    public func gestureManager(_ gestureManager: GestureManager, didEndAnimatingFor gestureType: GestureType) {
        Logger.init(verbosity: .debug).log(message: "didEndAnimatingFor")
    }
}
