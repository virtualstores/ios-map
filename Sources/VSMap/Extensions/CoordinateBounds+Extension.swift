//
//  CoordinateBounds+Extension.swift
//  VSMap
//
//  Created by Hripsime on 2022-02-17.
//

import Foundation
import MapboxMaps

extension CoordinateBounds {
    var center: CLLocationCoordinate2D {
        let width = northeast.longitude - southwest.longitude
        let height = northeast.latitude - southwest.latitude
        return CLLocationCoordinate2D(latitude: southwest.latitude + height/2, longitude: southwest.longitude + width/2)
    }
    
    func contains(coordinate: CLLocationCoordinate2D) -> Bool {
        self.containsLatitude(forLatitude: coordinate.latitude) && self.containsLongitude(forLongitude: coordinate.longitude)
    }
    
    convenience init(coordinates: [CLLocationCoordinate2D]) {
        guard coordinates.count > 1 else {
            let coordinate = coordinates.first ?? .init(latitude: 0, longitude: 0)
            self.init(southwest: coordinate, northeast: coordinate)
            return
        }
        
        var minLon = -Double.infinity
        var maxLon = Double.infinity
        var minLat = -Double.infinity
        var maxLat = Double.infinity
        coordinates.forEach { (coordinate) in
            if coordinate.longitude < minLon {
                minLon = coordinate.longitude
            }
            if coordinate.longitude > maxLon {
                maxLon = coordinate.longitude
            }
            if coordinate.latitude < minLat {
                minLat = coordinate.latitude
            }
            if coordinate.latitude > maxLat {
                maxLat = coordinate.latitude
            }
        }
        self.init(
            southwest: CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
            northeast: CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon)
        )
    }
    
    convenience init(rect: CGRect) {
        self.init(
            southwest: CLLocationCoordinate2D(latitude: Double(rect.minY), longitude: Double(rect.minX)),
            northeast: CLLocationCoordinate2D(latitude: Double(rect.maxY), longitude: Double(rect.maxX))
        )
    }
}
