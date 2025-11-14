//
//  ZoneController.swift
//  
//
//  Created by Théodore Roos on 2022-03-31.
//

import Foundation
import MapboxMaps
import VSFoundation
import Combine

class ZoneController {
  let tag = "ZoneController"
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
  private let PROP_ZONE_TEXT_OPACITY_SELECTED = "prop-zone-text-opacity-selected"
  private let PROP_ZONE_TEXT_ALLOW_OVERLAP = "prop-zone-text-allow-overlap"
  private let PROP_ZONE_TEXT_IGNORE_PLACEMENT = "prop-zone-text-ignore-placement"
  private let PROP_ZONE_TEXT_ANCHOR = "prop-zone-text-anchor"

  private let PROP_ZONE_FILL_COLOR = "prop-zone-fill-color"
  private let PROP_ZONE_FILL_COLOR_SELECTED = "prop-zone-fill-color-selected"
  private let PROP_ZONE_FILL_ALPHA = "prop-zone-fill-alpha"
  private let PROP_ZONE_FILL_ALPHA_SELECTED = "prop-zone-fill-alpha-selected"

  private let PROP_ZONE_LINE_COLOR = "prop-zone-line-color"
  private let PROP_ZONE_LINE_COLOR_SELECTED = "prop-zone-line-color-selected"
  private let PROP_ZONE_LINE_OPACITY = "prop-zone-line-opacity"
  private let PROP_ZONE_LINE_OPACITY_SELECTED = "prop-zone-line-opacity-selected"
  private let PROP_ZONE_LINE_WIDTH = "prop-zone-line-width"
  private let PROP_ZONE_LINE_WIDTH_SCALED = "prop-zone-line-width-scaled"

  @Inject var mapRepository: MapRepository
  private var mapOptions: VSFoundation.MapOptions { mapRepository.mapOptions }
  private var zoneStyle: VSFoundation.MapOptions.ZoneStyle { mapOptions.zoneStyle }
  private var sharedProperties: SharedZoneProperties?

  public private(set) var zones: [Zone] = []
  public var onEnterPublisher: CurrentValueSubject<Zone?, Never> = .init(nil)
  public var onExitPublisher: CurrentValueSubject<Zone?, Never> = .init(nil)

  private var zoneTextFeatures: [String : Feature] = [:]

  private var zoneLineFeatures: [String : Feature] = [:]

  private var zoneFillFeatures: [String : Feature] = [:]

  var converter: ICoordinateConverter { mapRepository.mapData.converter }

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

  deinit {
    Logger(verbosity: .info).log(tag: tag, message: "deinit")
  }

  func onFloorChange(mapRepository: MapRepository) {
    self.mapRepository = mapRepository
  }

  func setup(zones: [Zone], sharedProperties: SharedZoneProperties?) {
    self.zoneTextFeatures.removeAll()
    self.zoneFillFeatures.removeAll()
    self.zoneLineFeatures.removeAll()
    self.zones = zones
    self.sharedProperties = sharedProperties
    zones.forEach { (zone) in
      if let point = zone.navigationPoint {
        let coordinate = point.convertFromMeterToLatLng(converter: converter)
        let textStyle = zoneStyle.textStyle
        let textColor = zone.navigationPointProperties?.textColor ?? zone.properties.textColor ?? sharedProperties?.textColor ?? textStyle.textColor.asHex
        let textColorSelected = zone.navigationPointProperties?.textColorSelected ?? zone.properties.textColorSelected ?? sharedProperties?.textColorSelected ?? textStyle.textColorSelected.asHex
        let textSize = zone.navigationPointProperties?.textSize ?? zone.properties.textSize ?? sharedProperties?.textSize ?? textStyle.textMaxSize
        let textOpacity = zone.navigationPointProperties?.textOpacity ?? zone.properties.textOpacity ?? sharedProperties?.textOpacity ?? textStyle.textOpacity
        let textOpacitySelected = zone.navigationPointProperties?.textOpacitySelected ?? zone.properties.textOpacitySelected ?? sharedProperties?.textOpacitySelected ?? textStyle.textOpacitySelected
        let textAllowOverlap = zone.navigationPointProperties?.textAllowOverLap ?? zone.properties.textAllowOverLap ?? sharedProperties?.textAllowOverLap ?? textStyle.textAllowOverLap
        let textAnchor = zone.navigationPointProperties?.textAnchor ?? zone.properties.textAnchor ?? sharedProperties?.textAnchor ?? textStyle.textAnchor
        let textIgnorePlacement = zone.navigationPointProperties?.textIgnorePlacement ?? zone.properties.textIgnorePlacement ?? sharedProperties?.textIgnorePlacement ?? textStyle.textIgnorePlacement
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
        textFeature.properties?[PROP_ZONE_TEXT_OPACITY_SELECTED] = .number(textOpacitySelected)
        textFeature.properties?[PROP_ZONE_TEXT_ALLOW_OVERLAP] = .boolean(textAllowOverlap)
        textFeature.properties?[PROP_ZONE_TEXT_IGNORE_PLACEMENT] = .boolean(textIgnorePlacement)
        textFeature.properties?[PROP_ZONE_TEXT_ANCHOR] = .string(textAnchor)
        self.zoneTextFeatures[zone.id] = textFeature
      }

      let polygon = zone.polygon.map { CLLocationCoordinate2D(latitude: $0.y, longitude: $0.x) }
      let fillColor = zone.properties.fillColor ?? sharedProperties?.fillColor ?? zoneStyle.fillStyle.color.asHex
      let fillColorSelected = zone.properties.fillColorSelected ?? sharedProperties?.fillColorSelected ?? zoneStyle.fillStyle.colorSelected.asHex
      let fillAlpha = zone.properties.fillAlpha ?? sharedProperties?.fillAlpha ?? zoneStyle.fillStyle.alpha
      let fillAlphaSelected = zone.properties.fillAlphaSelected ?? sharedProperties?.fillAlphaSelected ?? zoneStyle.fillStyle.alphaSelected

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
      fillFeature.properties?[PROP_ZONE_FILL_ALPHA_SELECTED] = .number(fillAlphaSelected)

      self.zoneFillFeatures[zone.id] = fillFeature

      let lineColor = zone.properties.lineColor ?? sharedProperties?.lineColor ?? zoneStyle.lineStyle.lineColor.asHex
      let lineColorSelected = zone.properties.lineColorSelected ?? sharedProperties?.lineColorSelected ?? zoneStyle.lineStyle.lineColorSelected.asHex
      let lineOpacity = zone.properties.lineOpacity ?? sharedProperties?.lineOpacity ?? zoneStyle.lineStyle.lineOpacity
      let lineOpacitySelected = zone.properties.lineOpacitySelected ?? sharedProperties?.lineOpacitySelected ?? zoneStyle.lineStyle.lineOpacitySelected
      let lineWidth = zone.properties.lineWidth ?? sharedProperties?.lineWidth ?? zoneStyle.lineStyle.lineWidth

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
      lineFeature.properties?[PROP_ZONE_LINE_OPACITY_SELECTED] = .number(lineOpacitySelected)
      lineFeature.properties?[PROP_ZONE_LINE_WIDTH] = .number(lineWidth)
      lineFeature.properties?[PROP_ZONE_LINE_WIDTH_SCALED] = .number(lineWidth * 5)
      self.zoneLineFeatures[zone.id] = lineFeature
    }
  }

  func initSources() {
    _zoneTextSource = GeoJSONSource(id: SOURCE_ZONE_TEXT)
    _zoneFillSource = GeoJSONSource(id: SOURCE_ZONE_FILL)
    _zoneLineSource = GeoJSONSource(id: SOURCE_ZONE_LINE)

    let textSizeStops: [Double: Double] = [
      0: zoneStyle.textStyle.textMinSize,
//      7: (zoneStyle.textStyle.textMinSize + zoneStyle.textStyle.textMaxSize) / 2,
      12: zoneStyle.textStyle.textMaxSize
    ]

    _zoneTextLayer = SymbolLayer(id: LAYER_ZONE_TEXT, source: zoneTextSource.id)
    _zoneTextLayer?.source = SOURCE_ZONE_TEXT
    _zoneTextLayer?.textField = .expression(Exp(.get) { PROP_ZONE_NAME })
    _zoneTextLayer?.textMaxWidth = .constant(5)
    //_zoneTextLayer?.textSize = .expression(Exp(.get) { PROP_ZONE_TEXT_SIZE })
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
    _zoneTextLayer?.textOpacity = .expression(
      Exp(.switchCase) {
        Exp(.eq) { Exp(.get) { PROP_SELECTED }; true }
        Exp(.get) { PROP_ZONE_TEXT_OPACITY_SELECTED }
        Exp(.get) { PROP_ZONE_TEXT_OPACITY }
      }
    )
//    _zoneTextLayer?.textIgnorePlacement = .expression(Exp(.get) { PROP_ZONE_TEXT_IGNORE_PLACEMENT })
    _zoneTextLayer?.textAnchor = .expression(Exp(.get) { PROP_ZONE_TEXT_ANCHOR })
    _zoneTextLayer?.textOffset = .constant(zoneStyle.textStyle.textOffset)
    _zoneTextLayer?.textAllowOverlap = .constant(true)//.expression(Exp(.get) { PROP_ZONE_TEXT_ALLOW_OVERLAP })
    _zoneTextLayer?.textFont = .constant([zoneStyle.textStyle.textFont])
    _zoneTextLayer?.filter = Exp(.eq) { Exp(.get) { PROP_ZONE_VISIBLE }; true }

    _zoneFillLayer = FillLayer(id: LAYER_ZONE_FILL, source: zoneFillSource.id)
    _zoneFillLayer?.source = SOURCE_ZONE_FILL
    _zoneFillLayer?.fillColor = .expression(
      Exp(.switchCase) {
        Exp(.eq) { Exp(.get) { PROP_SELECTED }; true }
        Exp(.get) { PROP_ZONE_FILL_COLOR_SELECTED }
        Exp(.get) { PROP_ZONE_FILL_COLOR }
      }
    )
    _zoneFillLayer?.fillOpacity = .expression(
      Exp(.switchCase) {
        Exp(.eq) { Exp(.get) { PROP_SELECTED }; true }
        Exp(.get) { PROP_ZONE_FILL_ALPHA_SELECTED }
        Exp(.get) { PROP_ZONE_FILL_ALPHA }
      }
    )
    _zoneFillLayer?.filter = Exp(.eq) { Exp(.get) { PROP_ZONE_VISIBLE }; true }

    _zoneLineLayer = LineLayer(id: LAYER_ZONE_LINE, source: zoneLineSource.id)
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
    _zoneLineLayer?.lineOpacity = .expression(
      Exp(.switchCase) {
        Exp(.eq) { Exp(.get) { PROP_SELECTED }; true }
        Exp(.get) { PROP_ZONE_LINE_OPACITY_SELECTED }
        Exp(.get) { PROP_ZONE_LINE_OPACITY }
      }
    )
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

    mapRepository.map.updateGeoJSONSource(withId: self.SOURCE_ZONE_TEXT, geoJSON: .featureCollection(textsCollection))
    mapRepository.map.updateGeoJSONSource(withId: self.SOURCE_ZONE_FILL, geoJSON: .featureCollection(fillCollection))
    mapRepository.map.updateGeoJSONSource(withId: self.SOURCE_ZONE_LINE, geoJSON: .featureCollection(lineCollection))
  }

  func onStyleUpdated() {
    initSources()

    try? mapRepository.map.addSource(zoneTextSource)
    try? mapRepository.map.addLayer(zoneTextLayer, layerPosition: .below("marker-layer"))

    try? mapRepository.map.addSource(zoneLineSource)
    try? mapRepository.map.addLayer(zoneLineLayer, layerPosition: .below(DEFAULT_STYLE_WALLS_LAYER))

    try? mapRepository.map.addSource(zoneFillSource)
    try? mapRepository.map.addLayer(zoneFillLayer, layerPosition: .below(LAYER_ZONE_LINE))

    refreshZones()
    hideAllLayers()
  }
}

extension ZoneController: IZoneController {
  func showTextLayer() {
    try? mapRepository.map.updateLayer(withId: LAYER_ZONE_TEXT, type: SymbolLayer.self) { $0.visibility = .constant(.visible) }
  }

  func hideTextLayer() {
    do {
      try mapRepository.map.updateLayer(withId: LAYER_ZONE_TEXT, type: SymbolLayer.self) { $0.visibility = .constant(.none) }
    } catch {
      //print(Date(), error)
      let layer = try? mapRepository.map.layer(withId: LAYER_ZONE_TEXT) as? SymbolLayer
      if layer?.visibility != .constant(.none) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          self.hideTextLayer()
        }
      }
    }
  }

  func showFillLayer() {
    try? mapRepository.map.updateLayer(withId: LAYER_ZONE_FILL, type: FillLayer.self) { $0.visibility = .constant(.visible) }
  }

  func hideFillLayer() {
    try? mapRepository.map.updateLayer(withId: LAYER_ZONE_FILL, type: FillLayer.self) { $0.visibility = .constant(.none) }
  }

  func showLineLayer() {
    try? mapRepository.map.updateLayer(withId: LAYER_ZONE_LINE, type: LineLayer.self) { $0.visibility = .constant(.visible) }
  }

  func hideLineLayer() {
    try? mapRepository.map.updateLayer(withId: LAYER_ZONE_LINE, type: LineLayer.self) { $0.visibility = .constant(.none) }
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

  func show(zoneId: String) {
    showZone(zoneId)
    refreshZones()
  }

  func hide(zoneId: String) {
    hideZone(zoneId)
    refreshZones()
  }

  func select(zoneId: String) {
    selectZone(zoneId)
    refreshZones()
  }

  func select(zoneIds: [String]) {
    zones.forEach { selectZone($0) }
    refreshZones()
  }

  func deselect(zoneId: String) {
    deselectZone(zoneId)
    refreshZones()
  }

  func deselect(zoneIds: [String]) {
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
//    zoneTextFeatures[zone.id]?.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
    zoneFillFeatures[zone.id]?.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
    zoneLineFeatures[zone.id]?.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
  }

  func hideZone(_ zone: Zone) {
//    zoneTextFeatures[zone.id]?.properties?[PROP_ZONE_VISIBLE] = .boolean(false)
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

  func showZone(_ zoneId: String) {
//    zoneTextFeatures[zoneId]?.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
    zoneFillFeatures[zoneId]?.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
    zoneLineFeatures[zoneId]?.properties?[PROP_ZONE_VISIBLE] = .boolean(true)
  }

  func hideZone(_ zoneId: String) {
//    zoneTextFeatures[zoneId]?.properties?[PROP_ZONE_VISIBLE] = .boolean(false)
    zoneFillFeatures[zoneId]?.properties?[PROP_ZONE_VISIBLE] = .boolean(false)
    zoneLineFeatures[zoneId]?.properties?[PROP_ZONE_VISIBLE] = .boolean(false)
  }

  func selectZone(_ zoneId: String) {
    zoneTextFeatures[zoneId]?.properties?[PROP_SELECTED] = .boolean(true)
    zoneFillFeatures[zoneId]?.properties?[PROP_SELECTED] = .boolean(true)
    zoneLineFeatures[zoneId]?.properties?[PROP_SELECTED] = .boolean(true)
  }

  func deselectZone(_ zoneId: String) {
    zoneTextFeatures[zoneId]?.properties?[PROP_SELECTED] = .boolean(false)
    zoneFillFeatures[zoneId]?.properties?[PROP_SELECTED] = .boolean(false)
    zoneLineFeatures[zoneId]?.properties?[PROP_SELECTED] = .boolean(false)
  }
}
