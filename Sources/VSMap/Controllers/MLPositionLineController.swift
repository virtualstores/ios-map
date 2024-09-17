//
//  MLPositionLineController.swift
//
//
//  Created by Théodore Roos on 2023-11-14.
//

import Foundation
import CoreLocation
import MapboxMaps
import VSFoundation

class MLPositionLineController {
  let SOURCE_ID = "ml-position-source"
  let LAYER_ID = "ml-position"
  let QUEUE_SOURCE_ID = "queue-ml-position-source"
  let QUEUE_LAYER_ID = "queue-ml-position"
  let GPS_SOURCE_ID = "gps-position-source"
  let GPS_LAYER_ID = "gps-position"
  let CIRCLE_SOURCE_ID = "particle-circle-source"
  let CIRCLE_LAYER_ID = "particle-circle"
  let ML_USER_SOURCE_ID = "ml-position-circle-source"
  let ML_USER_LAYER_ID = "ml-position-circle"

  private var mapRepository: MapRepository
  private(set) var currentMLPath: [CLLocationCoordinate2D] = []
  private(set) var currentMLPathQueue: Queue<CLLocationCoordinate2D> = .init(timeout: 30_000)
  private(set) var currentGPSPath: [CLLocationCoordinate2D] = []
  private(set) var particleCoordinates = [CLLocationCoordinate2D]()
  private var currentMLPosition: CLLocationCoordinate2D? { currentMLPath.last }

  private var _mlLineSource: GeoJSONSource?
  private var mlLineSource: GeoJSONSource {
    guard let lineSource = _mlLineSource else { fatalError("ERROOOOOOOOOR!") }
    return lineSource
  }

  private var _mlLineLayer: CircleLayer?
  private var mlLineLayer: CircleLayer {
    guard let lineLayer = _mlLineLayer else { fatalError("ERROOOOOOR") }
    return lineLayer
  }

  private var _mlLineSourceQueue: GeoJSONSource?
  private var mlLineSourceQueue: GeoJSONSource {
    guard let lineSource = _mlLineSourceQueue else { fatalError("ERROOOOOOOOOR!") }
    return lineSource
  }

  private var _mlLineLayerQueue: CircleLayer?
  private var mlLineLayerQueue: CircleLayer {
    guard let lineLayer = _mlLineLayerQueue else { fatalError("ERROOOOOOR") }
    return lineLayer
  }

  private var _gpsLineSource: GeoJSONSource?
  private var gpsLineSource: GeoJSONSource {
    guard let lineSource = _gpsLineSource else { fatalError("ERROOOOOOOOOR!") }
    return lineSource
  }

  private var _gpsLineLayer: CircleLayer?
  private var gpsLineLayer: CircleLayer {
    guard let lineLayer = _gpsLineLayer else { fatalError("ERROOOOOOR") }
    return lineLayer
  }

  private var _circleSource: GeoJSONSource?
  private var circleSource: GeoJSONSource {
    guard let circleSource = _circleSource else { fatalError("ERROOOOOOOOOR!") }
    return circleSource
  }

  private var _circleLayer: CircleLayer?
  private var circleLayer: CircleLayer {
    guard let circleLayer = _circleLayer else { fatalError("ERROOOOOOR") }
    return circleLayer
  }

  private var _mlCircleSource: GeoJSONSource?
  private var mlCircleSource: GeoJSONSource {
    guard let circleSource = _mlCircleSource else { fatalError("ERROOOOOOOOOR!") }
    return circleSource
  }

  private var _mlCircleLayer: CircleLayer?
  private var mlCircleLayer: CircleLayer {
    guard let circleLayer = _mlCircleLayer else { fatalError("ERROOOOOOR") }
    return circleLayer
  }

  private var converter: ICoordinateConverter { mapRepository.mapData.converter }
  private var style: Style { mapRepository.style }
  private var mapOptions: VSFoundation.MapOptions { mapRepository.mapOptions }
  private var pathfindingStyle: VSFoundation.MapOptions.PathfindingStyle { mapOptions.pathfindingStyle }
  private var lastPosition: CGPoint = .zero

  init(mapRepository: MapRepository) {
    self.mapRepository = mapRepository
  }

  //var largestDistance: Double = 0
}

private extension MLPositionLineController {
  func initSources() {
    _mlLineSource = GeoJSONSource()
    _mlLineSource?.data = .empty

    _mlLineLayer = CircleLayer(id: LAYER_ID)
    _mlLineLayer?.source = SOURCE_ID
    //_mlLineLayer?.lineCap = .constant(LineCap(rawValue: pathfindingStyle.pathStyleBody.lineCap) ?? .round)
    //_mlLineLayer?.lineJoin = .constant(LineJoin(rawValue: pathfindingStyle.pathStyleBody.lineJoin) ?? .round)
    _mlLineLayer?.circleColor = .constant(StyleColor(.orange))
    _mlLineLayer?.visibility = .constant(.visible)
    _mlLineLayer?.circleRadius = .expression(
      Exp(.interpolate) {
        Exp(.exponential) { 2 }
        Exp(.zoom)
        [
          0.0: pathfindingStyle.pathStyleBody.lineWidth,
          11.0: pathfindingStyle.pathStyleBody.lineWidth * 2,
          22.0: pathfindingStyle.pathStyleBody.lineWidth * 4
        ]
      }
    )

    _mlLineSourceQueue = GeoJSONSource()
    _mlLineSourceQueue?.data = .empty

    _mlLineLayerQueue = CircleLayer(id: QUEUE_LAYER_ID)
    _mlLineLayerQueue?.source = QUEUE_SOURCE_ID
    //_mlLineLayerQueue?.lineCap = .constant(LineCap(rawValue: pathfindingStyle.pathStyleBody.lineCap) ?? .round)
    //_mlLineLayerQueue?.lineJoin = .constant(LineJoin(rawValue: pathfindingStyle.pathStyleBody.lineJoin) ?? .round)
    _mlLineLayerQueue?.circleColor = _mlLineLayer?.circleColor
    _mlLineLayerQueue?.visibility = _mlLineLayer?.visibility
    _mlLineLayerQueue?.circleRadius = _mlLineLayer?.circleRadius

    _gpsLineSource = GeoJSONSource()
    _gpsLineSource?.data = .empty

    _gpsLineLayer = CircleLayer(id: GPS_LAYER_ID)
    _gpsLineLayer?.source = GPS_SOURCE_ID
    //_gpsLineLayer?.lineCap = .constant(LineCap(rawValue: pathfindingStyle.pathStyleBody.lineCap) ?? .round)
    //_gpsLineLayer?.lineJoin = .constant(LineJoin(rawValue: pathfindingStyle.pathStyleBody.lineJoin) ?? .round)
    _gpsLineLayer?.circleColor = .constant(StyleColor(.blue))
    _gpsLineLayer?.visibility = _mlLineLayer?.visibility
    _gpsLineLayer?.circleRadius = _mlLineLayer?.circleRadius

    _circleSource = GeoJSONSource()
    _circleSource?.data = .empty

    _circleLayer = CircleLayer(id: CIRCLE_LAYER_ID)
    _circleLayer?.source = CIRCLE_SOURCE_ID
    _circleLayer?.circleColor = .constant(.init(.purple))
    _circleLayer?.circleRadius = .expression(
      Exp(.interpolate) {
        Exp(.exponential) { 2 }
        Exp(.zoom)
        [
          0.0: 0,
          22.0 : 20_000
        ]
      }
    )

    _mlCircleSource = GeoJSONSource()
    _mlCircleSource?.data = .empty

    _mlCircleLayer = CircleLayer(id: ML_USER_LAYER_ID)
    _mlCircleLayer?.source = ML_USER_SOURCE_ID
    _mlCircleLayer?.circleColor = .constant(.init(.orange))
    _mlCircleLayer?.circleStrokeColor = .constant(.init(.white))
    _mlCircleLayer?.circleStrokeWidth = .expression(
      Exp(.interpolate) {
        Exp(.exponential) { 2 }
        Exp(.zoom)
        [
          0.0: 0,
          22.0: 50
        ]
      }
    )
    _mlCircleLayer?.circleOpacity = .constant(0.8)
    _mlCircleLayer?.circleRadius = .expression(
      Exp(.interpolate) {
        Exp(.exponential) { 2 }
        Exp(.zoom)
        [
          0.0: 0,
          22.0 : 500
        ]
      }
    )
  }

  func refreshML() {
    //currentPath = testPath
    DispatchQueue.main.async { [self] in
      //try? style.updateGeoJSONSource(withId: SOURCE_ID, geoJSON: .geometry(.lineString(LineString(currentPath))))
      try? style.updateGeoJSONSource(withId: SOURCE_ID, geoJSON: .geometry(.multiPoint(.init(currentMLPath))))
      try? style.updateGeoJSONSource(withId: QUEUE_SOURCE_ID, geoJSON: .geometry(.multiPoint(.init(currentMLPathQueue.asArray()))))
      try? style.updateGeoJSONSource(withId: GPS_SOURCE_ID, geoJSON: .geometry(.multiPoint(.init(currentGPSPath))))
      if let coordinate = currentMLPosition {
        try? style.updateGeoJSONSource(withId: ML_USER_SOURCE_ID, geoJSON: .geometry(.point(.init(coordinate))))
      } else {
        hideMLUser()
      }
    }
  }

  func refreshCircle() {
    DispatchQueue.main.async { [self] in
      try? style.updateGeoJSONSource(withId: CIRCLE_SOURCE_ID, geoJSON: .geometry(.multiPoint(MultiPoint(particleCoordinates))))
    }
  }
}

internal extension MLPositionLineController {
  func onNewPosition(coordinate: CLLocationCoordinate2D) {
    //if let last = currentPath.last {
    //  let distance = last.fromLatLngToMeter(converter: converter).distance(to: position)
    //  if distance > largestDistance { largestDistance = distance }
    //  print("Distance", largestDistance, distance)
    //}
    //if position.distance(to: lastPosition) >= 2 { reset() }
    currentMLPath.append(coordinate)
    //lastPosition = position
    refreshML()
  }

  func onNewPosition(location: VPSOutputSignal.LatLngPosition.Location) {
    currentMLPath.append(location.coordinate)
    currentMLPathQueue.enqueue(location.coordinate)
    refreshML()
  }

  func onNewPosition(latLng: VPSOutputSignal.LatLngPosition) {
    if mapRepository.displayMultiplePositions {
      currentGPSPath.append(latLng.gpsLocation.coordinate)
      currentMLPath.append(latLng.mlLocation.coordinate)
      currentMLPathQueue.enqueue(latLng.mlLocation.coordinate)
    } else {
      switch latLng.reliableSource {
      case .gps:
        currentGPSPath.append(latLng.gpsLocation.coordinate)
      case .undefined:
        break
      case .vpsML:
        currentMLPath.append(latLng.mlLocation.coordinate)
        currentMLPathQueue.enqueue(latLng.mlLocation.coordinate)
      }
    }
    refreshML()
  }

  func onNewParticles(coordinates: [CLLocationCoordinate2D]) {
    particleCoordinates = coordinates
    refreshCircle()
  }

  func reset() {
    currentMLPath.removeAll()
    currentMLPathQueue.clear()
    currentGPSPath.removeAll()
    particleCoordinates.removeAll()
    refreshML()
    refreshCircle()
  }

  func onStyleUpdated() {
    initSources()

    try? style.addSource(mlLineSource, id: SOURCE_ID)
    try? style.addLayer(mlLineLayer, layerPosition: LayerPosition.below("marker-layer"))
    try? style.addSource(mlLineSourceQueue, id: QUEUE_SOURCE_ID)
    try? style.addLayer(mlLineLayerQueue, layerPosition: LayerPosition.below("marker-layer"))
    try? style.addSource(gpsLineSource, id: GPS_SOURCE_ID)
    try? style.addLayer(gpsLineLayer, layerPosition: LayerPosition.below("marker-layer"))
    try? style.addSource(circleSource, id: CIRCLE_SOURCE_ID)
    try? style.addLayer(circleLayer, layerPosition: LayerPosition.below("marker-layer"))
    try? style.addSource(mlCircleSource, id: ML_USER_SOURCE_ID)
    try? style.addLayer(mlCircleLayer, layerPosition: LayerPosition.below("marker-layer"))
    hide()
  }
}

extension MLPositionLineController: IMLPositionLineController {
  public func show() {
    showMLPath()
    showFullMLPath()
    showFullGPSPath()
    showParticles()
    showMLUser()
  }

  public func hide() {
    hideMLPath()
    hideFullMLPath()
    hideFullGPSPath()
    hideParticles()
    hideMLUser()
  }

  public func showMLPath() {
    try? style.updateLayer(withId: QUEUE_LAYER_ID, type: CircleLayer.self) { $0.visibility = .constant(.visible) }
  }

  public func showFullMLPath() {
    try? style.updateLayer(withId: LAYER_ID, type: CircleLayer.self) { $0.visibility = .constant(.visible) }
  }

  public func showFullGPSPath() {
    try? style.updateLayer(withId: GPS_LAYER_ID, type: CircleLayer.self) { $0.visibility = .constant(.visible) }
  }

  public func showParticles() {
    try? style.updateLayer(withId: CIRCLE_LAYER_ID, type: CircleLayer.self) { $0.visibility = .constant(.visible) }
  }

  public func showMLUser() {
    guard mlCircleLayer.visibility == .constant(.none) else { return }
    try? style.updateLayer(withId: ML_USER_LAYER_ID, type: CircleLayer.self) { $0.visibility = .constant(.visible) }
    _mlCircleLayer?.visibility = .constant(.visible)
  }

  public func hideMLPath() {
    try? style.updateLayer(withId: QUEUE_LAYER_ID, type: CircleLayer.self) { $0.visibility = .constant(.none) }
  }

  public func hideFullMLPath() {
    try? style.updateLayer(withId: LAYER_ID, type: CircleLayer.self) { $0.visibility = .constant(.none) }
  }

  public func hideFullGPSPath() {
    try? style.updateLayer(withId: GPS_LAYER_ID, type: CircleLayer.self) { $0.visibility = .constant(.none) }
  }

  public func hideParticles() {
    try? style.updateLayer(withId: CIRCLE_LAYER_ID, type: CircleLayer.self) { $0.visibility = .constant(.none) }
  }

  public func hideMLUser() {
    guard mlCircleLayer.visibility == .constant(.visible) else { return }
    try? style.updateLayer(withId: ML_USER_LAYER_ID, type: CircleLayer.self) { $0.visibility = .constant(.none) }
    _mlCircleLayer?.visibility = .constant(.none)
  }
}
