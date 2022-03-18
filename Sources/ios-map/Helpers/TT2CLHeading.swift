//
//  TT2CLHeading.swift
//  VSMap
//
//  Created by Hripsime on 2022-02-14.
//

import Foundation
import CoreLocation
@_implementationOnly import MapboxMaps
import VSFoundation

class TT2CLHeading: CLHeading {
    let heading: Double

    open override var magneticHeading: CLLocationDirection {
        get {
            Logger.init().log(message: "getter invoked magneticHeading")
            return heading
        }
        
        set {
            Logger.init().log(message: "setter invoked magneticHeading \(newValue)")
        }
    }
    
    open override var trueHeading: CLLocationDirection {
        get {
            Logger.init().log(message: "getter invoked trueHeading")
            return heading
        }
        
        set {
            Logger.init().log(message: "setter invoked trueHeading \(newValue)")
        }
    }
    
    open override var headingAccuracy: CLLocationDirection {
        get {
            Logger.init().log(message: "getter invoked headingAccuracy")
            return 1.0
        }
        
        set {
            Logger.init().log(message: "setter invoked headingAccuracy \(newValue)")
        }
    }
    
    open override var timestamp: Date {
        get {
            Logger.init().log(message: "getter invoked timestamp")
            return Date()
        }
        
        set {
            Logger.init().log(message: "setter invoked timestamp \(newValue)")
        }
    }

    init(heading: Double) {
        print("init heading")
        self.heading = heading
        super.init()
    }
    
    func update(heading: Double) -> TT2CLHeading {
        self.magneticHeading = heading
        self.headingAccuracy = 1.0
        self.timestamp = Date()
        self.trueHeading = heading
        
        return self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

