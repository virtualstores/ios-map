//
//  TT2CLHeading.swift
//  VSMap
//
//  Created by Hripsime on 2022-02-14.
//

import Foundation
import CoreLocation
import MapboxMaps
import VSFoundation

class TT2CLHeading: CLHeading {
    var _magneticHeading: CLLocationDirection?
    var _trueHeading: CLLocationDirection?

    open override var magneticHeading: CLLocationDirection {
        get {
            Logger.init().log(message: "getter invoked magneticHeading")
            return _magneticHeading ?? 0.0
        }
        
        set {
            print("setter invoked magneticHeading \(newValue)")
        }
    }
    
    open override var trueHeading: CLLocationDirection {
        get {
            Logger.init().log(message: "getter invoked trueHeading")
            return _trueHeading ?? 0.0
        }
        
        set {
            print("setter invoked trueHeading \(newValue)")
        }
    }
    
    open override var headingAccuracy: CLLocationDirection {
        get {
            Logger.init().log(message: "getter invoked headingAccuracy")
            return 1.0
        }
        
        set {
            print("setter invoked headingAccuracy \(newValue)")
        }
    }
    
    open override var timestamp: Date {
        get {
            Logger.init().log(message: "getter invoked timestamp")
            return Date()
        }
        
        set {
            print("setter invoked timestamp \(newValue)")
        }
    }
}

