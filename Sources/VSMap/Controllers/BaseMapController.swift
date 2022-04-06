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
import MapboxMaps
import Combine

public class BaseMapController: IMapController {
    public var mapDataLoadedPublisher: CurrentValueSubject<Bool?, MapControllerError> = .init(false)

    public var location: ILocation {
        guard let location = internalLocation else { fatalError("Map not loaded") }

        return location
    }

    public var camera: ICameraController {
        guard let camera = cameraController else { fatalError("Camera not loaded") }

        return camera
    }
    
    public var marker: IMarkerController {
//        guard let marker = markerController else { fatalError("marker not loaded") }
        
        return markerController
    }

    public var path: IPathfindingController { pathfinderController }

    public var zone: IZoneController { zoneController }
    
    private var locationController: LocationController {
        guard let internalLocation = internalLocation else { fatalError("location not loaded") }
        
        return internalLocation
    }

    private var mapData: MapData { mapRepository.mapData }
    private var mapView: MapView { mapViewContainer.mapView }

    //Controllers for helping baseController to setup map
    var internalLocation: LocationController?
    var cameraController: CameraController?
    var markerController: MarkerControllerImpl
    var pathfinderController: PathfinderController
    var zoneController: ZoneController
    
    private var mapRepository = MapRepository()
    private var mapViewContainer: TT2MapView

    private var styleLoaded: Bool = false

    public init(with token: String, view: TT2MapView, mapOptions: VSFoundation.MapOptions) {
        self.mapViewContainer = view
        self.mapViewContainer.setup(with: token)
        
        mapRepository.mapOptions = mapOptions
        pathfinderController = PathfinderController(mapRepository: mapRepository)
        zoneController = ZoneController(mapRepository: mapRepository)
        markerController = MarkerControllerImpl(mapRepository: mapRepository)
    }

    public func setup(pathfinder: IFoundationPathfinder, zones: [Zone], sharedProperties: SharedZoneProperties?, changedFloor: Bool = false) {
        if changedFloor {
            markerController.onFloorChange(mapRepository: mapRepository)
            pathfinderController.onFloorChange(mapRepository: mapRepository)
            zoneController.onFloorChange(mapRepository: mapRepository)
        }
        pathfinderController.pathfinder = pathfinder
        zoneController.setup(zones: zones, sharedProperties: sharedProperties)
    }

    /// Map loader which will receave all needed  setup information
    public func loadMap(with mapData: MapData) {
        self.mapRepository.mapData = mapData

        guard let style = mapData.rtlsOptions.mapBoxUrl, let styleURI = StyleURI(rawValue: style) else { return }

        mapViewContainer.mapStyle = self.mapRepository.mapOptions.mapStyle
        mapViewContainer.addLoadingView()
        mapRepository.map = mapView.mapboxMap
        mapView.mapboxMap.loadStyleURI(styleURI) { [weak self] result in
            switch result {
            case .success(let style):
                self?.onStyleLoaded(style: style)
                self?.mapViewContainer.dismissLoadingScreen()
            case let .failure(error):
                Logger.init(verbosity: .debug).log(message: "The map failed to load the style: \(error.localizedDescription)")
                self?.mapDataLoadedPublisher.send(completion: .failure(.loadingFailed))
            }
        }
    }

    public func start() {
        mapViewContainer.addLoadingView()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setupUserMarker()
        }
    }

    private func onStyleLoaded(style: Style) {
        internalLocation = LocationController(mapRepository: mapRepository)

        mapRepository.style = style

        setupCamera(with: .free)
        markerController.onStyleUpdated()
        pathfinderController.onStyleUpdated()
        zoneController.onStyleUpdated()

        mapView.location.overrideLocationProvider(with: locationController)
        mapView.location.locationProvider.startUpdatingLocation()
        mapView.location.locationProvider.startUpdatingHeading()
        mapView.location.options.activityType = .other
        mapView.location.options.puckBearingSource = .heading

        mapView.ornaments.compassView.isHidden = true
        mapView.ornaments.scaleBarView.isHidden = true
        mapView.ornaments.attributionButton.isHidden = true
        mapView.ornaments.logoView.isHidden = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(gesture:)))
        mapView.addGestureRecognizer(tapGesture)

        styleLoaded = true
        locationController.setOptions(options: mapView.location.options)
        mapDataLoadedPublisher.send(true)
    }

    @objc func handleTap(gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: mapView)
        markerController.onClick(point: location)
    }

    private func setupUserMarker() {
        guard styleLoaded else { return }
        let image = UIImage(named: "userMarker")//mapRepository.mapOptions.mapStyle.userMarkerImage

        if let userMarkerImage = image {
            let config = Puck2DConfiguration(topImage: userMarkerImage, bearingImage: nil, shadowImage: nil, scale: .constant(1.5), showsAccuracyRing: true)
            mapView.location.options.puckType = .puck2D(config)
        } else {
            mapView.location.options.puckType = .puck2D()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.mapViewContainer.dismissLoadingScreen()
        }
    }

    private func setupCamera(with mode: CameraModes) {
        cameraController = CameraController(mapView: mapView, mapRepository: mapRepository)

        if let controller = cameraController {
            controller.resetCameraToMapBounds()
            controller.updateCameraMode(with: mode)
            mapView.location.addLocationConsumer(newConsumer: controller)
            mapView.gestures.delegate = cameraController
        }
    }

    public func updateUserLocation(newLocation: CGPoint?, std: Float?) {
        guard let position = newLocation, let std = std else { return }

        let mapPosition = position.convertFromMeterToLatLng(converter: mapData.converter)

        location.updateUserLocation(newLocation: mapPosition, std: std)
        cameraController?.updateLocation(with: mapPosition, direction: direction)
        markerController.updateLocation(newLocation: position, precision: std)
        pathfinderController.onNewPosition(position: position)
        zoneController.updateLocation(newLocation: position)
    }

    var direction: Double = .zero
    public func updateUserDirection(newDirection: Double) {
        direction = newDirection
        location.updateUserDirection(newDirection: newDirection)
    }

  public func addGoal(id: String, itemPosition: ItemPosition) {

}

    public func stop() {
        mapViewContainer.addLoadingView()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.mapView.location.options.puckType = .none
            self.mapView.location.locationProvider.stopUpdatingLocation()
            self.mapView.location.locationProvider.stopUpdatingHeading()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.mapViewContainer.dismissLoadingScreen()
            }
        }
    }

    public func reset() { }

}

