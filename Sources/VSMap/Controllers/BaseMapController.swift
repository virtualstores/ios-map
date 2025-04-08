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

public class BaseMapController {
  public var mapDataLoadedPublisher: CurrentValueSubject<Bool, MapControllerError> = .init(false)
  public var mapStatePublisher: CurrentValueSubject<MapState?, Never> { stateMachine.mapStatePublisher }
  public var id: String = UUID().uuidString.uppercased()

  public var location: ILocation {
    guard let location = internalLocation else { fatalError("Location not loaded") }
    return location
  }

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
  private var cameraController: CameraController?

  @Inject var mapRepository: MapRepository
  @Inject var stateMachine: IMapStateMachine
  private let mapViewContainer: TT2MapView

  private var mapData: MapData { mapRepository.mapData }
  private var mapView: MapView { mapViewContainer.mapView }

  private var styleLoaded: Bool = false

  public init(with token: String, view: TT2MapView, mapOptions: VSFoundation.MapOptions = .init(), stateOptions: StateOptions = .init()) {
    self.mapViewContainer = view
    self.mapViewContainer.setup(with: token)

    markerController = MarkerController()
    pathfinderController = PathfinderController()
    zoneController = ZoneController()
    shelfController = ShelfController()
    mlPositionController = MLPositionLineController()
    mapRepository.mapOptions = mapOptions
    mapRepository.stateOptions = stateOptions
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

    guard let style = mapData.rtlsOptions.mapBoxUrl, let styleURI = StyleURI(rawValue: style) else { return }
    styleLoaded = false
    mapViewContainer.mapStyle = self.mapRepository.mapOptions.mapStyle
    mapViewContainer.addLoadingView()
    mapRepository.map = mapView.mapboxMap
    mapView.mapboxMap.loadStyleURI(styleURI) { [weak self] result in
      switch result {
      case .success(let style):
        self?.onStyleLoaded(style: style)
      case let .failure(error):
        Logger(verbosity: .error).log(message: "The map failed to load the style: \(error.localizedDescription)")
        self?.mapDataLoadedPublisher.send(completion: .failure(.loadingFailed))
      }
    }
  }

  public var currentGPSCoordinate: CLLocationCoordinate2D?
  public func getCoordinate(point: CGPoint) -> CLLocationCoordinate2D {
    CLLocationCoordinate2D()
  }

  public func start() {
    if mapView.location.options.puckType == .none || mapView.location.options.puckType == nil { mapViewContainer.addLoadingView() }
    //DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
    //    self.setupUserMarker()
    //}
    if mapRepository.stateOptions.preset == .singleItemWayfinding, mapRepository.isReferenceAngleCertain {
      stateMachine.onQRCodeStart(mapController: self)
    }
  }

  private func onStyleLoaded(style: Style) {
    internalLocation = LocationController()

    mapRepository.style = style

    setupCamera(with: .free)
    markerController.onStyleUpdated()
    pathfinderController.onStyleUpdated()
    zoneController.onStyleUpdated()
    shelfController.onStyleUpdated()
    mlPositionController.onStyleUpdated()

    mapView.location.overrideLocationProvider(with: locationController)
    mapView.location.locationProvider.startUpdatingLocation()
    mapView.location.locationProvider.startUpdatingHeading()
    mapView.location.options.activityType = .other
    mapView.location.options.puckBearing = .heading

    mapView.ornaments.compassView.isHidden = true
    mapView.ornaments.scaleBarView.isHidden = true
    mapView.ornaments.attributionButton.isHidden = true
    //mapView.ornaments.logoView.isHidden = true

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(gesture:)))
    mapView.addGestureRecognizer(tapGesture)

    styleLoaded = true
    locationController.setOptions(options: mapView.location.options)
    let coordinate = mapRepository.currentPosition?.point.convertFromMeterToLatLng(converter: mapRepository.mapData.converter) ?? CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
    locationController.updateUserLocation(newLocation: coordinate, std: 0.0)

    mapDataLoadedPublisher.send(true)
    switch mapRepository.stateOptions.preset {
    case .none: break
    case .singleItemWayfinding:
      stateMachine.set(mapController: self, options: mapRepository.stateOptions)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.mapViewContainer.dismissLoadingScreen() }
  }

  @objc func handleTap(gesture: UITapGestureRecognizer) {
    let location = gesture.location(in: mapView)
    markerController.onClick(point: location)
  }

  private func setupUserMarker() {
    guard styleLoaded else { return }

    let scale = Value<Double>.constant(1.0)
    let userMark = mapRepository.mapOptions.userMark
    let accuracyRingColor = userMark.activeAccuracyStyle.color.withAlphaComponent(userMark.activeAccuracyStyle.alpha)
    let image2 = UIImage(named: "userMarker-shadow", in: .module, compatibleWith: nil)
    let config: Puck2DConfiguration
    switch userMark.userMarkerType {
    case .bullsEye:
      guard let userMarkerImage = UIImage(named: "userMarker", in: .module, compatibleWith: nil) else { return }
      //guard let userMarkerImage = UIImage(named: "userMarker", in: .module, compatibleWith: nil)?.withColor(.red) else { return }
      config = Puck2DConfiguration(topImage: userMarkerImage, scale: scale, showsAccuracyRing: true, accuracyRingColor: accuracyRingColor)
      //var configPulsing = Puck2DConfiguration(topImage: userMarkerImage, pulsing: Puck2DConfiguration.Pulsing(/*color: .white,*/ radius: .accuracy), showsAccuracyRing: true)
      //configPulsing.accuracyRingBorderColor = .white
    case .heading:
      guard let image = UIImage(named: "userMarker-arrow", in: .module, compatibleWith: nil)?.withColor(.red), let shadow = image2 else { return }
      //image.withRenderingMode(.alwaysTemplate)
      //image.withTintColor(.red)
      //image.withTintColor(.red, renderingMode: .alwaysOriginal)
      config = Puck2DConfiguration(topImage: image, shadowImage: shadow, scale: scale, showsAccuracyRing: true, accuracyRingColor: accuracyRingColor)
    case .accuracy:
      guard let shadow = image2 else { return }
      //config = Puck2DConfiguration(topImage: shadow, shadowImage: shadow, scale: scale, showsAccuracyRing: true, accuracyRingColor: accuracyRingColor, accuracyRingBorderColor: .white)

      var test = Puck2DConfiguration.makeDefault()
      test.showsAccuracyRing = true
      test.accuracyRingColor = accuracyRingColor
      test.accuracyRingBorderColor = .white
      config = test
    case .custom(let image):
      config = Puck2DConfiguration(topImage: image, scale: scale, showsAccuracyRing: true, accuracyRingColor: accuracyRingColor)
    }

    mapView.location.options.puckType = .puck2D(config)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      self.mapViewContainer.dismissLoadingScreen()
    }
  }

  private func setupCamera(with mode: CameraModes) {
    guard cameraController == nil else { return }
    cameraController = CameraController(mapView: mapView)

    if let controller = cameraController {
      controller.resetCameraToMapBounds()
      controller.updateCameraMode(with: mode)
      mapView.location.addLocationConsumer(newConsumer: controller)
      mapView.gestures.delegate = cameraController
    }
  }

  var date = Date()
  public func updateUserLocation(position: VPSOutputSignal.Position) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, styleLoaded else { return }

      let mapPosition = position.point.convertFromMeterToLatLng(converter: mapData.converter)
      locationController.updateUserLocation(newLocation: mapPosition, std: position.std)
      cameraController?.updateLocation(with: mapPosition, direction: direction, std: position.std)
      markerController.updateLocation(newLocation: position.point, precision: position.std)
      pathfinderController.onNewPosition(position: position.point, std: locationController.accuracyOverride ?? 1.5)
      zoneController.updateLocation(newLocation: position.point)

      if mapRepository.stateOptions.preset == .none, mapView.location.options.puckType == .none || mapView.location.options.puckType == nil {
        setupUserMarker()
      } else {
        mapViewContainer.dismissLoadingScreen()
        stateMachine.onPositionUpdate(position: position, mapController: self)
        if position.trustedPosition, score > 750 {
          locationController.accuracyOverride = max(2.0, min(4.0, position.std))
        } else {
          locationController.accuracyOverride = max(4.0, min(20.0, position.std))
        }
      }
    }
  }

  var score = 1000
  public func visitScore(_ score: Int) {
    self.score = score
  }

  public func set(userMarkerVisibility: Bool) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if userMarkerVisibility, mapView.location.options.puckType == .none || mapView.location.options.puckType == nil {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          self.setupUserMarker()
        }
      } else {
        mapView.location.options.puckType = .none
      }
    }
  }

  private var realConverter: ICoordinateConverterReal?
  public func updateMLPosition(point: CGPoint) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, styleLoaded else { return }
      if let converter = realConverter {
        mlPositionController.onNewPosition(coordinate: point.convertFromMeterToLatLng(converter: converter))
      } else {
        mlPositionController.onNewPosition(coordinate: point.convertFromMeterToLatLng(converter: mapData.converter))
      }
    }
  }

  public func updateMLPosition(coordinate: CLLocationCoordinate2D) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, styleLoaded else { return }
      mlPositionController.onNewPosition(coordinate: coordinate)
    }
  }

  public func updateLatLngPosition(latLng: VPSOutputSignal.LatLngPosition) {}

  public func update(location: VPSOutputSignal.LatLngPosition.Location) {}

  public func updateParticlePositions(positions: [CGPoint]) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, styleLoaded else { return }
      mlPositionController.onNewParticles(coordinates: positions.map({ $0.convertFromMeterToLatLng(converter: self.mapData.converter) }))
    }
  }

  var direction: Double = .zero
  public func updateUserDirection(newDirection: Double) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, styleLoaded else { return }
      direction = newDirection
      locationController.updateUserDirection(newDirection: newDirection)
    }
  }

  public func stop() {
    mapViewContainer.addLoadingView()
    cameraController?.set(override: nil)
    cameraController?.reset()
    mapRepository.currentPosition = nil
    mapRepository.isPositionActive = false
    if mapRepository.stateOptions.preset == .singleItemWayfinding {
      stateMachine.transitionToSate(toState: .locationUnknown, fromState: nil)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      self.mapView.location.options.puckType = .none
      self.mapView.location.locationProvider.stopUpdatingLocation()
      self.mapView.location.locationProvider.stopUpdatingHeading()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        self.mapViewContainer.dismissLoadingScreen()
        self.marker.updateLocation(newLocation: .zero, precision: 0.0)
      }
    }
  }

  public func reset() {
    mlPositionController.reset()
  }
}

extension BaseMapController: IMapController {
  public var camera: ICameraController {
    guard let camera = cameraController else { fatalError("Camera not loaded") }
    return camera
  }

  public var marker: IMarkerController { markerController }
  public var path: IPathfinderController { pathfinderController }
  public var zone: IZoneController { zoneController }
  public var shelf: IShelfController { shelfController }
  public var mlPosition: IMLPositionLineController { mlPositionController }
}

extension UIImage {
  func withColor(_ color: UIColor) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, scale)
    let drawRect = CGRect(x: 0,y: 0,width: size.width,height: size.height)
    color.setFill()
    UIRectFill(drawRect)
    draw(in: drawRect, blendMode: .destinationIn, alpha: 1)

    let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return tintedImage!
  }
}
