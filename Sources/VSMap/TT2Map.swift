//
//  TT2Map.swift
//  VSMap
//
//  Created by Théodore Roos on 2025-03-27.
//

import VSFoundation

struct TT2MapConfig: Config {
  func configure(_ injector: VSFoundation.Injector) {
    // Repositories
    injector.map(MapRepository.self) { MapRepository() }

    // State machine
    injector.map(IMapStateMachine.self) { BaseMapStateMachine() }
  }
}

public class TT2Map {
  private let context: Context
  private var mapInternal: TT2MapInternal

  public var manager: IMapManager { mapInternal }

  public init() {
    context = Context(TT2MapConfig())
    mapInternal = TT2MapInternal()
  }
}

class TT2MapInternal {
  @Inject var repository: MapRepository
  @Inject var stateMachine: IMapStateMachine
}

extension TT2MapInternal: IMapManager {
  func set(isPositionActive: Bool) {
    repository.isPositionActive = isPositionActive
  }
  
  func set(currentLocation position: VSFoundation.VPSOutputSignal.Position?) {
    repository.currentPosition = position
  }
}
