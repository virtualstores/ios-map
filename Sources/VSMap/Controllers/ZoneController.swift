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
  private var mapOptions: VSFoundation.MapOptions { mapRepository.mapOptions }
  private var sharedProperties: SharedZoneProperties?
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

  func setup(zones: [Zone], sharedProperties: SharedZoneProperties?) {
    self.sharedProperties = sharedProperties
    zones.forEach { (zone) in
      if let point = zone.navigationPoint {
        let coordinate = CLLocationCoordinate2D(latitude: point.y, longitude: point.x)
        var textFeature = Feature(geometry: .point(Point(coordinate)))
        textFeature.properties = JSONObject()
        textFeature.properties?[PROP_ZONE_ID] = .string(zone.id)
        textFeature.properties?[PROP_ZONE_PARENT_ID] = .string(zone.parent?.id ?? "")
        textFeature.properties?[PROP_ZONE_NAME] = .string(zone.name)
        textFeature.properties?[PROP_SELECTED] = .boolean(false)
        textFeature.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
        self.zoneTextFeatures[zone.id] = textFeature
      }

      let polygon = zone.polygon.map { CLLocationCoordinate2D(latitude: $0.y, longitude: $0.x) }
      let fillColor = zone.properties.fillColor ?? sharedProperties?.fillColor ?? mapOptions.zoneStyle.fillStyle.color.asHex
      let fillColorSelected = zone.properties.fillColorSelected ?? sharedProperties?.fillColorSelected ?? mapOptions.zoneStyle.fillStyle.colorSelected.asHex

      var fillFeature = Feature(geometry: .polygon(Polygon([polygon])))
      fillFeature.properties = JSONObject()
      fillFeature.properties?[PROP_ZONE_ID] = .string(zone.id)
      fillFeature.properties?[PROP_ZONE_PARENT_ID] = .string(zone.parent?.id ?? "")
      fillFeature.properties?[PROP_ZONE_NAME] = .string(zone.name)
      fillFeature.properties?[PROP_SELECTED] = .boolean(false)
      fillFeature.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
      fillFeature.properties?[PROP_ZONE_FILL_COLOR] = .string(fillColor)
      fillFeature.properties?[PROP_ZONE_FILL_COLOR_SELECTED] = .string(fillColorSelected)

      self.zoneFillFeatures[zone.id] = fillFeature

      let lineColor = zone.properties.lineColor ?? sharedProperties?.lineColor ?? mapOptions.zoneStyle.lineStyle.lineColor.asHex
      let lineColorSelected = zone.properties.lineColorSelected ?? sharedProperties?.lineColorSelected ?? mapOptions.zoneStyle.lineStyle.lineColorSelected.asHex

      var lineFeature = Feature(geometry: .polygon(Polygon([polygon])))
      lineFeature.properties = JSONObject()
      lineFeature.properties?[PROP_ZONE_ID] = .string(zone.id)
      lineFeature.properties?[PROP_ZONE_PARENT_ID] = .string(zone.parent?.id ?? "")
      lineFeature.properties?[PROP_ZONE_NAME] = .string(zone.name)
      lineFeature.properties?[PROP_SELECTED] = .boolean(false)
      lineFeature.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
      lineFeature.properties?[PROP_ZONE_LINE_COLOR] = .string(lineColor)
      lineFeature.properties?[PROP_ZONE_LINE_COLOR_SELECTED] = .string(lineColorSelected)
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

    let textSizeStops: [Double: Double] = [
      // If the map is at zoom level 12 or below,
      // set circle radius to 2
      0: mapOptions.zoneStyle.textStyle.textMinSize,
      7: (mapOptions.zoneStyle.textStyle.textMinSize + mapOptions.zoneStyle.textStyle.textMaxSize) / 2,
      // If the map is at zoom level 22 or above,
      // set circle radius to 180
      12: mapOptions.zoneStyle.textStyle.textMaxSize
    ]

    _zoneTextLayer = SymbolLayer(id: LAYER_ZONE_TEXT)
    _zoneTextLayer?.source = SOURCE_ZONE_TEXT
    _zoneTextLayer?.textField = .expression(Exp(.get) { PROP_ZONE_NAME })
    _zoneTextLayer?.textSize = .expression(
      // Produce a continuous, smooth series of values
      // between pairs of input and output values
      Exp(.interpolate) {
        // Set the interpolation type
        Exp(.exponential) { 1.75 }
        // Get current zoom level
        Exp(.zoom)
        // Use the stops defined above
        textSizeStops
      }
    )
    _zoneTextLayer?.textColor = .expression(
      Exp(.switchCase) {
        Exp(.eq) { Exp(.get) { PROP_SELECTED }; true }
        mapOptions.zoneStyle.textStyle.textColorSelected
        mapOptions.zoneStyle.textStyle.textColor
      }
    )
    _zoneTextLayer?.textOpacity = .constant(mapOptions.zoneStyle.textStyle.textOpacity)
    _zoneTextLayer?.textIgnorePlacement = .constant(mapOptions.zoneStyle.textStyle.textIgnorePlacement)
    _zoneTextLayer?.textAnchor = .constant(TextAnchor(rawValue: mapOptions.zoneStyle.textStyle.textAnchor) ?? .bottom)
    _zoneTextLayer?.textOffset = .constant(mapOptions.zoneStyle.textStyle.textOffset)
    _zoneTextLayer?.textAllowOverlap = .constant(mapOptions.zoneStyle.textStyle.textAllowOverLap)
    _zoneTextLayer?.textFont = .constant([mapOptions.zoneStyle.textStyle.textFont])
    _zoneTextLayer?.filter = Exp(.eq) { Exp(.get) { PROP_ZONE_VISIBLE }; true }

    _zoneFillLayer = FillLayer(id: LAYER_ZONE_FILL)
    _zoneFillLayer?.source = SOURCE_ZONE_FILL
    _zoneFillLayer?.fillColor = .expression(
      Exp(.switchCase) {
        Exp(.eq) { Exp(.get) { PROP_SELECTED }; true }
        Exp(.get) { PROP_ZONE_FILL_COLOR_SELECTED }
        Exp(.get) { PROP_ZONE_FILL_COLOR }
      }
    )
    _zoneFillLayer?.fillOpacity = .constant(mapOptions.zoneStyle.fillStyle.alpha)
    _zoneFillLayer?.filter = Exp(.eq) { Exp(.get) { PROP_ZONE_VISIBLE }; true }

    let lineWidthStops: [Double : Double] = [
      0.0: mapOptions.zoneStyle.lineStyle.lineWidth,
      7.5: mapOptions.zoneStyle.lineStyle.lineWidth,
      10.0: mapOptions.zoneStyle.lineStyle.lineWidth * 5
    ]
    _zoneLineLayer = LineLayer(id: LAYER_ZONE_LINE)
    _zoneLineLayer?.source = SOURCE_ZONE_LINE
    _zoneLineLayer?.lineColor = .expression(
      Exp(.switchCase) {
        Exp(.eq) { Exp(.get) { PROP_SELECTED }; true }
        Exp(.get) { PROP_ZONE_LINE_COLOR_SELECTED }
        Exp(.get) { PROP_ZONE_LINE_COLOR }
      }
    )
    _zoneLineLayer?.lineCap = .constant(.round)
    _zoneLineLayer?.lineJoin = .constant(.round)
    _zoneLineLayer?.lineWidth = .expression(
      Exp(.interpolate) {
        Exp(.exponential) { 1.75 }
        Exp(.zoom)
        lineWidthStops
      }
    )
    _zoneLineLayer?.filter = Exp(.eq) { Exp(.get) { PROP_ZONE_VISIBLE }; true }
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

    try? self.style.updateGeoJSONSource(withId: self.SOURCE_ZONE_TEXT, geoJSON: .featureCollection(textsCollection))
    try? self.style.updateGeoJSONSource(withId: self.SOURCE_ZONE_FILL, geoJSON: .featureCollection(fillCollection))
    try? self.style.updateGeoJSONSource(withId: self.SOURCE_ZONE_LINE, geoJSON: .featureCollection(lineCollection))
  }

  func onStyleUpdated() {
    initSources()

    try? mapRepository.style.addSource(zoneTextSource, id: SOURCE_ZONE_TEXT)
    try? mapRepository.style.addLayer(zoneTextLayer, layerPosition: LayerPosition.default)

    try? mapRepository.style.addSource(zoneLineSource, id: SOURCE_ZONE_LINE)
    try? mapRepository.style.addLayer(zoneLineLayer, layerPosition: LayerPosition.below(DEFAULT_STYLE_WALLS_LAYER))

    try? mapRepository.style.addSource(zoneFillSource, id: SOURCE_ZONE_FILL)
    try? mapRepository.style.addLayer(zoneFillLayer, layerPosition: LayerPosition.below(LAYER_ZONE_LINE))

    refreshZones()
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
    zoneTextFeatures[zone.id]?.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
    zoneFillFeatures[zone.id]?.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
    zoneLineFeatures[zone.id]?.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
    refreshZones()
  }

  func hide(zone: Zone) {
    zoneTextFeatures[zone.id]?.properties?[PROP_ZONE_VISIBLE] = .boolean(false)
    zoneFillFeatures[zone.id]?.properties?[PROP_ZONE_VISIBLE] = .boolean(false)
    zoneLineFeatures[zone.id]?.properties?[PROP_ZONE_VISIBLE] = .boolean(false)
    refreshZones()
  }

  func select(zone: Zone) {
    zoneTextFeatures[zone.id]?.properties?[PROP_SELECTED] = .boolean(true)
    zoneFillFeatures[zone.id]?.properties?[PROP_SELECTED] = .boolean(true)
    zoneLineFeatures[zone.id]?.properties?[PROP_SELECTED] = .boolean(true)
    refreshZones()
  }

  func select(zones: [Zone]) {
    refreshZones()
  }

  func deselect(zone: Zone) {
    zoneTextFeatures[zone.id]?.properties?[PROP_SELECTED] = .boolean(false)
    zoneFillFeatures[zone.id]?.properties?[PROP_SELECTED] = .boolean(false)
    zoneLineFeatures[zone.id]?.properties?[PROP_SELECTED] = .boolean(false)
    refreshZones()
  }

  func deselect(zones: [Zone]) {
    refreshZones()
  }

  func deselectAll() {
    refreshZones()
  }

  func updateLocation(newLocation: CGPoint) {
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
