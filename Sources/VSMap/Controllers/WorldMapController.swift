//
//  WorldMapController.swift
//  VSMap
//
//  Created by Théodore Roos on 2023-11-21.
//

import Foundation
import CoreLocation
import CoreGraphics
import VSFoundation
import MapboxMaps
import Combine

public class WorldMapController: IMapController {
  public var mapDataLoadedPublisher: CurrentValueSubject<Bool, MapControllerError> = .init(false)

  public var location: ILocation {
    guard let location = internalLocation else { fatalError("Location not loaded") }
    return location
  }

  public var camera: ICameraController {
    guard let camera = cameraController else { fatalError("Camera not loaded") }
    return camera
  }

  public var marker: IMarkerController { markerController }
  public var path: IPathfinderController { pathfinderController }
  public var zone: IZoneController { zoneController }
  public var shelf: IShelfController { shelfController }
  public var mlPosition: IMLPositionLineController { mlPositionController }

  private var locationController: LocationController {
    guard let location = internalLocation else { fatalError("Location not loaded") }
    return location
  }

  //Controllers for helping baseController to setup map
  private let markerController: MarkerController
  private let pathfinderController: PathfinderController
  private let zoneController: ZoneController
  private let shelfController: ShelfController
  private let mlPositionController: MLPositionLineController
  private var internalLocation: LocationController?
  private var cameraController: WorldCameraController?

  private let mapRepository: MapRepository = MapRepository()
  private let mapViewContainer: TT2MapView

  private var mapData: MapData { mapRepository.mapData }
  private var mapView: MapView { mapViewContainer.mapView }

  private var styleLoaded: Bool = false

  public init(with token: String, view: TT2MapView, mapOptions: VSFoundation.MapOptions) {
    self.mapViewContainer = view
    self.mapViewContainer.setup(with: token)

    mapRepository.mapOptions = mapOptions
    markerController = MarkerController(mapRepository: mapRepository)
    pathfinderController = PathfinderController(mapRepository: mapRepository)
    zoneController = ZoneController(mapRepository: mapRepository)
    shelfController = ShelfController(mapRepository: mapRepository)
    mlPositionController = MLPositionLineController(mapRepository: mapRepository)
  }

  // maybe just be able to send new useraccuracylevel parameters?
  public func setNew(mapOptions: VSFoundation.MapOptions) {
    mapRepository.mapOptions = mapOptions
  }

  public func setup(pathfinder: IPathfinder, zones: [Zone], sharedProperties: SharedZoneProperties?, shelves: [ShelfGroup], changedFloor: Bool = false) {
    if changedFloor {
      markerController.onFloorChange(mapRepository: mapRepository)
      pathfinderController.onFloorChange(mapRepository: mapRepository)
      zoneController.onFloorChange(mapRepository: mapRepository)
      shelfController.onFloorChange(mapRepository: mapRepository)
    }
    pathfinderController.pathfinder = pathfinder
    zoneController.setup(zones: zones, sharedProperties: sharedProperties)
    shelfController.setShelves(shelves: shelves)
  }

  /// Map loader which will receave all needed  setup information
  public func loadMap(with mapData: MapData) {
    self.mapRepository.mapData = mapData

    styleLoaded = false
    mapViewContainer.mapStyle = self.mapRepository.mapOptions.mapStyle
    mapViewContainer.addLoadingView()
    mapRepository.map = mapView.mapboxMap
    mapView.mapboxMap.loadStyleURI(.outdoors) { [weak self] result in
      switch result {
      case .success(let style):
        self?.onStyleLoaded(style: style)
      case let .failure(error):
        Logger(verbosity: .error).log(message: "The map failed to load the style: \(error.localizedDescription)")
        self?.mapDataLoadedPublisher.send(completion: .failure(.loadingFailed))
      }
    }
  }

  public func initRealWorldConverter() {
    guard let location = lastLocation, let heading = location.heading else { return }
    print("HEADING", heading)
    realConverter = RealCoordinateConverter(
      latLngOrigin: location.coordinate,
      mapAngleInDegrees: 0.0,
      earthRadiusInMeters: 6378137.0,
      pixelsPerMeter: 50
    )
  }

  public func start() {
    if mapView.location.options.puckType == .none || mapView.location.options.puckType == nil { mapViewContainer.addLoadingView() }
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
    shelfController.onStyleUpdated()
    mlPositionController.onStyleUpdated()

    mapView.location.locationProvider.startUpdatingLocation()
    mapView.location.locationProvider.startUpdatingHeading()
    mapView.location.options.activityType = .other
    mapView.location.options.puckBearing = .heading
    mapView.location.addLocationConsumer(newConsumer: self)

    mapView.ornaments.compassView.isHidden = true
    mapView.ornaments.scaleBarView.isHidden = true
    mapView.ornaments.attributionButton.isHidden = true
    mapView.ornaments.logoView.isHidden = true

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(gesture:)))
    mapView.addGestureRecognizer(tapGesture)

    styleLoaded = true
    locationController.setOptions(options: mapView.location.options)
    locationController.updateUserLocation(newLocation: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0), std: 0.0)

    mapDataLoadedPublisher.send(true)

    start()
  }

  @objc func handleTap(gesture: UITapGestureRecognizer) {
    let location = gesture.location(in: mapView)
    markerController.onClick(point: location)
  }

  private func setupUserMarker() {
    guard styleLoaded else { return }
    mapView.location.options.puckType = .puck2D(Puck2DConfiguration(showsAccuracyRing: true))
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      self.mapViewContainer.dismissLoadingScreen()
    }
  }

  private func setupCamera(with mode: CameraModes) {
    guard cameraController == nil else { return }
    cameraController = WorldCameraController(mapView: mapView, mapRepository: mapRepository)

    if let controller = cameraController {
      controller.updateCameraMode(with: mode)
      controller.resetCameraMode()
      mapView.location.addLocationConsumer(newConsumer: controller)
      mapView.gestures.delegate = cameraController
    }
  }

  var date = Date()
  public func updateUserLocation(newLocation: CGPoint?, std: Double?) {
    guard let position = newLocation, let std = std, styleLoaded else { return }
    if mapView.location.options.puckType == .none || mapView.location.options.puckType == nil { setupUserMarker() }

    let mapPosition = position.convertFromMeterToLatLng(converter: mapData.converter)
    locationController.updateUserLocation(newLocation: mapPosition, std: std)
    cameraController?.updateLocation(with: mapPosition, direction: direction)
    markerController.updateLocation(newLocation: position, precision: std)
    pathfinderController.onNewPosition(position: position)
    zoneController.updateLocation(newLocation: position)
  }

  private var realConverter: ICoordinateConverterReal?
  public var convertedMLPostionPublisher: CurrentValueSubject<CLLocationCoordinate2D?, Never> = .init(nil)
  public func updateMLPosition(point: CGPoint) {
    guard styleLoaded else { return }
    if let converter = realConverter {
      let coordinate = point.convertFromMeterToLatLng(converter: converter)
      mlPositionController.onNewPosition(coordinate: coordinate)
      convertedMLPostionPublisher.send(coordinate)
    } else {
      mlPositionController.onNewPosition(coordinate: point.convertFromMeterToLatLng(converter: mapData.converter))
    }
  }

  var direction: Double = .zero
  public func updateUserDirection(newDirection: Double) {
    direction = newDirection
    locationController.updateUserDirection(newDirection: newDirection)
  }

  public func stop() {}

  public func reset() { }

  var lastLocation: Location?

  public var lastLocationPublisher: CurrentValueSubject<Location?, Never> = .init(nil)
}

extension WorldMapController: LocationConsumer {
  public func locationUpdate(newLocation: MapboxMaps.Location) {
    lastLocation = newLocation
    lastLocationPublisher.send(newLocation)
  }
}
