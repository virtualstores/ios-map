//
//  File.swift
//  
//
//  Created by Hripsime on 2022-03-30.
//

import Foundation
import VSFoundation

extension PathfindingGoal.GoalType {
  var asGoalType: Goal.GoalType {
    switch self {
    case .start: return .start
    case .target: return .target
    case .end: return .end
    }
  }
}

public extension PathfindingGoal {
   var asGoal: Goal {
    Goal(id: id, position: position, data: data, type: type.asGoalType, floorLevelId: floorLevelId)
  }
}
