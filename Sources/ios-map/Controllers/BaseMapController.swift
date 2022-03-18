//
//  BaseMapController.swift
//  VSMap
//
//  Created by Hripsime on 2022-02-13.
//

import Foundation
import CoreLocation
import CoreGraphics
import VSFoundation
@_implementationOnly import MapboxMaps

public class BaseMapController: IMapController {
    public var dragDidBegin: (() -> Void)? = nil
    public var dragDidEnd: (() -> Void)? = nil
    
    var mapData: MapData?

    public var location: ILocation {
        guard let location = internalLocation else {
            fatalError("Map not loadede")
        }
        
        return location
    }
    
    public var camera: ICameraController? {
        guard let camera = cameraController else {
            fatalError("Camera not loadede")
        }
        
        return camera
    }
    
    //Controllers for helpin baseController to setup map
    var internalLocation: LocationController?
    var cameraController: CameraController?
    
    private var mapViewContainer: TT2MapView
    private var currentStyle: Style?
    
    public init(with token: String, view: TT2MapView) {
        self.mapViewContainer = view
        self.mapViewContainer.setup(with: token)
    }
    
    /// Map loader which will receave all needed  setup information
    public func loadMap(with mapData: MapData) {
        self.mapData = mapData
        
        guard let style = mapData.rtlsOptions.mapBoxUrl, let styleURI = StyleURI(rawValue: style) else { return }
        
        mapViewContainer.mapBoxMapView.mapboxMap.loadStyleURI(styleURI) { [weak self] result in
            switch result {
            case .success(let style):
                self?.currentStyle = style
                self?.onStyleLoaded()
                self?.setupCamera(with: .free)
            case let .failure(error):
                Logger.init(verbosity: .debug).log(message: "The map failed to load the style: \(error)")
            }
        }
    }
    
    private func onStyleLoaded() {
        internalLocation = LocationController()
        guard let location = internalLocation else { return }
        
        mapViewContainer.mapBoxMapView.location.overrideLocationProvider(with: location)
        mapViewContainer.mapBoxMapView.location.locationProvider.startUpdatingLocation()
        mapViewContainer.mapBoxMapView.location.options.puckType = .puck2D(Puck2DConfiguration(topImage: UIImage(systemName: "location.north.circle.fill"), bearingImage: nil, shadowImage: nil, scale: nil, showsAccuracyRing: false))
        
        let image = mapData?.style.userMarkerImage
        
        if let userMarkerImage = image {
            let config = Puck2DConfiguration(topImage: userMarkerImage, bearingImage: nil, shadowImage: nil, scale: .constant(1.5), showsAccuracyRing: true)
            
            mapViewContainer.mapBoxMapView.location.options.puckType = .puck2D(config)
        } else {
            mapViewContainer.mapBoxMapView.location.options.puckType = .puck2D()
        }
    }
    
    private func setupCamera(with mode: CameraModes) {
        guard let mapData = self.mapData else { return }
        
        cameraController = CameraController(mapView: mapViewContainer.mapBoxMapView, mapData: mapData)
        
        if let controller = cameraController {
            controller.setupInitialCamera()
            controller.setInitialCameraMode(for: mode)
            mapViewContainer.mapBoxMapView.location.addLocationConsumer(newConsumer: controller)
            mapViewContainer.mapBoxMapView.gestures.delegate = cameraController
            
            cameraController?.dragDidEnd = {
                self.dragDidEnd?()
            }
            
            cameraController?.dragDidBegin = {
                self.dragDidBegin?()
            }
        }
    }
    
    public func updateUserLocation(newLocation: CGPoint?, std: Float?) {
        guard let position = newLocation, let converter = mapData?.converter, let std = std else { return }
        
        let mapPosition = position.convertFromMeterToLatLng(converter: converter)
        let convertedStd = converter.convertFromMetersToPixels(input: Double(std))
        let mapStd = converter.convertFromPixelsToMapCoordinate(input: convertedStd)
        
        location.updateUserLocation(newLocation: mapPosition, std: Float(mapStd))
        cameraController?.updateLocation(with: mapPosition, direction: Double(std))
    }
    
    public func updateUserDirection(newDirection: Double) {
        location.updateUserDirection(newDirection: newDirection)
    }
    
    public func reset() { }
}

