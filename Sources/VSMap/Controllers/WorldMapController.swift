//
//  WorldMapController.swift
//  VSMap
//
//  Created by Théodore Roos on 2023-11-21.
//

import CoreLocation
import CoreGraphics
import Combine
import Foundation
import UIKit
import VSFoundation
import MapboxMaps

public class WorldMapController: IMapController {
  public var id: String { UUID().uuidString.uppercased() }
  public var mapDataLoadedPublisher: CurrentValueSubject<Bool, MapControllerError> = .init(false)
  public var mapStatePublisher: CurrentValueSubject<MapState?, Never> = .init(nil)

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
  public var offlineManager: IMapboxOfflineManager { offlineController }

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
  private let offlineController = MapboxOfflineManager()

  //private let mapRepository: MapRepository = MapRepository()
  @Inject var mapRepository: MapRepository
  private let mapViewContainer: TT2MapView

  private var mapData: MapData { mapRepository.mapData }
  private var mapView: MapView { mapViewContainer.mapView }
  private var displayMultiplePositions: Bool { mapRepository.displayMultiplePositions }

  private var styleLoaded: Bool = false

  public init(with token: String, view: TT2MapView, mapOptions: VSFoundation.MapOptions, displayMultiplePositions: Bool = false) {
    self.mapViewContainer = view
    self.mapViewContainer.setup(with: token)

    markerController = MarkerController()
    pathfinderController = PathfinderController()
    zoneController = ZoneController()
    shelfController = ShelfController()
    mlPositionController = MLPositionLineController()
    mapRepository.mapOptions = mapOptions
    mapRepository.displayMultiplePositions = displayMultiplePositions
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(orientationDidChange),
      name: UIDevice.orientationDidChangeNotification,
      object: nil
    )
  }

  deinit {
    dispose()
  }

  public func dispose() {
    // TODO: Dispose
  }

  var cameraOffset: Double = 0
  @objc func orientationDidChange(_ notification: Notification) {
    switch UIDevice.current.orientation {
    case .portrait: cameraOffset = 0
    case .landscapeLeft: cameraOffset = 90
    case .landscapeRight: cameraOffset = -90
    default: break
    }
  }

  // maybe just be able to send new useraccuracylevel parameters?
  public func setNew(mapOptions: VSFoundation.MapOptions) {
    mapRepository.mapOptions = mapOptions
  }

  public func setup(pathfinder: IPathfinder?, zones: [Zone], sharedProperties: SharedZoneProperties?, shelves: [ShelfGroup], changedFloor: Bool = false) {
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
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      mapRepository.mapData = mapData

      styleLoaded = false
      mapViewContainer.mapStyle = mapRepository.mapOptions.mapStyle
      mapViewContainer.addLoadingView()
      mapRepository.map = mapView.mapboxMap
      mapView.mapboxMap.loadStyle(.satellite) { [weak self] (error) in
        if let error = error {
          Logger(verbosity: .error).log(message: "The map failed to load the style: \(error.localizedDescription)")
          self?.mapDataLoadedPublisher.send(completion: .failure(.loadingFailed))
        } else {
          DispatchQueue.main.async {
            self?.onStyleLoaded()
          }
        }
      }
    }
  }

  public func start() {
    if mapView.location.options.puckType == .none || mapView.location.options.puckType == nil { mapViewContainer.addLoadingView() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        self.setupUserMarker()
    }
  }

  private func onStyleLoaded() {
    internalLocation = LocationController(coordinateConverter: mapRepository.mapData.converter, mapOptions: mapRepository.mapOptions)

    setupCamera(with: .free)
    markerController.onStyleUpdated()
    pathfinderController.onStyleUpdated()
    zoneController.onStyleUpdated()
    shelfController.onStyleUpdated()
    mlPositionController.onStyleUpdated()
    offlineController.onStyleUpdated()

    mapView.location.override(provider: locationController)
    mapView.location.options.puckBearing = .heading
    // TODO: Sink for location
    //mapView.location.addLocationConsumer(newConsumer: self)


    mapView.ornaments.compassView.isHidden = true
    mapView.ornaments.scaleBarView.isHidden = true
    mapView.ornaments.attributionButton.isHidden = true
    mapView.ornaments.logoView.isHidden = true

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(gesture:)))
    mapView.addGestureRecognizer(tapGesture)

    styleLoaded = true
    locationController.setOptions(options: mapView.location.options)
    //locationController.updateUserLocation(newLocation: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0), std: 0.0)

    mapDataLoadedPublisher.send(true)

    start()
  }

  @objc func handleTap(gesture: UITapGestureRecognizer) {
    let location = gesture.location(in: mapView)
    //print("LOCATION", location)
    //let coordinate = mapView.mapboxMap.coordinate(for: location)
    //print("MAPBOXMAP COORDINATE", coordinate)
    //initRealWorldConverter()
    //if let converter = realConverter {
    //  print("GESTURE COORDINATE", location.convertFromMeterToLatLng(converter: converter))
    //  if let location = self.lastLocationPublisher.value?.coordinate {
    //    print("LAST LOCATION", location)
    //  }
    //}
    markerController.onClick(point: location)
  }

  public func getCoordinate(point: CGPoint) -> CLLocationCoordinate2D {
    let coordinate = mapView.mapboxMap.coordinate(for: point)
    //print("CONVERTED COORDINATE", "(\(coordinate.latitude), \(coordinate.longitude))")
    //if let location = self.lastLocationPublisher.value?.coordinate {
    //  print("LAST LOCATION", "       (\(location.latitude), \(location.longitude))")
    //  print("EQUALS", coordinate == location)
    //}
    return coordinate
  }

  private func setupUserMarker() {
    guard styleLoaded else { return }
    if displayMultiplePositions {
      mapView.location.options.puckType = .puck2D(Puck2DConfiguration(showsAccuracyRing: true, accuracyRingBorderColor: .white))
    } else {
      switch currentReliableSource {
      case .gps, .undefined:
        mapView.location.options.puckType = .puck2D(Puck2DConfiguration(showsAccuracyRing: true, accuracyRingBorderColor: .white))
      case .vpsML:
        guard let image = UIImage(named: "userMarker-shadow", in: .module, compatibleWith: nil) else { return }
        mapView.location.options.puckType = .puck2D(Puck2DConfiguration(topImage: image, shadowImage: image, showsAccuracyRing: true, accuracyRingColor: .orange.withAlphaComponent(0.6), accuracyRingBorderColor: .white))
      }
    }
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
      // TODO: Send location to camera controller
      //mapView.location.addLocationConsumer(newConsumer: controller)
      mapView.gestures.delegate = cameraController
    }
  }

  public func set(userMarkerVisibility: Bool) {
    if userMarkerVisibility, mapView.location.options.puckType == .none || mapView.location.options.puckType == nil {
      setupUserMarker()
    } else {
      mapView.location.options.puckType = .none
    }
  }

  var date = Date()
  public func updateUserLocation(position: VPSOutputSignal.Position) {
    guard styleLoaded else { return }
    if mapView.location.options.puckType == .none || mapView.location.options.puckType == nil { setupUserMarker() }

    let mapPosition = position.point.convertFromMeterToLatLng(converter: mapData.converter)
    locationController.updateUserLocation(newLocation: mapPosition, std: position.std)
    cameraController?.updateLocation(with: mapPosition, direction: direction, std: position.std)
    markerController.updateLocation(newLocation: position.point, precision: position.std)
    pathfinderController.onNewPosition(position: position.point, std: 1.5)
    zoneController.updateLocation(newLocation: position.point)
  }

  private var realConverter: ICoordinateConverterReal?
  public func updateMLPosition(point: CGPoint) {
    guard styleLoaded else { return }
    if let converter = realConverter {
      let coordinate = point.convertFromMeterToLatLng(converter: converter)
      updateMLPosition(coordinate: coordinate)
    } else {
      updateMLPosition(coordinate: point.convertFromMeterToLatLng(converter: mapData.converter))
    }
  }

  public func updateMLPosition(coordinate: CLLocationCoordinate2D) {
    guard styleLoaded else { return }
    mlPositionController.onNewPosition(coordinate: coordinate)
  }
  
  var currentReliableSource: VPSOutputSignal.LatLngPosition.Source = .undefined {
    didSet {
      setupUserMarker()
    }
  }
  public func updateLatLngPosition(latLng: VPSOutputSignal.LatLngPosition) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, styleLoaded else { return }
      lastLocationPublisher2.send(.init(latitude: latLng.gpsLocation.latitude, longitude: latLng.gpsLocation.longitude))
      mlPositionController.onNewPosition(latLng: latLng)
      if displayMultiplePositions {
        switch latLng.reliableSource {
        case .gps:
          mlPositionController.hideMLPath()
          mlPositionController.hideMLUser()
        case .vpsML:
          //mlPositionController.onNewPosition(location: latLng.mlLocation)
          mlPositionController.showMLPath()
          mlPositionController.showMLUser()
        case .undefined: break
        }
        locationController.updateUserLocation(location: latLng.gpsLocation)
      } else {
        if currentReliableSource != latLng.reliableSource {
          currentReliableSource = latLng.reliableSource
        }
        locationController.updateUserLocation(latLng: latLng)
        if latLng.reliableSource == .vpsML {
          //mlPositionController.onNewPosition(location: latLng.mlLocation)
        }
      }
    }
  }

  public func update(location: VPSOutputSignal.LatLngPosition.Location) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, styleLoaded else { return }
      locationController.updateUserLocation(location: location)
      lastLocationPublisher2.send(.init(latitude: location.latitude, longitude: location.longitude))
    }
  }

  public func updateParticlePositions(positions: [CGPoint]) {}

  var direction: Double = .zero
  public func updateUserDirection(newDirection: Double) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, styleLoaded else { return }
      direction = newDirection + cameraOffset
      locationController.updateUserDirection(newDirection: newDirection + cameraOffset)
    }
  }

  public func stop() {
    reset()
    set(userMarkerVisibility: false)
  }

  public func reset() {
    guard styleLoaded else { return }
    mlPositionController.reset()
    currentReliableSource = .undefined
  }

  public var lastLocationPublisher: CurrentValueSubject<Location?, Never> = .init(nil)
  public var lastLocationPublisher2: CurrentValueSubject<CLLocation?, Never> = .init(nil)
  public var currentGPSCoordinate: CLLocationCoordinate2D? { lastLocationPublisher.value?.coordinate }
  public var lastMLCoordinate: CLLocationCoordinate2D? { mlPositionController.currentMLPath.last }
  public var distanceBetweenGPSML: Double? {
    guard
      let gpsCoordinate = currentGPSCoordinate,
      let mlCoordinate = lastMLCoordinate
    else { return nil }
    return gpsCoordinate.distance(to: mlCoordinate)
  }

  public func visitScore(_ score: Int) {}
  public func onForceSync() {}
}

// TODO: Sink on location
//extension WorldMapController: LocationConsumer {
//  public func locationUpdate(newLocation: MapboxMaps.Location) {
//    lastLocationPublisher.send(newLocation)
//  }
//}
