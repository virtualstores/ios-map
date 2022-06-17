//
//  ShelfController.swift
//  
//
//  Created by Théodore Roos on 2022-06-10.
//

import Foundation
import VSFoundation
import CoreGraphics
import MapboxMaps
import Combine

class ShelfController: IShelfController {
  private let DEFAULT_STYLE_SHELVES_LAYER = "shelves"
  private let DEFAULT_STYLE_WALLS_LAYER = "walls"
  private let SHELVES_SOURCE = "shelves-source"
  private let SHELVES_FILL_LAYER = "shelves-layer"
  private let SHELVES_OUTLINES_LAYER = "shelves-outlines-layer"

  private let PROP_SELECTED = "shelf-selected"
  private let PROP_VISIBLE = "shelf-visible"
  private let PROP_MARKED = "shelf-marked"
  private let MARKED_SHELVES_SOURCE = "marked-shelves-source"
  private let MARKED_SHELVES_LAYER = "marked-shelves-layer"

  var shelves: [Shelf] = []
  private var shelvesFeatures = [String : Feature]()
  private var shelvesMarkedFeatures = [String : Feature]()
  var onShelfClicked: CurrentValueSubject<Shelf?, Never> = .init(nil)

  private var mapRepository: MapRepository

  private var mapOptions: VSFoundation.MapOptions { mapRepository.mapOptions }
  private var shelfOptions: VSFoundation.MapOptions.ShelfStyle { mapOptions.shelfStyle }
  private var shelfOptionsSelected: VSFoundation.MapOptions.ShelfStyle { mapOptions.shelfStyleSelected }
  private var floorLevelId: Int64 { mapRepository.floorLevelId }
  private var converter: ICoordinateConverter { mapRepository.mapData.converter }

  private var _shelvesSource: GeoJSONSource? = nil
  private var shelvesSource: GeoJSONSource {
    guard let shelvesSource = _shelvesSource else { fatalError("shelvesSource is not initialized") }

    return shelvesSource
  }

  private var _shelvesFillLayer: FillExtrusionLayer?
  private var shelvesFillLayer: FillExtrusionLayer {
    guard let shelvesFillLayer = _shelvesFillLayer else { fatalError("shelvesFillLayer is not initialized") }

    return shelvesFillLayer
  }

  private var _markedShelvesSource: GeoJSONSource? = nil
  private var markedShelvesSource: GeoJSONSource {
    guard let markedShelvesSource = _markedShelvesSource else { fatalError("markedShelvesSource is not initalized") }

    return markedShelvesSource
  }

  private var _shelvesLineLayer: LineLayer?
  private var shelvesLineLayer: LineLayer {
    guard let shelvesLineLayer = _shelvesLineLayer else { fatalError("shelvesLineLayer is not initialized") }

    return shelvesLineLayer
  }

  private var _markedShelvesFillLayer: CircleLayer?
  private var markedShelvesFillLayer: CircleLayer {
    guard let markedShelvesFillLayer = _markedShelvesFillLayer else { fatalError("markedShelvesFillLayer is not initialized") }

    return markedShelvesFillLayer
  }

  init(mapRepository: MapRepository) {
    self.mapRepository = mapRepository
  }

  func onFloorChange(mapRepository: MapRepository) {
    self.mapRepository = mapRepository
  }

  func initSources() {
    _shelvesSource = GeoJSONSource()
    _shelvesSource?.data = .empty

    // MARK: ShelvesFill
    _shelvesFillLayer = FillExtrusionLayer(id: SHELVES_FILL_LAYER)
    _shelvesFillLayer?.source = SHELVES_SOURCE

    _shelvesFillLayer?.visibility = .constant(.none)
    _shelvesFillLayer?.fillExtrusionBase = .constant(0.0)
    _shelvesFillLayer?.fillExtrusionHeight = .constant(shelfOptions.shelfHeight)
    _shelvesFillLayer?.fillExtrusionOpacity = .constant(1.0)
    _shelvesFillLayer?.fillExtrusionColor = .expression(
      Exp(.switchCase) {
        Exp(.eq) { Exp(.get) { PROP_SELECTED }; true }
        shelfOptionsSelected.fillStyle.color
        shelfOptions.fillStyle.color
      }
    )
    _shelvesFillLayer?.filter = Exp(.eq) { Exp(.get) { PROP_VISIBLE }; true }

    // MARK: ShelvesLine
    _shelvesLineLayer = LineLayer(id: SHELVES_OUTLINES_LAYER)
    _shelvesLineLayer?.source = SHELVES_SOURCE

    _shelvesLineLayer?.visibility = .constant(.none)
    _shelvesLineLayer?.lineWidth = .expression(
      Exp(.switchCase) {
        Exp(.eq) { Exp(.get) { PROP_SELECTED }; true }
        shelfOptionsSelected.lineStyle.lineWidth
        shelfOptions.lineStyle.lineWidth
      }
    )
    _shelvesLineLayer?.lineColor = .expression(
      Exp(.switchCase) {
        Exp(.eq) { Exp(.get) { PROP_SELECTED }; true }
        shelfOptionsSelected.lineStyle.lineColor
        shelfOptions.lineStyle.lineColor
      }
    )
    _shelvesLineLayer?.lineJoin = .expression(
      Exp(.switchCase) {
        Exp(.eq) { Exp(.get) { PROP_SELECTED }; true }
        shelfOptionsSelected.lineStyle.lineCap
        shelfOptions.lineStyle.lineCap
      }
    )
    _shelvesLineLayer?.lineCap = .expression(
      Exp(.switchCase) {
        Exp(.eq) { Exp(.get) { PROP_SELECTED }; true }
        shelfOptionsSelected.lineStyle.lineCap
        shelfOptions.lineStyle.lineCap
      }
    )
    _shelvesLineLayer?.filter = Exp(.eq) { Exp(.get) { PROP_VISIBLE }; true }

    // MARK: MarkedShelves
    _markedShelvesSource = GeoJSONSource()
    _markedShelvesSource?.data = .empty

    _markedShelvesFillLayer = CircleLayer(id: MARKED_SHELVES_LAYER)
    _markedShelvesFillLayer?.source = MARKED_SHELVES_SOURCE

    _markedShelvesFillLayer?.visibility = .constant(.none)
    _markedShelvesFillLayer?.circleRadius = .constant(4.0)
    _markedShelvesFillLayer?.circleColor = .constant(StyleColor(.white))
    _markedShelvesFillLayer?.filter = Exp(.eq) { Exp(.get) { PROP_VISIBLE }; true }
  }

  func updateMarkedShelves() {
    shelvesMarkedFeatures.removeAll()
    shelves.filter { $0.isMarked }.forEach { (shelf) in
      let avgX = shelf.shape.map { $0.x }.reduce(0, +) / CGFloat(shelf.shape.count)
      let avgY = shelf.shape.map { $0.y }.reduce(0, +) / CGFloat(shelf.shape.count)
      let coordinate = CGPoint(x: avgX, y: avgY).convertFromMeterToLatLng(converter: converter)

      var feature = Feature(geometry: .point(Point(coordinate)))

      feature.identifier = .string(shelf.name)
      feature.properties = JSONObject()
      feature.properties?[PROP_SELECTED] = .boolean(shelf.isSelected)
      feature.properties?[PROP_VISIBLE] = .boolean(shelf.isVisible)
      feature.properties?[PROP_MARKED] = .boolean(shelf.isMarked)

      self.shelvesMarkedFeatures[shelf.name] = feature
    }
    refreshShelves()
  }

  func updateShelves() {
    shelvesFeatures.removeAll()
    shelves.forEach { (shelf) in
      let clockwisePoints = sortVerticiesClockwise(points: shelf.shape)
      let coordinates = clockwisePoints.map { $0.convertFromMeterToLatLng(converter: converter) }

      var feature = Feature(geometry: .multiPoint(MultiPoint(coordinates)))

      feature.identifier = .string(shelf.name)
      feature.properties = JSONObject()
      feature.properties?[PROP_SELECTED] = .boolean(shelf.isSelected)
      feature.properties?[PROP_VISIBLE] = .boolean(shelf.isVisible)
      feature.properties?[PROP_MARKED] = .boolean(shelf.isMarked)

      self.shelvesFeatures[shelf.name] = feature
    }
    refreshShelves()
  }

  func refreshShelves() {
    let shelves = shelvesFeatures.map { $0.value }
    let collection = FeatureCollection(features: shelves)

    let markedShelves = shelvesMarkedFeatures.map { $0.value }
    let markedCollection = FeatureCollection(features: markedShelves)

    try? mapRepository.style.updateGeoJSONSource(withId: SHELVES_SOURCE, geoJSON: .featureCollection(collection))
    try? mapRepository.style.updateGeoJSONSource(withId: MARKED_SHELVES_SOURCE, geoJSON: .featureCollection(markedCollection))
  }

  func findCentroid(points: [CGPoint]) -> CGPoint {
    var x = 0.0
    var y = 0.0
    points.forEach {
      x += $0.x
      y += $0.y
    }
    var center: CGPoint = .zero
    center.x = x / Double(points.count)
    center.y = y / Double(points.count)
    return center
  }

  func sortVerticiesClockwise(points: [CGPoint]) -> [CGPoint] {
    // get centroid
    let center = findCentroid(points: points)
    let sortedPoints = points.sorted { (a, b) in
      let a1 = (atan2(a.x - center.x, a.y - center.y).toDegrees + 360).truncatingRemainder(dividingBy: 360)
      let a2 = (atan2(b.x - center.x, b.y - center.y).toDegrees + 360).truncatingRemainder(dividingBy: 360)
      return a1 < a2
    }

    return sortedPoints
  }

  func onStyleUpdated() {
    initSources()

    try? mapRepository.style.addSource(shelvesSource, id: SHELVES_SOURCE)
    try? mapRepository.style.addSource(markedShelvesSource, id: MARKED_SHELVES_SOURCE)

    try? mapRepository.style.addLayer(shelvesFillLayer, layerPosition: .above(DEFAULT_STYLE_SHELVES_LAYER))
    try? mapRepository.style.addLayer(shelvesFillLayer, layerPosition: .above(DEFAULT_STYLE_WALLS_LAYER))
    try? mapRepository.style.addLayer(shelvesLineLayer, layerPosition: .below(SHELVES_FILL_LAYER))
    try? mapRepository.style.addLayer(markedShelvesFillLayer, layerPosition: .above(DEFAULT_STYLE_SHELVES_LAYER))
    try? mapRepository.style.addLayer(markedShelvesFillLayer, layerPosition: .above(DEFAULT_STYLE_WALLS_LAYER))
  }
}

extension ShelfController {
  func showAllShelfLayers() {
    showShelvesMarkLayer()
    showShelvesFillLayer()
    showShelvesLineLayer()
  }

  func hideAllShelfLayers() {
    hideShelvesMarkLayer()
    hideShelvesFillLayer()
    hideShelvesLineLayer()
  }

  func showShelvesLineLayer() {
    try? mapRepository.style.updateLayer(withId: SHELVES_OUTLINES_LAYER, type: LineLayer.self) { $0.visibility = .constant(.visible); print("updating shelf", $0.id) }
  }

  func showShelvesMarkLayer() {
    try? mapRepository.style.updateLayer(withId: MARKED_SHELVES_LAYER, type: CircleLayer.self) { $0.visibility = .constant(.visible); print("updating shelf", $0.id) }
  }

  func showShelvesFillLayer() {
    try? mapRepository.style.updateLayer(withId: SHELVES_FILL_LAYER, type: FillLayer.self) { $0.visibility = .constant(.visible); print("updating shelf", $0.id) }
  }

  func hideShelvesLineLayer() {
    try? mapRepository.style.updateLayer(withId: SHELVES_OUTLINES_LAYER, type: LineLayer.self) { $0.visibility = .constant(.none); print("updating shelf", $0.id) }
  }

  func hideShelvesMarkLayer() {
    try? mapRepository.style.updateLayer(withId: MARKED_SHELVES_LAYER, type: CircleLayer.self) { $0.visibility = .constant(.none); print("updating shelf", $0.id) }
  }

  func hideShelvesFillLayer() {
    try? mapRepository.style.updateLayer(withId: SHELVES_FILL_LAYER, type: FillLayer.self) { $0.visibility = .constant(.none); print("updating shelf", $0.id) }
  }

  func setShelves(shelves: [ShelfGroup]) {
    self.shelves = shelves.flatMap { $0.shelves }
//    updateShelves()
  }

  func show(shelf: Shelf) {
    modify(shelf: shelf, type: .visible, bool: true)
    updateShelves()
  }

  func showAll() {
    shelves.forEach { modify(shelf: $0, type: .visible, bool: true) }
    updateShelves()
  }

  func hide(shelf: Shelf) {
    modify(shelf: shelf, type: .visible, bool: false)
    updateShelves()
  }

  func hideAll() {
    shelves.forEach { modify(shelf: $0, type: .visible, bool: false) }
    updateShelves()
  }

  func select(shelf: Shelf?) {
    guard let shelf = shelf else { return }
    modify(shelf: shelf, type: .selected, bool: true)
    updateShelves()
  }

  func deselect(shelf: Shelf?) {
    guard let shelf = shelf else { return }
    modify(shelf: shelf, type: .selected, bool: false)
    updateShelves()
  }

  func deselectAll() {
    shelves.forEach { modify(shelf: $0, type: .selected, bool: false) }
    updateShelves()
  }

  func markShelf(shelf: Shelf) {
    modify(shelf: shelf, type: .marked, bool: true)
    updateMarkedShelves()
  }

  func clearMarkedShelf(shelf: Shelf) {
    modify(shelf: shelf, type: .selected, bool: false)
    updateMarkedShelves()
  }

  func clearAllMarkedShelves() {
    shelves.forEach { modify(shelf: $0, type: .selected, bool: false) }
    updateMarkedShelves()
  }
}

private extension ShelfController {
  enum ModifyShelf {
    case visible
    case selected
    case marked
  }

  func modify(shelf: Shelf, type: ModifyShelf, bool: Bool) {
    guard let shelf = shelves.first(where: { $0.name == shelf.name }) else { return }
    switch type {
    case .visible: shelf.isVisible = bool
    case .selected: shelf.isSelected = bool
    case .marked: shelf.isMarked = bool
    }
  }
}

extension CGFloat {
  var toDegrees: CGFloat { self * (180 / .pi) }
}
