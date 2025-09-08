//
//  MapRepository.swift
//  
//
//  Created by Hripsime on 2022-03-26.
//

import Foundation
import VSFoundation
import MapboxMaps

public class MapRepository: Disposable {
    private let tag: String = "MapRepository"
    private var _mapData: MapData?
    private var _mapOptions: VSFoundation.MapOptions?
    private var _stateOptions: StateOptions?
    private var _style: Style?
    private var _map: MapboxMap?

    var mapData: MapData {
        get {
            guard let mapData = _mapData else { fatalError("mapData not initialized")}
            
            return mapData
        }
        
        set { _mapData = newValue }
    }
    
    var mapOptions: VSFoundation.MapOptions {
        get {
            guard let mapOptions = _mapOptions else { fatalError("mapOptions not initialized")}
            
            return mapOptions
        }
        
        set { _mapOptions = newValue }
    }

    var stateOptions: StateOptions {
        get {
            guard let stateOptions = _stateOptions else { fatalError("stateOptions not initialized")}

            return stateOptions
        }

        set { _stateOptions = newValue }
    }

    var style: Style {
        get {
            guard let style = _style else { fatalError("style not initialized")}
            
            return style
        }
        
        set { _style = newValue }
    }
    
    var map: MapboxMap {
        get {
            guard let map = _map else { fatalError("map not initialized")}
            
            return map
        }
        
        set { _map = newValue }
    }

    var displayMultiplePositions: Bool = false
    var currentPosition: VPSOutputSignal.Position?
    var isPositionActive = false
    var isReferenceAngleCertain = false

    var floorLevelId: Int64 { mapData.rtlsOptions.id }
    
    var swapLocations: [Int64: [SwapLocation]] {
        get {
            var locations: [Int64: [SwapLocation]] = [:]
            mapData.swapLocations.forEach { location in
                var list: [SwapLocation] = locations[location.rtlsOptionsId] ?? []
                list.append(location)
                locations[location.rtlsOptionsId] = list
            }
            
            return locations
        }
    }

  init() {
    Logger(verbosity: .info).log(tag: tag, message: "init")
  }

  deinit {
    Logger(verbosity: .info).log(tag: tag, message: "deinit")
    dispose()
  }

  public func dispose() {
    Logger(verbosity: .info).log(tag: tag, message: "dispose")
    _mapData = nil
    _mapOptions = nil
    _stateOptions = nil
    _style = nil
    _map = nil
    displayMultiplePositions = false
    currentPosition = nil
    isPositionActive = false
    isReferenceAngleCertain = false
  }
}
