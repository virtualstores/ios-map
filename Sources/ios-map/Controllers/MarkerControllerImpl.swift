//
// MarkerControllerImpl.swift
// VSFoundation
//
// Created by Hripsime on 2022-02-18.
// Copyright (c) 2022 Virtual Stores

import Foundation
import VSFoundation
import CoreGraphics
import MapboxMaps

class MarkerControllerImpl: IMarkerController {
    var allMarks: [MapMark] = []
    
    private let TAG = "MarkerController"
    
    private let SOURCE_ID = "marker-source"
    private let UNCLUSTERABLE_SOURCE_ID = "marker-source-no-cluster"
    let MARKER_LAYER_ID = "marker-layer"
    let UNCLUSTERABLE_MARKER_LAYER_ID = "unclusterable-marker-layer"
    let CLUSTERED_LAYER_ID = "clustered-marker-layer"
    let CLUSTERED_TEXT_LAYER_ID = "count"
    let CLUSTERED_ICON_LAYER_ID = "clusteredIconLayer"
    private let SELECTED_LAYER_ID = "selected-marker-layer"
    
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
    
    let TRANSPARENCY_TRIGGER_RADIUS = 25000
    let CLUSTER_TRIGGER_RADIUS = 60000
    let CLUSTER_ICON_SIZE = 64
    
    private var mapRepository: MapRepository
    
    private var mapOptions: VSFoundation.MapOptions {
        mapRepository.mapOptions
    }
    
    private var floorLevelId: Int64 {
        mapRepository.floorLevelId
    }
    
    private var markers = [String: MapMark]()
    private var markerFeatures = [String : Feature]()
    private var lineFeatures = [String : Feature]()
    private var startLocationFeatures = [String : Feature]()
    private var style: Style? = nil
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
    
    private var _selectedMarkerLayer: SymbolLayer? = nil
    
    private var selectedMarkerLayer: SymbolLayer {
        guard let selectedMarkerLayer = _selectedMarkerLayer else { fatalError("selectedMarkerLayer is not initialized") }
        
        return selectedMarkerLayer
    }
    
    public init(mapRepository: MapRepository) {
        self.mapRepository = mapRepository
        
    }
    
    public func setup(with mapOptions: VSFoundation.MapOptions, floorLevelId: Int64?) {
        
    }
    
    func initSources() {
        _markerSource = GeoJSONSource()
        _markerSource?.cluster = mapOptions.cluster.clusteringEnabled
        _markerSource?.clusterRadius = mapOptions.cluster.clusterRadius
        _markerSource?.clusterMaxZoom = mapOptions.cluster.clusterMaxZoom
        
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
        
        //        let expression = Exp(.switchCase) { // Switching on a value
        //            Exp(.eq) { // Evaluates if conditions are equal
        //                Exp(.get) { "PROP_ICON" } // Get the current value for `POITYPE`
        //                "Restroom" // returns true for the equal expression if the type is equal to "Restrooms"
        //            }
        //            "restrooms" // Use the icon named "restrooms" on the sprite sheet if the above condition is true
        //            Exp(.eq) {
        //                Exp(.get) { "POITYPE" }
        //                "Picnic Area"
        //            }
        //            "picnic-area"
        //            Exp(.eq) {
        //                Exp(.get) { "POITYPE" }
        //                "Trailhead"
        //            }
        //            "trailhead"
        //            "" // default case is to return an empty string so no icon will be loaded
        //        }
        
        _markerLayer?.iconImage =  .expression(Exp(.get){ PROP_ICON })
        _markerLayer?.iconAnchor = .constant(IconAnchor.bottom)
        _markerLayer?.iconOffset = .constant([0.0, 0.0]) // use marker offset
        
        _markerLayer?.iconSize = .constant(1.0)  //options.mapMark.scaleSize
        _markerLayer?.iconAllowOverlap = .constant(true)
        _markerLayer?.iconOpacity = .expression(Exp(.get){ PROP_TRANSPARENCY })
        _markerLayer?.visibility = .constant(.visible)
    }
    
    private func addMapMark() {
        
    }
    
    private func clearMarkers() {
        markers.removeAll()
        markerFeatures.removeAll()
    }
    
    private func refreshMarkers() {
        let markers = markerFeatures.map({ $0.value })

        //var unclusterableMarkers = markerFeatures.filter({ $0.key != PROP_CLUSTERABLE } )
        
        let featureCollection = FeatureCollection(features: markers)
        _markerSource?.data = .featureCollection(featureCollection)

        try? mapRepository.style.updateGeoJSONSource(withId: SOURCE_ID, geoJSON: GeoJSONObject.featureCollection(featureCollection))
    }
    
    private func createMark(mark: MapMark, onFinish: @escaping (Result<Feature, Error>) -> Void ) {
        mark.createViewHolder { holder in
            try! self.mapRepository.style.addImage(holder.renderedBitmap, id: holder.imageId, stretchX: [], stretchY: [])
            let mapPosition = mark.position.convertFromMeterToLatLng(converter: self.mapRepository.mapData.converter)
            var feature = Feature(geometry: .point(Point(mapPosition)))

            feature.identifier = FeatureIdentifier.string(mark.id)
            feature.properties = JSONObject()
            feature.properties?[self.PROP_ICON] = .string(holder.imageId)
            feature.properties?[self.PROP_ID] = .string(holder.id)
            feature.properties?[self.PROP_FOCUSED] = .boolean(false)
            feature.properties?[self.PROP_CLUSTERABLE] = .boolean(mark.clusterable)
            feature.properties?[self.PROP_OFFSET_X] = .number(mark.offsetX)
            feature.properties?[self.PROP_OFFSET_Y] = .number(mark.offsetY)
            
            //add VISIBLE check with floor
            feature.properties?[self.PROP_VISIBLE] = .boolean(true)

            onFinish(.success(feature))
        }
    }
    
    //MARK: IMarkerController
    func addMark(mark: MapMark) {
        createMark(mark: mark) { result in
            switch result {
            case .success(let feature):
                self.markers[mark.id] = mark
                self.markerFeatures[mark.id] = feature
                self.lineFeatures[mark.id] = feature
                self.refreshMarkers()
            default: break
            }
        }
    }
    
    func setMarks(marks: [MapMark]) {
        clearMarkers()
        
        if (marks.isEmpty) {
            refreshMarkers()
        } else {
            var numMarksToLoad = marks.count
            
            marks.forEach { mark in
                createMark(mark: mark) { result in
                    switch result {
                    case .success(let feature):
                        self.markers[mark.id] = mark
                        self.markerFeatures[mark.id] = feature
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
    
    func getMark(id: String) -> MapMark {
        markers[id]!
    }
    
    func focusMark(id: String) {
        markerFeatures[id]?.properties?[PROP_FOCUSED] = true
        //  markerFeatures[id]?.addBooleanProperty(PROP_FOCUSED, true)
        refreshMarkers()
        // animateMarkerFocused(true)
    }
    
    func unfocusMarks() {
        //  markerFeatures.forEach({ $0.value.properties?[PROP_FOCUSED] = true })
        refreshMarkers()
        //  animateMarkerFocused(false)
    }
    
    func removeMark(mark: MapMark) {
        
    }
    
    func removeMark(id: String) {
        markerFeatures.removeValue(forKey: id)
        markers.removeValue(forKey: id)
        refreshMarkers()
    }
    
    func updateLocation(newLocation: CGPoint, precision: Float) {
        
    }
    
    func setStartLocationsVisibility(isVisible: Bool) {
        isStartLocationsVisible = isVisible
        
        startLocationFeatures.forEach { index, item in
            // $0.value.properties?[PROP_VISIBLE] = isVisible//.addBooleanProperty(PROP_VISIBLE, isVisible)
        }
        refreshMarkers()
    }
    
}

extension MarkerControllerImpl {
    func onStyleUpdated() {
        initSources()

        try! mapRepository.style.addSource(markerSource, id: SOURCE_ID)
        try! mapRepository.style.addLayer(markerLayer, layerPosition: LayerPosition.default)
    }
    
    func onMapUpdated() {
        
    }
}
