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

  private let PROP_ZONE_TEXT_COLOR = "prop-zone-text-color"
  private let PROP_ZONE_TEXT_COLOR_SELECTED = "prop-zone-text-color-selected"
  private let PROP_ZONE_TEXT_SIZE = "prop-zone-text-size"
  private let PROP_ZONE_TEXT_OPACITY = "prop-zone-text-opacity"
  private let PROP_ZONE_TEXT_ALLOW_OVERLAP = "prop-zone-text-allow-overlap"
  private let PROP_ZONE_TEXT_IGNORE_PLACEMENT = "prop-zone-text-ignore-placement"
  private let PROP_ZONE_TEXT_ANCHOR = "prop-zone-text-anchor"

  private let PROP_ZONE_FILL_COLOR = "prop-zone-fill-color"
  private let PROP_ZONE_FILL_COLOR_SELECTED = "prop-zone-fill-color-selected"
  private let PROP_ZONE_FILL_ALPHA = "prop-zone-fill-alpha"

  private let PROP_ZONE_LINE_COLOR = "prop-zone-line-color"
  private let PROP_ZONE_LINE_COLOR_SELECTED = "prop-zone-line-color-selected"
  private let PROP_ZONE_LINE_OPACITY = "prop-zone-line-opacity"
  private let PROP_ZONE_LINE_WIDTH = "prop-zone-line-width"
  private let PROP_ZONE_LINE_WIDTH_SCALED = "prop-zone-line-width-scaled"

  private var mapRepository: MapRepository
  private var mapOptions: VSFoundation.MapOptions { mapRepository.mapOptions }
  private var sharedProperties: SharedZoneProperties?
  public private(set) var zones: [Zone] = []

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
    self.zoneTextFeatures.removeAll()
    self.zoneFillFeatures.removeAll()
    self.zoneLineFeatures.removeAll()
    self.sharedProperties = sharedProperties
    zones.forEach { (zone) in
      if let point = zone.navigationPoint {
        let coordinate = CLLocationCoordinate2D(latitude: point.y, longitude: point.x)
        let textStyle = mapOptions.zoneStyle.textStyle
        let textColor = zone.properties.textColor ?? sharedProperties?.textColor ?? textStyle.textColor.asHex
        let textColorSelected = zone.properties.textColorSelected ?? sharedProperties?.textColorSelected ?? textStyle.textColorSelected.asHex
        let textSize = zone.properties.textSize ?? sharedProperties?.textSize ?? textStyle.textMaxSize
        let textOpacity = zone.properties.textOpacity ?? sharedProperties?.textOpacity ?? textStyle.textOpacity
        let textAllowOverlap = zone.properties.textAllowOverLap ?? sharedProperties?.textAllowOverLap ?? textStyle.textAllowOverLap
        let textAnchor = zone.properties.textAnchor ?? sharedProperties?.textAnchor ?? textStyle.textAnchor
        let textIgnorePlacement = zone.properties.textIgnorePlacement ?? sharedProperties?.textIgnorePlacement ?? textStyle.textIgnorePlacement
        var textFeature = Feature(geometry: .point(Point(coordinate)))
        textFeature.properties = JSONObject()
        textFeature.properties?[PROP_ZONE_ID] = .string(zone.id)
        textFeature.properties?[PROP_ZONE_PARENT_ID] = .string(zone.parent?.id ?? "")
        textFeature.properties?[PROP_ZONE_NAME] = .string(zone.name)
        textFeature.properties?[PROP_SELECTED] = .boolean(false)
        textFeature.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
        textFeature.properties?[PROP_ZONE_TEXT_COLOR] = .string(textColor)
        textFeature.properties?[PROP_ZONE_TEXT_COLOR_SELECTED] = .string(textColorSelected)
        textFeature.properties?[PROP_ZONE_TEXT_SIZE] = .number(textSize)
        textFeature.properties?[PROP_ZONE_TEXT_OPACITY] = .number(textOpacity)
        textFeature.properties?[PROP_ZONE_TEXT_ALLOW_OVERLAP] = .boolean(textAllowOverlap)
        textFeature.properties?[PROP_ZONE_TEXT_IGNORE_PLACEMENT] = .boolean(textIgnorePlacement)
        textFeature.properties?[PROP_ZONE_TEXT_ANCHOR] = .string(textAnchor)
        self.zoneTextFeatures[zone.id] = textFeature
      }

      let polygon = zone.polygon.map { CLLocationCoordinate2D(latitude: $0.y, longitude: $0.x) }
      let fillColor = zone.properties.fillColor ?? sharedProperties?.fillColor ?? mapOptions.zoneStyle.fillStyle.color.asHex
      let fillColorSelected = zone.properties.fillColorSelected ?? sharedProperties?.fillColorSelected ?? mapOptions.zoneStyle.fillStyle.colorSelected.asHex
      let fillAlpha = zone.properties.fillAlpha ?? sharedProperties?.fillAlpha ?? mapOptions.zoneStyle.fillStyle.alpha

      var fillFeature = Feature(geometry: .polygon(Polygon([polygon])))
      fillFeature.properties = JSONObject()
      fillFeature.properties?[PROP_ZONE_ID] = .string(zone.id)
      fillFeature.properties?[PROP_ZONE_PARENT_ID] = .string(zone.parent?.id ?? "")
      fillFeature.properties?[PROP_ZONE_NAME] = .string(zone.name)
      fillFeature.properties?[PROP_SELECTED] = .boolean(false)
      fillFeature.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
      fillFeature.properties?[PROP_ZONE_FILL_COLOR] = .string(fillColor)
      fillFeature.properties?[PROP_ZONE_FILL_COLOR_SELECTED] = .string(fillColorSelected)
      fillFeature.properties?[PROP_ZONE_FILL_ALPHA] = .number(fillAlpha)

      self.zoneFillFeatures[zone.id] = fillFeature

      let lineColor = zone.properties.lineColor ?? sharedProperties?.lineColor ?? mapOptions.zoneStyle.lineStyle.lineColor.asHex
      let lineColorSelected = zone.properties.lineColorSelected ?? sharedProperties?.lineColorSelected ?? mapOptions.zoneStyle.lineStyle.lineColorSelected.asHex
      let lineOpacity = zone.properties.lineOpacity ?? sharedProperties?.lineOpacity ?? mapOptions.zoneStyle.lineStyle.lineOpacity
      let lineWidth = zone.properties.lineWidth ?? sharedProperties?.lineWidth ?? mapOptions.zoneStyle.lineStyle.lineWidth

      var lineFeature = Feature(geometry: .polygon(Polygon([polygon])))
      lineFeature.properties = JSONObject()
      lineFeature.properties?[PROP_ZONE_ID] = .string(zone.id)
      lineFeature.properties?[PROP_ZONE_PARENT_ID] = .string(zone.parent?.id ?? "")
      lineFeature.properties?[PROP_ZONE_NAME] = .string(zone.name)
      lineFeature.properties?[PROP_SELECTED] = .boolean(false)
      lineFeature.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
      lineFeature.properties?[PROP_ZONE_LINE_COLOR] = .string(lineColor)
      lineFeature.properties?[PROP_ZONE_LINE_COLOR_SELECTED] = .string(lineColorSelected)
      lineFeature.properties?[PROP_ZONE_LINE_OPACITY] = .number(lineOpacity)
      lineFeature.properties?[PROP_ZONE_LINE_WIDTH] = .number(lineWidth)
      lineFeature.properties?[PROP_ZONE_LINE_WIDTH_SCALED] = .number(lineWidth * 5)
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
      0: mapOptions.zoneStyle.textStyle.textMinSize,
      7: (mapOptions.zoneStyle.textStyle.textMinSize + mapOptions.zoneStyle.textStyle.textMaxSize) / 2,
      12: mapOptions.zoneStyle.textStyle.textMaxSize
    ]

    _zoneTextLayer = SymbolLayer(id: LAYER_ZONE_TEXT)
    _zoneTextLayer?.source = SOURCE_ZONE_TEXT
    _zoneTextLayer?.textField = .expression(Exp(.get) { PROP_ZONE_NAME })
    _zoneTextLayer?.textMaxWidth = .constant(5)
    _zoneTextLayer?.textSize = .expression(
      // Produce a continuous, smooth series of values
      // between pairs of input and output values
      Exp(.interpolate) {
        // Set the interpolation type
        Exp(.exponential) { 1.0 }
        // Get current zoom level
        Exp(.zoom)
        // Use the stops defined above
        textSizeStops
      }
    )
    _zoneTextLayer?.textColor = .expression(
      Exp(.switchCase) {
        Exp(.eq) { Exp(.get) { PROP_SELECTED }; true }
        Exp(.get) { PROP_ZONE_TEXT_COLOR_SELECTED }
        Exp(.get) { PROP_ZONE_TEXT_COLOR }
      }
    )
    _zoneTextLayer?.textOpacity = .expression(Exp(.get) { PROP_ZONE_TEXT_OPACITY })
//    _zoneTextLayer?.textIgnorePlacement = .expression(Exp(.get) { PROP_ZONE_TEXT_IGNORE_PLACEMENT })
    _zoneTextLayer?.textAnchor = .expression(Exp(.get) { PROP_ZONE_TEXT_ANCHOR })
    _zoneTextLayer?.textOffset = .constant(mapOptions.zoneStyle.textStyle.textOffset)
//    _zoneTextLayer?.textAllowOverlap = .expression(Exp(.get) { PROP_ZONE_TEXT_ALLOW_OVERLAP })
    _zoneTextLayer?.textFont = .constant([mapOptions.zoneStyle.textStyle.textFont])
    _zoneTextLayer?.textSize = .expression(Exp(.get) { PROP_ZONE_TEXT_SIZE })
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
    _zoneFillLayer?.fillOpacity = .expression(Exp(.get) { PROP_ZONE_FILL_ALPHA })
    _zoneFillLayer?.filter = Exp(.eq) { Exp(.get) { PROP_ZONE_VISIBLE }; true }

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
    _zoneLineLayer?.lineOpacity = .expression(Exp(.get) { PROP_ZONE_LINE_OPACITY })
    _zoneLineLayer?.lineWidth = .expression(
      Exp(.interpolate) {
        Exp(.exponential) { 1.75 }
        Exp(.zoom)
        [
        0.0: Exp(.get) { PROP_ZONE_LINE_WIDTH },
        7.5: Exp(.get) { PROP_ZONE_LINE_WIDTH },
        10.0: Exp(.get) { PROP_ZONE_LINE_WIDTH_SCALED }
        ]
      }
    )
    _zoneLineLayer?.filter = Exp(.eq) { Exp(.get) { PROP_ZONE_VISIBLE }; true }
  }

  func refreshZones() {
    let filteredTexts = zoneTextFeatures.filter { ($0.value.properties?.first(where: { $0.key == self.PROP_ZONE_VISIBLE })?.value?.rawValue as? Bool ?? false) == true }
    let texts = filteredTexts.map { $0.value }
    let textsCollection = FeatureCollection(features: texts)

    let filteredFillZones = zoneFillFeatures.filter { ($0.value.properties?.first(where: { $0.key == self.PROP_ZONE_VISIBLE })?.value?.rawValue as? Bool ?? false) == true }
    let fillZones = filteredFillZones.map { $0.value }
    let fillCollection = FeatureCollection(features: fillZones)

    let filteredLineZones = zoneLineFeatures.filter { ($0.value.properties?.first(where: { $0.key == self.PROP_ZONE_VISIBLE })?.value?.rawValue as? Bool ?? false) == true }
    let lineZones = filteredLineZones.map { $0.value }
    let lineCollection = FeatureCollection(features: lineZones)

    try? self.style.updateGeoJSONSource(withId: self.SOURCE_ZONE_TEXT, geoJSON: .featureCollection(textsCollection))
    try? self.style.updateGeoJSONSource(withId: self.SOURCE_ZONE_FILL, geoJSON: .featureCollection(fillCollection))
    try? self.style.updateGeoJSONSource(withId: self.SOURCE_ZONE_LINE, geoJSON: .featureCollection(lineCollection))
  }

  func onStyleUpdated() {
    initSources()

    try? style.addSource(zoneTextSource, id: SOURCE_ZONE_TEXT)
    try? style.addLayer(zoneTextLayer, layerPosition: .below("marker-layer"))

    try? style.addSource(zoneLineSource, id: SOURCE_ZONE_LINE)
    try? style.addLayer(zoneLineLayer, layerPosition: .below(DEFAULT_STYLE_WALLS_LAYER))

    try? style.addSource(zoneFillSource, id: SOURCE_ZONE_FILL)
    try? style.addLayer(zoneFillLayer, layerPosition: .below(LAYER_ZONE_LINE))

    hideAll()
    refreshZones()
  }
}

extension ZoneController: IZoneController {
  func showTextLayer() {
    try? mapRepository.style.updateLayer(withId: LAYER_ZONE_TEXT, type: SymbolLayer.self) { $0.visibility = .constant(.visible) }
  }

  func hideTextLayer() {
    try? mapRepository.style.updateLayer(withId: LAYER_ZONE_TEXT, type: SymbolLayer.self) { $0.visibility = .constant(.none) }
  }

  func showFillLayer() {
    try? mapRepository.style.updateLayer(withId: LAYER_ZONE_FILL, type: FillLayer.self) { $0.visibility = .constant(.visible) }
  }

  func hideFillLayer() {
    try? mapRepository.style.updateLayer(withId: LAYER_ZONE_FILL, type: FillLayer.self) { $0.visibility = .constant(.none) }
  }

  func showLineLayer() {
    try? mapRepository.style.updateLayer(withId: LAYER_ZONE_LINE, type: LineLayer.self) { $0.visibility = .constant(.visible) }
  }

  func hideLineLayer() {
    try? mapRepository.style.updateLayer(withId: LAYER_ZONE_LINE, type: LineLayer.self) { $0.visibility = .constant(.none) }
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
    zones.forEach { showZone($0) }
    refreshZones()
  }

  func hideAll() {
    zones.forEach { hideZone($0) }
    refreshZones()
  }

  func show(zone: Zone) {
    showZone(zone)
    refreshZones()
  }

  func hide(zone: Zone) {
    hideZone(zone)
    refreshZones()
  }

  func select(zone: Zone) {
    selectZone(zone)
    refreshZones()
  }

  func select(zones: [Zone]) {
    zones.forEach { selectZone($0) }
    refreshZones()
  }

  func deselect(zone: Zone) {
    deselectZone(zone)
    refreshZones()
  }

  func deselect(zones: [Zone]) {
    zones.forEach { deselectZone($0) }
    refreshZones()
  }

  func deselectAll() {
    zones.forEach { deselectZone($0) }
    refreshZones()
  }

  func updateLocation(newLocation: CGPoint) {
  }

  func setInAndOutDataListener(completion: @escaping ([String]) -> Void) {

  }
}

private extension ZoneController {
  func showZone(_ zone: Zone) {
    zoneTextFeatures[zone.id]?.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
    zoneFillFeatures[zone.id]?.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
    zoneLineFeatures[zone.id]?.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
  }

  func hideZone(_ zone: Zone) {
    zoneTextFeatures[zone.id]?.properties?[PROP_ZONE_VISIBLE] = .boolean(false)
    zoneFillFeatures[zone.id]?.properties?[PROP_ZONE_VISIBLE] = .boolean(false)
    zoneLineFeatures[zone.id]?.properties?[PROP_ZONE_VISIBLE] = .boolean(false)
  }

  func selectZone(_ zone: Zone) {
    zoneTextFeatures[zone.id]?.properties?[PROP_SELECTED] = .boolean(true)
    zoneFillFeatures[zone.id]?.properties?[PROP_SELECTED] = .boolean(true)
    zoneLineFeatures[zone.id]?.properties?[PROP_SELECTED] = .boolean(true)
  }

  func deselectZone(_ zone: Zone) {
    zoneTextFeatures[zone.id]?.properties?[PROP_SELECTED] = .boolean(false)
    zoneFillFeatures[zone.id]?.properties?[PROP_SELECTED] = .boolean(false)
    zoneLineFeatures[zone.id]?.properties?[PROP_SELECTED] = .boolean(false)
  }

  func showZone(zoneId: String) {
    guard
      var fillFeature = zoneFillFeatures[zoneId],
      var textFeature = zoneTextFeatures[zoneId]
    else { return }

    fillFeature.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
    textFeature.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
  }

  func hideZone(zoneId: String) {
    guard
      var fillFeature = zoneFillFeatures[zoneId],
      var textFeature = zoneTextFeatures[zoneId]
    else { return }

    fillFeature.properties?[PROP_ZONE_VISIBLE] = .boolean(false)
    textFeature.properties?[PROP_ZONE_VISIBLE] = .boolean(false)
  }
}
