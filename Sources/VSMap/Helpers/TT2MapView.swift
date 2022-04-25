//
//  MapBoxView.swift
//  VSMap
//
//  Created by Hripsime on 2022-02-10.
//

import SwiftUI
import CoreLocation
import MapboxMaps
import VSFoundation

public class TT2MapView: UIView {
    internal var mapView: MapView!
    var mapStyle: VSFoundation.MapOptions.MapStyle?
    
    public func setup(with token: String) {
        let myResourceOptions = ResourceOptions(accessToken: token)
        let cameraOptions = CameraOptions(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), zoom: 6.5, pitch: 0.0)
        
        let myMapInitOptions = MapInitOptions(resourceOptions: myResourceOptions, cameraOptions: cameraOptions)
        
        mapView = MapView(frame: self.bounds, mapInitOptions: myMapInitOptions)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(mapView)
        
        mapView.mapboxMap.onEvery(.styleDataLoaded) { (event) in
//            guard let data = event.data as? [String: Any],
//                  let type = data["type"]
//            else {
//                Logger.init(verbosity: .debug).log(message: "styleDataLoaded success")
//                return
//            }
            
//            Logger.init(verbosity: .debug).log(message: "The map has finished loading style data of type = \(type)")
        }
        
//        mapView.mapboxMap.onNext(.styleLoaded) { (event) in
//            Logger.init(verbosity: .debug).log(message: "The map has finished loading style ... Event = \(event)")
//        }
//
//        mapView.mapboxMap.onNext(.renderFrameFinished) { (event) in
//            Logger.init(verbosity: .debug).log(message: "he map has finished loading style ... Event =  \(event)")
//        }
//
//        mapView.mapboxMap.onNext(.mapLoaded) {  (event) in
//            Logger.init(verbosity: .debug).log(message: "The map has finished loading ... Event =  \(event)")
//        }
    }

    private var loadingView: UIView?
    private var loadingIndicator: UIActivityIndicatorView?
    func addLoadingView() {
        guard let loadingView = loadingView else {
            DispatchQueue.main.async {
                self.loadingView = .init(frame: self.mapView.frame)
                if let view = self.loadingView {
                    self.loadingIndicator = UIActivityIndicatorView(frame: view.frame)
                    self.createLoadingActivityIndicator()
                }
            }
            return
        }

        DispatchQueue.main.async {
            self.mapView.addSubview(loadingView)
        }
    }

    private func createLoadingActivityIndicator() {
        guard let loadingView = self.loadingView, let loadingIndicator = self.loadingIndicator else { return }
        self.loadingIndicator?.startAnimating()

        switch mapStyle?.styleMode {
        case .light:
            if #available(iOS 13.0, *) {
                loadingView.backgroundColor = .secondarySystemBackground
                loadingIndicator.style = .large
            } else {
                loadingView.backgroundColor = .lightGray
            }
        case .dark:
            loadingView.backgroundColor = UIColor(rgb: 0x444444)
            loadingIndicator.color = .lightGray
            if #available(iOS 13.0, *) {
                loadingIndicator.style = .large
            }
        case .none: break
        }

        loadingView.addSubview(loadingIndicator)
        loadingIndicator.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor).isActive = true
        loadingIndicator.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor).isActive = true
        mapView.addSubview(loadingView)
    }

    func dismissLoadingScreen() {
        UIView.animate(withDuration: 0.5, animations: {
                self.loadingView?.alpha = 0.0
                self.loadingIndicator?.alpha = 0.0
        }) { (_) in
            self.loadingView?.removeFromSuperview()
            self.loadingView?.alpha = 1.0
            self.loadingIndicator?.alpha = 1.0
        }
    }
    
    func updateUserPosition(with newPosition: CLLocation) { }
}
