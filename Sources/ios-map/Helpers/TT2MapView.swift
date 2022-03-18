//
//  MapBoxView.swift
//  VSMap
//
//  Created by Hripsime on 2022-02-10.
//

import SwiftUI
import CoreLocation
@_implementationOnly import MapboxMaps
import VSFoundation

public class TT2MapView: UIView {
    internal var mapBoxMapView: MapView!
    
    public func setup(with token: String) {
        let myResourceOptions = ResourceOptions(accessToken: token)
        let cameraOptions = CameraOptions(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), zoom: 6.5, pitch: 0.0)
        
        let myMapInitOptions = MapInitOptions(resourceOptions: myResourceOptions, cameraOptions: cameraOptions)
        
        mapBoxMapView = MapView(frame: self.bounds, mapInitOptions: myMapInitOptions)
        mapBoxMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(mapBoxMapView)
        
        mapBoxMapView.mapboxMap.onEvery(.styleDataLoaded) { (event) in
            guard let data = event.data as? [String: Any],
                  let type = data["type"]
            else {
                Logger.init(verbosity: .debug).log(message: "styleDataLoaded success")
                return
            }
            
            Logger.init(verbosity: .debug).log(message: "The map has finished loading style data of type = \(type)")
        }
        
        mapBoxMapView.mapboxMap.onNext(.styleLoaded) { (event) in
            Logger.init(verbosity: .debug).log(message: "The map has finished loading style ... Event = \(event)")
        }
        
        mapBoxMapView.mapboxMap.onNext(.renderFrameFinished) { (event) in
            Logger.init(verbosity: .debug).log(message: "he map has finished loading style ... Event =  \(event)")
        }
        
        mapBoxMapView.mapboxMap.onNext(.mapLoaded) {  (event) in
            Logger.init(verbosity: .debug).log(message: "The map has finished loading ... Event =  \(event)")
        }
    }
    
    func updateUserPosition(with newPosition: CLLocation) { }
}
