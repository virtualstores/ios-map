//
// BaseMapMark.swift
// VSFoundation
//
// Created by Hripsime on 2022-02-18.
// Copyright (c) 2022 Virtual Stores

import Foundation
import VSFoundation
import CoreGraphics
import UIKit

public class BaseMapMark: MapMark {
    public var id: String
    public var position: CGPoint
    public var floorLevelId: Int64?
    public var triggerRadius: Double?
    public var data: UIImage?
    public var clusterable: Bool
    public var deletable: Bool
    public var defaultVisibility: Bool
    public var offsetX: Double
    public var offsetY: Double
    
    public init(
        id: String,
        position: CGPoint,
        floorLevelId: Int64?,
        triggerRadius: Double?,
        data: UIImage?,
        clusterable: Bool,
        deletable: Bool,
        defaultVisibility: Bool,
        offsetX: Double,
        offsetY: Double
    ) {
        self.id = id
        self.position = position
        self.floorLevelId = floorLevelId
        self.triggerRadius = triggerRadius
        self.data = data
        self.clusterable = clusterable
        self.deletable = deletable
        self.defaultVisibility = defaultVisibility
        self.offsetY = offsetY
        self.offsetX = offsetX
    }
    
    public func createViewHolder(completion: @escaping (MapMarkViewHolder) -> ()) {
       let marker =  MapMarkViewHolder(id: self.id)
        
        let data = self.data 
        marker._renderedBitmap = data
        
        completion(marker)
    }
}
