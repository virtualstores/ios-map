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
  let CIRCLE_SOURCE_ID = "particle-circle-source"
  let CIRCLE_LAYER_ID = "particle-circle"

  private var mapRepository: MapRepository
  private(set) var currentPath: [CLLocationCoordinate2D] = []
  private(set) var particleCoordinates = [CLLocationCoordinate2D]()

  private var _lineSource: GeoJSONSource?
  private var lineSource: GeoJSONSource {
    guard let lineSource = _lineSource else { fatalError("ERROOOOOOOOOR!") }
    return lineSource
  }

  private var _lineLayer: LineLayer?
  private var lineLayer: LineLayer {
    guard let lineLayer = _lineLayer else { fatalError("ERROOOOOOR") }
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

    _lineLayer = LineLayer(id: LAYER_ID)
    _lineLayer?.source = SOURCE_ID
    _lineLayer?.lineCap = .constant(LineCap(rawValue: pathfindingStyle.pathStyleBody.lineCap) ?? .round)
    _lineLayer?.lineJoin = .constant(LineJoin(rawValue: pathfindingStyle.pathStyleBody.lineJoin) ?? .round)
    _lineLayer?.lineColor = .constant(StyleColor(.red))
    _lineLayer?.visibility = .constant(.visible)
    _lineLayer?.lineWidth = .expression(
      Exp(.interpolate) {
        Exp(.exponential) { 2 }
        Exp(.zoom)
        [
          0.0: pathfindingStyle.pathStyleBody.lineWidth,
          7.5: pathfindingStyle.pathStyleBody.lineWidth * 2.5,
          10.0: pathfindingStyle.pathStyleBody.lineWidth * 5
        ]
      }
    )

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
  }

  func refreshLines() {
    DispatchQueue.main.async { [self] in
      try? style.updateGeoJSONSource(withId: SOURCE_ID, geoJSON: .geometry(.lineString(LineString(currentPath))))
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
    refreshLines()
  }

  func onNewParticles(coordinates: [CLLocationCoordinate2D]) {
    particleCoordinates = coordinates
    refreshCircle()
  }

  func reset() {
    currentPath.removeAll()
    particleCoordinates.removeAll()
  }

  func onStyleUpdated() {
    initSources()

    try? style.addSource(lineSource, id: SOURCE_ID)
    try? style.addLayer(lineLayer, layerPosition: LayerPosition.below("marker-layer"))
    try? style.addSource(circleSource, id: CIRCLE_SOURCE_ID)
    try? style.addLayer(circleLayer, layerPosition: LayerPosition.below("marker-layer"))
    hide()
  }
}

extension MLPositionLineController: IMLPositionLineController {
  public func show() {
    showMLPath()
    showParticles()
  }

  public func hide() {
    hideMLPath()
    hideParticles()
  }

  public func showMLPath() {
    try? style.updateLayer(withId: LAYER_ID, type: LineLayer.self) { $0.visibility = .constant(.visible) }
  }

  public func showParticles() {
    try? style.updateLayer(withId: CIRCLE_LAYER_ID, type: CircleLayer.self) { $0.visibility = .constant(.visible) }
  }

  public func hideMLPath() {
    try? style.updateLayer(withId: LAYER_ID, type: LineLayer.self) { $0.visibility = .constant(.none) }
  }

  public func hideParticles() {
    try? style.updateLayer(withId: CIRCLE_LAYER_ID, type: CircleLayer.self) { $0.visibility = .constant(.none) }
  }
}
