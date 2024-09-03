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
  let CIRCLE_SOURCE_ID = "particle-circle-source"
  let CIRCLE_LAYER_ID = "particle-circle"
  let ML_USER_SOURCE_ID = "ml-position-circle-source"
  let ML_USER_LAYER_ID = "ml-position-circle"

  private var mapRepository: MapRepository
  private(set) var currentPath: [CLLocationCoordinate2D] = []
  private(set) var currentPathQueue: Queue<CLLocationCoordinate2D> = .init(timeout: 30_000)
  private(set) var particleCoordinates = [CLLocationCoordinate2D]()
  private var currentMLPosition: CLLocationCoordinate2D? { currentPath.last }

  private var _lineSource: GeoJSONSource?
  private var lineSource: GeoJSONSource {
    guard let lineSource = _lineSource else { fatalError("ERROOOOOOOOOR!") }
    return lineSource
  }

  private var _lineLayer: CircleLayer?
  private var lineLayer: CircleLayer {
    guard let lineLayer = _lineLayer else { fatalError("ERROOOOOOR") }
    return lineLayer
  }

  private var _lineSourceQueue: GeoJSONSource?
  private var lineSourceQueue: GeoJSONSource {
    guard let lineSource = _lineSourceQueue else { fatalError("ERROOOOOOOOOR!") }
    return lineSource
  }

  private var _lineLayerQueue: CircleLayer?
  private var lineLayerQueue: CircleLayer {
    guard let lineLayer = _lineLayerQueue else { fatalError("ERROOOOOOR") }
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
    _lineSource = GeoJSONSource()
    _lineSource?.data = .empty

    _lineLayer = CircleLayer(id: LAYER_ID)
    _lineLayer?.source = SOURCE_ID
    //_lineLayer?.lineCap = .constant(LineCap(rawValue: pathfindingStyle.pathStyleBody.lineCap) ?? .round)
    //_lineLayer?.lineJoin = .constant(LineJoin(rawValue: pathfindingStyle.pathStyleBody.lineJoin) ?? .round)
    _lineLayer?.circleColor = .constant(StyleColor(.orange))
    _lineLayer?.visibility = .constant(.visible)
    _lineLayer?.circleRadius = .expression(
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

    _lineSourceQueue = GeoJSONSource()
    _lineSourceQueue?.data = .empty

    _lineLayerQueue = CircleLayer(id: QUEUE_LAYER_ID)
    _lineLayerQueue?.source = QUEUE_SOURCE_ID
    //_lineLayer?.lineCap = .constant(LineCap(rawValue: pathfindingStyle.pathStyleBody.lineCap) ?? .round)
    //_lineLayer?.lineJoin = .constant(LineJoin(rawValue: pathfindingStyle.pathStyleBody.lineJoin) ?? .round)
    _lineLayerQueue?.circleColor = _lineLayer?.circleColor
    _lineLayerQueue?.visibility = _lineLayer?.visibility
    _lineLayerQueue?.circleRadius = _lineLayer?.circleRadius

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
      try? style.updateGeoJSONSource(withId: SOURCE_ID, geoJSON: .geometry(.multiPoint(.init(currentPath))))
      try? style.updateGeoJSONSource(withId: QUEUE_SOURCE_ID, geoJSON: .geometry(.multiPoint(.init(currentPathQueue.asArray()))))
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
    currentPath.append(coordinate)
    //lastPosition = position
    refreshML()
  }

  func onNewPosition(location: VPSOutputSignal.LatLngPosition.Location) {
    currentPath.append(location.coordinate)
    currentPathQueue.enqueue(location.coordinate)
    refreshML()
  }

  func onNewParticles(coordinates: [CLLocationCoordinate2D]) {
    particleCoordinates = coordinates
    refreshCircle()
  }

  func reset() {
    currentPath.removeAll()
    particleCoordinates.removeAll()
    refreshML()
    refreshCircle()
  }

  func onStyleUpdated() {
    initSources()

    try? style.addSource(lineSource, id: SOURCE_ID)
    try? style.addLayer(lineLayer, layerPosition: LayerPosition.below("marker-layer"))
    try? style.addSource(lineSourceQueue, id: QUEUE_SOURCE_ID)
    try? style.addLayer(lineLayerQueue, layerPosition: LayerPosition.below("marker-layer"))
    try? style.addSource(circleSource, id: CIRCLE_SOURCE_ID)
    try? style.addLayer(circleLayer, layerPosition: LayerPosition.below("marker-layer"))
    try? style.addSource(mlCircleSource, id: ML_USER_SOURCE_ID)
    try? style.addLayer(mlCircleLayer, layerPosition: LayerPosition.below("marker-layer"))
    hide()
    //showMLUser()
    //refreshML()
  }
}

extension MLPositionLineController: IMLPositionLineController {
  public func show() {
    showMLPath()
    showFullMLPath()
    showParticles()
    showMLUser()
  }

  public func hide() {
    hideMLPath()
    hideFullMLPath()
    hideParticles()
    hideMLUser()
  }

  public func showMLPath() {
    try? style.updateLayer(withId: QUEUE_LAYER_ID, type: LineLayer.self) { $0.visibility = .constant(.visible) }
  }

  public func showFullMLPath() {
    try? style.updateLayer(withId: LAYER_ID, type: LineLayer.self) { $0.visibility = .constant(.visible) }
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
    try? style.updateLayer(withId: QUEUE_LAYER_ID, type: LineLayer.self) { $0.visibility = .constant(.none) }
  }

  public func hideFullMLPath() {
    try? style.updateLayer(withId: LAYER_ID, type: LineLayer.self) { $0.visibility = .constant(.none) }
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
