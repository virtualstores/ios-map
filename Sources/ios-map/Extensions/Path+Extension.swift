//
//  Path+Extension.swift
//  
//
//  Created by Hripsime on 2022-03-31.
//

import Foundation
import VSFoundation
import CoreLocation

public extension Path {
  func convertFromPixelToMapCoordinate(converter: ICoordinateConverter) -> (head: [CLLocationCoordinate2D], body: [CLLocationCoordinate2D], tail: [CLLocationCoordinate2D]) {
    return (
      head: self.head.map { $0.fromPixelToLatLng(converter: converter) },
      body: self.body.map { $0.fromPixelToLatLng(converter: converter) },
      tail: self.tail.map { $0.fromPixelToLatLng(converter: converter) }
    )
  }
}
