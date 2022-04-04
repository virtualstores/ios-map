//
//  ZoneController.swift
//  
//
//  Created by Théodore Roos on 2022-03-31.
//

import Foundation
import MapboxMaps
import VSFoundation

class ZoneController {

  private let DEFAULT_STYLE_WALLS_LAYER = "walls"
  private let SOURCE_ZONE_LINE = "zone-line-source"
  private let SOURCE_ZONE_FILL = "zone-fill-source"
  private let SOURCE_ZONE_TEXT = "zone-text-source"
  let LAYER_ZONE_TEXT = "zone-text-layer"
  let LAYER_ZONE_LINE = "zone-line-layer"
  let LAYER_ZONE_FILL = "zone-fill-layer"

  private let PROP_SELECTED = "selected"
  private let PROP_ZONE_ID = "prop-zone-text-id"
  private let PROP_ZONE_PARENT_ID = "prop-zone-parent-id"
  private let PROP_ZONE_NAME = "prop-zone-name"
  private let PROP_ZONE_VISIBLE = "prop-zone-visible"

  private let PROP_ZONE_FILL_COLOR = "prop-zone-fill-color"
  private let PROP_ZONE_FILL_COLOR_SELECTED = "prop-zone-fill-color-selected"
  private let PROP_ZONE_LINE_COLOR = "prop-zone-line-color"
  private let PROP_ZONE_LINE_COLOR_SELECTED = "prop-zone-line-color-selected"

  private var mapRepository: MapRepository
  private var zones: [Zone] = []

  private var zoneTextFeatures: [String : Feature] = [:]
//  private var zoneTextMarks = mutableMapOf<String, TT2Feature>()

  private var zoneLineFeatures: [String : Feature] = [:]
//  private var zoneLineMarks = mutableMapOf<String, TT2Feature>()

  private var zoneFillFeatures: [String : Feature] = [:]
//  private var zoneFillMarks = mutableMapOf<String, TT2Feature>()

  var converter: ICoordinateConverter { mapRepository.mapData.converter }
  var style: Style { mapRepository.style }

  private var _zoneTextSource: GeoJSONSource?
  private var zoneTextSource: GeoJSONSource {
    guard let zoneTextSource = _zoneTextSource else { fatalError() }

    return zoneTextSource
  }

  private var _zoneFillSource: GeoJSONSource?
  private var zoneFillSource: GeoJSONSource {
    guard let zoneFillSource = _zoneFillSource else { fatalError() }

    return zoneFillSource
  }

  private var _zoneLineSource: GeoJSONSource?
  private var zoneLineSource: GeoJSONSource {
    guard let zoneLineSource = _zoneLineSource else { fatalError() }

    return zoneLineSource
  }

  private var _zoneTextLayer: SymbolLayer?
  private var zoneTextLayer: SymbolLayer {
    guard let zoneTextLayer = _zoneTextLayer else { fatalError() }

    return zoneTextLayer
  }

  private var _zoneFillLayer: FillLayer?
  private var zoneFillLayer: FillLayer {
    guard let zoneFillLayer = _zoneFillLayer else { fatalError() }

    return zoneFillLayer
  }

  private var _zoneLineLayer: LineLayer?
  private var zoneLineLayer: LineLayer {
    guard let zoneLineLayer = _zoneLineLayer else { fatalError() }

    return zoneLineLayer
  }

  init(mapRepository: MapRepository) {
    self.mapRepository = mapRepository
  }

  func onFloorChange(mapRepository: MapRepository) {
    self.mapRepository = mapRepository
  }

  func setup(zones: [Zone]) {
    zones.forEach { (zone) in
      if let point = zone.navigationPoint {
        let coordinate = CLLocationCoordinate2D(latitude: point.y, longitude: point.x)
        var textFeature = Feature(geometry: .point(Point(coordinate)))
        textFeature.properties = JSONObject()
        textFeature.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
        self.zoneTextFeatures[zone.id] = textFeature
      }

      let polygon = zone.polygon.map { CLLocationCoordinate2D(latitude: $0.y, longitude: $0.x) }
      var fillFeature = Feature(geometry: .polygon(Polygon([polygon])))
      fillFeature.properties = JSONObject()
      var selected = fillFeature.properties?[PROP_SELECTED]
      selected = .boolean(false)
      fillFeature.properties?[PROP_ZONE_VISIBLE] = selected
      self.zoneFillFeatures[zone.id] = fillFeature

      var lineFeature = Feature(geometry: .polygon(Polygon([polygon])))
      lineFeature.properties = JSONObject()
      lineFeature.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
      self.zoneLineFeatures[zone.id] = lineFeature
    }
  }

  func initSources() {
    _zoneTextSource = GeoJSONSource()
    _zoneTextSource?.data = .empty
    _zoneFillSource = GeoJSONSource()
    _zoneFillSource?.data = .empty
    _zoneLineSource = GeoJSONSource()
    _zoneLineSource?.data = .empty

    _zoneTextLayer = SymbolLayer(id: LAYER_ZONE_TEXT)
    _zoneTextLayer?.source = SOURCE_ZONE_TEXT
    _zoneTextLayer?.textColor = .constant(StyleColor(.cyan))

    _zoneFillLayer = FillLayer(id: LAYER_ZONE_FILL)
    _zoneFillLayer?.source = SOURCE_ZONE_FILL
    _zoneFillLayer?.fillColor = .constant(StyleColor(.magenta))

    _zoneLineLayer = LineLayer(id: LAYER_ZONE_LINE)
    _zoneLineLayer?.source = SOURCE_ZONE_LINE
    _zoneLineLayer?.lineColor = .constant(StyleColor(.darkText))
    _zoneLineLayer?.lineCap = .constant(.round)
    _zoneLineLayer?.lineJoin = .constant(.round)
    _zoneLineLayer?.lineWidth = .constant(5.0)
  }

  func refreshZones() {
    let filteredTexts = zoneTextFeatures.filter { ($0.value.properties?.first(where: { $0.key == self.PROP_ZONE_VISIBLE })?.value?.rawValue as? Bool ?? false) == true }
    let texts = filteredTexts.map({ $0.value })
    let textsCollection = FeatureCollection(features: texts)

    let filteredFillZones = zoneFillFeatures.filter { ($0.value.properties?.first(where: { $0.key == self.PROP_ZONE_VISIBLE })?.value?.rawValue as? Bool ?? false) == true }
    let fillZones = filteredFillZones.map({ $0.value })
    let fillCollection = FeatureCollection(features: fillZones)

    let filteredLineZones = zoneLineFeatures.filter { ($0.value.properties?.first(where: { $0.key == self.PROP_ZONE_VISIBLE })?.value?.rawValue as? Bool ?? false) == true }
    let lineZones = filteredLineZones.map({ $0.value })
    let lineCollection = FeatureCollection(features: lineZones)

    DispatchQueue.main.async {
      try? self.style.updateGeoJSONSource(withId: self.SOURCE_ZONE_TEXT, geoJSON: .featureCollection(textsCollection))
      try? self.style.updateGeoJSONSource(withId: self.SOURCE_ZONE_FILL, geoJSON: .featureCollection(fillCollection))
      try? self.style.updateGeoJSONSource(withId: self.SOURCE_ZONE_LINE, geoJSON: .featureCollection(lineCollection))
    }
  }

  func onStyleUpdated() {
    initSources()

    try? mapRepository.style.addSource(zoneTextSource, id: SOURCE_ZONE_TEXT)
    try? mapRepository.style.addLayer(zoneTextLayer, layerPosition: LayerPosition.default)

    try? mapRepository.style.addSource(zoneFillSource, id: SOURCE_ZONE_FILL)
    try? mapRepository.style.addLayer(zoneFillLayer, layerPosition: LayerPosition.default)

    try? mapRepository.style.addSource(zoneLineSource, id: SOURCE_ZONE_LINE)
    try? mapRepository.style.addLayer(zoneLineLayer, layerPosition: LayerPosition.default)
  }
}

extension ZoneController: IZoneController {
  func showTextLayer() {
    _zoneTextLayer?.visibility = .constant(.visible)
  }

  func hideTextLayer() {
    _zoneTextLayer?.visibility = .constant(.none)
  }

  func showFillLayer() {
    _zoneFillLayer?.visibility = .constant(.visible)
  }

  func hideFillLayer() {
    _zoneFillLayer?.visibility = .constant(.none)
  }

  func showLineLayer() {
    _zoneLineLayer?.visibility = .constant(.visible)
  }

  func hideLineLayer() {
    _zoneLineLayer?.visibility = .constant(.none)
  }

  func showAllLayers() {
    showTextLayer()
    showFillLayer()
    showLineLayer()
  }

  func hideAllLayers() {
    hideTextLayer()
    hideFillLayer()
    hideLineLayer()
  }

  func showAll() {

  }

  func hideAll() {

  }

  func show(zone: Zone) {
    guard let zone = zones.first(where: { $0 == zone }) else { return }

  }

  func hide(zone: Zone) {
    guard let zone = zones.first(where: { $0 == zone }) else { return }
  }

  func select(zone: Zone) {
    guard let zone = zones.first(where: { $0 == zone }) else { return }
  }

  func select(zones: [Zone]) {

  }

  func deselect(zone: Zone) {
    guard let zone = zones.first(where: { $0 == zone }) else { return }
  }

  func deselect(zones: [Zone]) {

  }

  func deselectAll() {

  }

  func updateLocation(newLocation: CGPoint) {
    refreshZones()
  }

  func setInAndOutDataListener(completion: @escaping ([String]) -> Void) {

  }
}

private extension ZoneController {
  private func showZone(zoneId: String) {
    guard
      var fillFeature = zoneFillFeatures[zoneId],
      var textFeature = zoneTextFeatures[zoneId]
    else { return }

    fillFeature.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
    textFeature.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
  }

  private func hideZone(zoneId: String) {
    guard
      var fillFeature = zoneFillFeatures[zoneId],
      var textFeature = zoneTextFeatures[zoneId]
    else { return }

    fillFeature.properties?[PROP_ZONE_VISIBLE] = .boolean(false)
    textFeature.properties?[PROP_ZONE_VISIBLE] = .boolean(false)
  }
}
