//
//  Goal+Extension.swift
//  
//
//  Created by Hripsime on 2022-03-30.
//

import Foundation
import VSFoundation
import CoreGraphics

extension Goal.GoalType {
  var asPathfindingGoalType: PathfindingGoal.GoalType {
    switch self {
    case .start: return .start
    case .target: return .target
    case .end: return .end
    }
  }
}

public extension Goal {
  var asPathfindeingGoal: PathfindingGoal {
    PathfindingGoal(id: id, position: position, data: data, type: type.asPathfindingGoalType, floorLevelId: floorLevelId)
  }

  func convertFromMeterToPixel(converter: ICoordinateConverter) -> Goal {
    let height = converter.heightInMeters
    let x = converter.convertFromMetersToPixels(input: position.x)
    let y: Double
    if height > 0.0 {
      y = converter.convertFromMetersToPixels(input: height - position.y)
    } else {
      y = converter.convertFromMetersToPixels(input: position.y)
    }
    return Goal(id: id, position: CGPoint(x: x, y: y), data: data, type: type, floorLevelId: floorLevelId)
  }

  func convertFromPixelToMeter(converter: ICoordinateConverter) -> Goal {
    let height = converter.heightInPixels
    let x = converter.convertFromPixelsToMeters(input: position.x)
    let y: Double
    if height > 0.0 {
      y = converter.convertFromPixelsToMeters(input: height - position.y)
    } else {
      y = converter.convertFromPixelsToMeters(input: position.y)
    }
    return Goal(id: id, position: CGPoint(x: x, y: y), data: data, type: type, floorLevelId: floorLevelId)
  }
}
