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

  private var mapRepository: MapRepository
  private var currentPath: [CLLocationCoordinate2D] = []

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
  }

  func refreshLines() {
    DispatchQueue.main.async { [self] in
      try? style.updateGeoJSONSource(withId: SOURCE_ID, geoJSON: .geometry(.lineString(LineString(currentPath))))
    }
  }
}

internal extension MLPositionLineController {
  func onNewPosition(position: CGPoint) {
    //if let last = currentPath.last {
    //  let distance = last.fromLatLngToMeter(converter: converter).distance(to: position)
    //  if distance > largestDistance { largestDistance = distance }
    //  print("Distance", largestDistance, distance)
    //}
    if position.distance(to: lastPosition) >= 2 { reset() }
    currentPath.append(position.convertFromMeterToLatLng(converter: converter))
    lastPosition = position
    refreshLines()
  }

  func reset() {
    currentPath.removeAll()
  }

  func onStyleUpdated() {
    initSources()

    try? style.addSource(lineSource, id: SOURCE_ID)
    try? style.addLayer(lineLayer, layerPosition: LayerPosition.below("marker-layer"))
    hide()
  }
}

extension MLPositionLineController: IMLPositionLineController {
  public func show() {
    try? style.updateLayer(withId: LAYER_ID, type: LineLayer.self) { $0.visibility = .constant(.visible) }
  }

  public func hide() {
    try? style.updateLayer(withId: LAYER_ID, type: LineLayer.self) { $0.visibility = .constant(.none) }
  }
}
