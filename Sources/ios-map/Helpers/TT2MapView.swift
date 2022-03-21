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
    internal var mapView: MapView!
    var mapStyle: MapStyle?
    
    public func setup(with token: String) {
        let myResourceOptions = ResourceOptions(accessToken: token)
        let cameraOptions = CameraOptions(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), zoom: 6.5, pitch: 0.0)
        
        let myMapInitOptions = MapInitOptions(resourceOptions: myResourceOptions, cameraOptions: cameraOptions)
        
        mapView = MapView(frame: self.bounds, mapInitOptions: myMapInitOptions)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(mapView)
        
        mapView.mapboxMap.onEvery(.styleDataLoaded) { (event) in
            guard let data = event.data as? [String: Any],
                  let type = data["type"]
            else {
                Logger.init(verbosity: .debug).log(message: "styleDataLoaded success")
                return
            }
            
            Logger.init(verbosity: .debug).log(message: "The map has finished loading style data of type = \(type)")
        }
        
        mapView.mapboxMap.onNext(.styleLoaded) { (event) in
            Logger.init(verbosity: .debug).log(message: "The map has finished loading style ... Event = \(event)")
        }
        
        mapView.mapboxMap.onNext(.renderFrameFinished) { (event) in
            Logger.init(verbosity: .debug).log(message: "he map has finished loading style ... Event =  \(event)")
        }
        
        mapView.mapboxMap.onNext(.mapLoaded) {  (event) in
            Logger.init(verbosity: .debug).log(message: "The map has finished loading ... Event =  \(event)")
        }
    }

//    private func createLoadingActivityIndicator() {
//        self.loadingIndicator.startAnimating()
//
//        switch mapOptions.style.styleMode {
//        case .light:
//            if #available(iOS 13.0, *) {
//                self.loadingView.backgroundColor = .secondarySystemBackground
//                loadingIndicator.style = .large
//            } else {
//                self.loadingView.backgroundColor = .lightGray
//            }
//        case .dark:
//            self.loadingView.backgroundColor = UIColor(rgb: 0x444444)
//            self.loadingIndicator.color = .lightGray
//            if #available(iOS 13.0, *) {
//                loadingIndicator.style = .large
//            }
//        }
//
//        self.loadingView.addSubview(loadingIndicator)
//        loadingIndicator.centerXAnchor.constraint(equalTo: self.loadingView.centerXAnchor).isActive = true
//        loadingIndicator.centerYAnchor.constraint(equalTo: self.loadingView.centerYAnchor).isActive = true
//    }
    
    func updateUserPosition(with newPosition: CLLocation) { }
}
