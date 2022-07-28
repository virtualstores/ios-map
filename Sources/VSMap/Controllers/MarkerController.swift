//
// MarkerController.swift
// VSFoundation
//
// Created by Hripsime on 2022-02-18.
// Copyright (c) 2022 Virtual Stores

import Foundation
import VSFoundation
import CoreGraphics
import MapboxMaps
import Combine

class MarkerController: IMarkerController {
    private let TAG = "MarkerController"
    
    private let SOURCE_ID = "marker-source"
    private let UNCLUSTERABLE_SOURCE_ID = "marker-source-no-cluster"
    let MARKER_LAYER_ID = "marker-layer"
    let UNCLUSTERABLE_MARKER_LAYER_ID = "unclusterable-marker-layer"
    let CLUSTERED_LAYER_ID = "clustered-marker-layer"
    let CLUSTERED_TEXT_LAYER_ID = "count"
    let CLUSTERED_ICON_LAYER_ID = "clusteredIconLayer"
    let FOCUSED_LAYER_ID = "focused-marker-layer"
    
    private let CLUSTER_ICON = "clusterIcon"
    private let CLUSTER_FONT = "Circular Pro Medium Regular"
    private let CLUSTER_FONT_FALLBACK = "Roboto Black"
    
    private let PROP_ID = "markerId"
    private let PROP_ICON = "iconName"
    private let PROP_DECORATION = "marker_decoration"
    private let PROP_CLUSTER_IDS = "cluster_ids"
    private let PROP_FOCUSED = "mark_focused"
    private let PROP_VISIBLE = "mark_visible"
    private let PROP_COUNT = "point_count"
    private let PROP_CLUSTERABLE = "clusterable"
    private let PROP_TRANSPARENCY = "marker_transparency"
    private let PROP_OFFSET_X = "marker_offset_x"
    private let PROP_OFFSET_Y = "marker_offset_y"
    
    private let ARRAY_SEPARATOR = ":"
    
    let ID_START = "start"
    let ID_STOP = "stop"
    
    let TRANSPARENCY_TRIGGER_RADIUS: Double = 25000
    let CLUSTER_TRIGGER_RADIUS: Double = 60000
    let CLUSTER_ICON_SIZE = 64

    var allMarkers: [MapMark] { markers.values.map { $0 } }
    var onMarkerClicked: CurrentValueSubject<MapMark?, Never> = .init(nil)

    private var mapRepository: MapRepository
    
    private var mapOptions: VSFoundation.MapOptions { mapRepository.mapOptions }
    private var mapMarkOptions: VSFoundation.MapOptions.MapMark { mapOptions.mapMark }
    private var floorLevelId: Int64 { mapRepository.floorLevelId }
    private var converter: ICoordinateConverter { mapRepository.mapData.converter }
    
    private var markers = [String: MapMark]()
    private var markerFeatures = [String : Feature]()
    private var startLocationFeatures = [String : Feature]()
    private var isStartLocationsVisible = false
    
    private var _markerSource: GeoJSONSource? = nil
    private var markerSource: GeoJSONSource {
        guard let markerSource = _markerSource else { fatalError("markerSource is not initialized") }
        
        return markerSource
    }
    
    private var _markerLayer: SymbolLayer? = nil
    private var markerLayer: SymbolLayer {
        guard let markerLayer = _markerLayer else { fatalError("markerLayer is not initialized") }
        
        return markerLayer
    }
    
    private var _focusedMarkerLayer: SymbolLayer? = nil
    
    private var focusedMarkerLayer: SymbolLayer {
        guard let focusedMarkerLayer = _focusedMarkerLayer else { fatalError("selectedMarkerLayer is not initialized") }
        
        return focusedMarkerLayer
    }
    
    public init(mapRepository: MapRepository) {
        self.mapRepository = mapRepository
    }

    func onFloorChange(mapRepository: MapRepository) {
        self.mapRepository = mapRepository
        self.refreshMarkers()
    }
    
    func initSources() {
        _markerSource = GeoJSONSource()
//        _markerSource?.cluster = mapOptions.cluster.clusteringEnabled
//        _markerSource?.clusterRadius = mapOptions.cluster.clusterRadius
//        _markerSource?.clusterMaxZoom = mapOptions.cluster.clusterMaxZoom
        
//        _markerSource?.clusterProperties = [
//            PROP_CLUSTER_IDS : Expression(.accumulated) {
//                Expression(.concat) {
//                    Exp(.accumulated){
//                        Exp(.get) {
//                        }
//                    }
//                }
//                Expression(.concat) {
//                    Exp(.get) {PROP_ID}
//                    Exp(.literal) {ARRAY_SEPARATOR}
//                }
//            },
//            PROP_TRANSPARENCY : Expression(.accumulated)
//        ]

        _markerSource?.data = .empty
        
        _markerLayer = SymbolLayer(id: MARKER_LAYER_ID)
        _markerLayer?.source = SOURCE_ID
        
        _markerLayer?.iconImage = .expression(Exp(.get) { PROP_ICON })
        _markerLayer?.iconAnchor = .constant(IconAnchor(rawValue: mapMarkOptions.anchor.rawValue) ?? .bottom)
        _markerLayer?.iconOffset = .constant([mapMarkOptions.offsetX, mapMarkOptions.offsetY]) // use marker offset
        
        _markerLayer?.iconSize = .constant(mapMarkOptions.scaleSize)  //options.mapMark.scaleSize
        _markerLayer?.iconAllowOverlap = .constant(true)
        _markerLayer?.iconOpacity = .expression(Exp(.get) { PROP_TRANSPARENCY })
        _markerLayer?.visibility = .constant(.visible)
        _markerLayer?.filter = Exp(.eq) { Exp(.get) { PROP_FOCUSED }; false }

        _focusedMarkerLayer = SymbolLayer(id: FOCUSED_LAYER_ID)
        _focusedMarkerLayer?.source = SOURCE_ID

        _focusedMarkerLayer?.iconImage = .expression(Exp(.get){ PROP_ICON })
        _focusedMarkerLayer?.iconAnchor = .constant(IconAnchor(rawValue: mapMarkOptions.anchor.rawValue) ?? .bottom)
        _focusedMarkerLayer?.iconOffset = .constant([mapMarkOptions.offsetX, mapMarkOptions.offsetY]) // use marker offset

        _focusedMarkerLayer?.iconSize = .constant(mapMarkOptions.focusScaleSize)  //options.mapMark.scaleSize
        _focusedMarkerLayer?.iconAllowOverlap = .constant(true)
        _focusedMarkerLayer?.iconOpacity = .expression(Exp(.get) { PROP_TRANSPARENCY })
        _focusedMarkerLayer?.visibility = .constant(.visible)
        _focusedMarkerLayer?.filter = Exp(.eq) { Exp(.get) { PROP_FOCUSED }; true }
    }
    
    private func addMapMark() {
        
    }
    
    private func clearMarkers() {
        markers.removeAll()
        markerFeatures.removeAll()
        refreshMarkers()
    }
    
    private func refreshMarkers() {
        let filteredMarkers = markerFeatures.filter { ($0.value.properties?.first(where: { $0.key == self.PROP_VISIBLE })?.value?.rawValue as? Bool ?? false) == true }
        let markers = filteredMarkers.map({ $0.value })

        //var unclusterableMarkers = markerFeatures.filter({ $0.key != PROP_CLUSTERABLE } )
        
        let featureCollection = FeatureCollection(features: markers)
        _markerSource?.data = .featureCollection(featureCollection)
        try? mapRepository.style.updateGeoJSONSource(withId: SOURCE_ID, geoJSON: .featureCollection(featureCollection))
    }
    
    private func create(marker: MapMark, completion: @escaping (Result<Feature, Error>) -> Void) {
        marker.createViewHolder { holder in
            try? self.mapRepository.style.addImage(holder.renderedBitmap, id: holder.imageId, stretchX: [], stretchY: [])
            let mapPosition = marker.position.convertFromMeterToLatLng(converter: self.mapRepository.mapData.converter)
            var feature = Feature(geometry: .point(Point(mapPosition)))

            feature.identifier = .string(marker.id)
            feature.properties = JSONObject()
            feature.properties?[self.PROP_ICON] = .string(holder.imageId)
            feature.properties?[self.PROP_ID] = .string(holder.id)
            feature.properties?[self.PROP_FOCUSED] = .boolean(marker.focused)
            feature.properties?[self.PROP_CLUSTERABLE] = .boolean(marker.clusterable)
            feature.properties?[self.PROP_OFFSET_X] = .number(marker.offset.dx)
            feature.properties?[self.PROP_OFFSET_Y] = .number(marker.offset.dy)

            feature.properties?[self.PROP_VISIBLE] = .boolean(self.floorLevelId == marker.floorLevelId ?? self.floorLevelId)

            completion(.success(feature))
        }
    }

    func onClick(point: CGPoint) {
      mapRepository.map.queryRenderedFeatures(at: point) { (result) in
        switch result {
        case .success(let features):
          features.forEach { feature in
            if feature.source == self.SOURCE_ID {
              guard
                let id = feature.feature.properties?[self.PROP_ID]??.rawValue as? String,
                let marker = self.markers[id]
              else { return }

              self.onMarkerClicked.send(marker)
            }
          }
        case .failure(let error): print("QueryError", error.localizedDescription)
        }
      }
    }
    
    //MARK: IMarkerController
    func add(marker: MapMark) {
        create(marker: marker) { result in
            switch result {
            case .success(let feature):
                self.markers[marker.id] = marker
                self.markerFeatures[marker.id] = feature
                self.refreshMarkers()
            case .failure(let error): Logger(verbosity: .error).log(message: "Error: Could not add marker: \(error)")
            }
        }
    }
    
    func set(markers: [MapMark]) {
        clearMarkers()
        
        if (markers.isEmpty) {
            refreshMarkers()
        } else {
            var numMarksToLoad = markers.count
            
            markers.forEach { marker in
                create(marker: marker) { result in
                    switch result {
                    case .success(let feature):
                        self.markers[marker.id] = marker
                        self.markerFeatures[marker.id] = feature
                        numMarksToLoad -= 1
                        if numMarksToLoad == 0 {
                            self.refreshMarkers()
                        }
                    default: break
                    }
                }
            }
        }
    }
    
    func get(markerId id: String) -> MapMark {
        markers[id]!
    }
    
    func focus(markerId id: String) {
        markerFeatures[id]?.properties?[PROP_FOCUSED] = .boolean(true)
        refreshMarkers()
    }
    
    func unfocusMarkers() {
        markerFeatures.forEach({ markerFeatures[$0.key]?.properties?[PROP_FOCUSED] = .boolean(false) })
        refreshMarkers()
    }
    
    func remove(marker: MapMark) {
        markerFeatures.removeValue(forKey: marker.id)
        markers.removeValue(forKey: marker.id)
        refreshMarkers()
    }
    
    func remove(markerId id: String) {
        markerFeatures.removeValue(forKey: id)
        markers.removeValue(forKey: id)
        refreshMarkers()
    }
    
    func updateLocation(newLocation: CGPoint, precision: Float) {
        let coordinate = newLocation.convertFromMeterToLatLng(converter: converter)
        markers.forEach { (key, value) in
            if self.setTransparentMarkers(coordinate: coordinate, marker: value) {
                refreshMarkers()
            }
        }
    }

    func setTransparentMarkers(coordinate: CLLocationCoordinate2D, marker: MapMark) -> Bool {
        var update = false
        guard let feature = markerFeatures[marker.id] else { return update }
        let markerCoordinate = marker.position.convertFromMeterToLatLng(converter: converter)
        let distance = markerCoordinate.distance(to: coordinate)
        if distance < TRANSPARENCY_TRIGGER_RADIUS {
            let adjustedCoordinate = CLLocationCoordinate2D(latitude: coordinate.latitude - 0.3, longitude: coordinate.longitude)
            let transparency = markerCoordinate.distance(to: adjustedCoordinate)
            let trans = min(max(transparency / (TRANSPARENCY_TRIGGER_RADIUS * 1.5), 0.4), 1.0)
            markerFeatures[marker.id]?.properties?[PROP_TRANSPARENCY] = .number(trans)
            update = true
        } else {
            guard let transparency = feature.properties?[PROP_TRANSPARENCY]??.rawValue as? Double, transparency != 1.0, !update else { return update }
            markerFeatures[marker.id]?.properties?[PROP_TRANSPARENCY] = .number(1.0)
            update = true
        }
        return update
    }
    
    func setStartLocationsVisibility(isVisible: Bool) {
        isStartLocationsVisible = isVisible
        startLocationFeatures.forEach { startLocationFeatures[$0.key]?.properties?[PROP_VISIBLE] = .boolean(isVisible) }
        refreshMarkers()
    }
}

extension MarkerController {
    func onStyleUpdated() {
        initSources()

        try? mapRepository.style.addSource(markerSource, id: SOURCE_ID)
        try? mapRepository.style.addLayer(markerLayer, layerPosition: LayerPosition.below("puck"))
        try? mapRepository.style.addLayer(markerLayer, layerPosition: LayerPosition.default)
        try? mapRepository.style.addLayer(focusedMarkerLayer, layerPosition: LayerPosition.below("puck"))
        try? mapRepository.style.addLayer(focusedMarkerLayer, layerPosition: LayerPosition.default)
    }
}
