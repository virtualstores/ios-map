//
//  TT2Map.swift
//  VSMap
//
//  Created by Théodore Roos on 2025-03-27.
//

import VSFoundation

class TT2MapConfig: Config {
  var disposables = [Disposable]()

  func configure(_ injector: VSFoundation.Injector) {
    injector.map(MapRepository.self) { [weak self] in
      let inject = MapRepository()
      self?.disposables.append(inject)
      return inject
    }
    injector.map(IMapStateMachine.self) { [weak self] in
      let inject = BaseMapStateMachine()
      self?.disposables.append(inject)
      return inject
    }
  }

  func dispose() {
    // TODO:
  }

  func deconfigure(_ injector: Injector) {
    disposables.forEach { $0.dispose() }
    disposables.removeAll()
    injector.unmap(MapRepository.self)
    injector.unmap(IMapStateMachine.self)
  }
}

public class TT2Map: Disposable {
  private let tag: String = "TT2Map"
  private var context: Context?
  private var mapInternal: TT2MapInternal?

  public var manager: IMapManager {
    guard let map = mapInternal else {
      fatalError("Map Internal not initialized")
    }
    return map
  }

  public init() {
    context = Context(TT2MapConfig())
    mapInternal = TT2MapInternal()
  }

  deinit {
    Logger(verbosity: .info).log(tag: tag, message: "deinit")
    dispose()
  }

  public func dispose() {
    Logger(verbosity: .info).log(tag: tag, message: "dispose")
    mapInternal?.dispose()
    mapInternal = nil
    context?.dispose()
    context = nil
  }
}

class TT2MapInternal {
  @OptionalInject var repository: MapRepository?
  @OptionalInject var stateMachine: IMapStateMachine?
  private let tag: String = "TT2MapInternal"

  deinit {
    Logger(verbosity: .info).log(tag: tag, message: "deinit")
    dispose()
  }
}

extension TT2MapInternal: IMapManager {
  func dispose() {
    Logger(verbosity: .info).log(tag: tag, message: "dispose")
    repository = nil
    stateMachine = nil
  }

  func set(isPositionActive: Bool) {
    repository?.isPositionActive = isPositionActive
  }
  
  func set(currentLocation position: VSFoundation.VPSOutputSignal.Position?) {
    repository?.currentPosition = position
  }

  func set(isReferenceAngleCertain: Bool) {
    repository?.isReferenceAngleCertain = isReferenceAngleCertain
  }
}
