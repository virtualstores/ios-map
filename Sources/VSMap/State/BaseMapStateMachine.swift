//
//  BaseMapStateMachine.swift
//  VSMap
//
//  Created by Théodore Roos on 2025-03-27.
//

import Combine
import VSFoundation

protocol IMapStateMachine: Disposable {
  var mapStatePublisher: CurrentValueSubject<MapState?, Never> { get }
  func onQRCodeStart(mapController: IMapController)
  func set(mapController: IMapController?, options: StateOptions)
  func onPositionUpdate(position: VPSOutputSignal.Position, mapController: IMapController)
  func transitionToSate(toState: MapState, fromState: MapState?)
  func onDestroy()
}

public struct StateOptions {
  public let preset: UIPreset
  public let controlStartScanLocationVisibility: Bool
  public let forceUseQRStart: Bool

  public init(preset: UIPreset = .none, controlStartScanLocationVisibility: Bool = true, forceUseQRStart: Bool = true) {
    self.preset = preset
    self.controlStartScanLocationVisibility = controlStartScanLocationVisibility
    self.forceUseQRStart = forceUseQRStart
  }

  public enum UIPreset {
    case none, singleItemWayfinding
  }
}

class BaseMapStateMachine {
  @OptionalInject var mapRepository: MapRepository?

  var mapStatePublisher: CurrentValueSubject<MapState?, Never> = .init(nil)

  private let tag = "BaseMapStateMachine"
  private var states: [MapState: IMapControllerState] = [:]

  private var currentState: IMapControllerState?
  private var mapController: IMapController?
  private var cancellable = Set<AnyCancellable>()

  init() {
    states = [
      .pending: MapControllerStatePending(stateMachine: self),
      .locationKnown: MapControllerStateLocationKnown(stateMachine: self),
      .locationUnknown: MapControllerStateLocationUnknown(stateMachine: self),
    ]
    currentState = states[.pending]
    currentState?.onEnter(previousState: nil)
  }

  deinit {
    Logger(verbosity: .info).log(tag: tag, message: "deinit")
    dispose()
  }

  private func bindPublishers() {
    mapController?.path.onGoalsUpdatedPublisher
      .compactMap { $0 }
      .sink(receiveValue: { [weak self] (goal) in
        guard let self = self else { return }
        if goal.count > 0 {
          currentState?.onPathfindingActivated()
        } else {
          currentState?.onPathfindingDeactivated()
        }
      }).store(in: &cancellable)
  }
}

extension BaseMapStateMachine: IMapStateMachine {
  func dispose() {
    Logger(verbosity: .info).log(tag: tag, message: "dispose")
    mapRepository = nil
    currentState = nil
    mapController = nil
    states.forEach { $0.value.dispose() }
    states = [:]
  }
  
  func onQRCodeStart(mapController: IMapController) {
    guard self.mapController?.id == mapController.id else { return }
    currentState?.onQRCodeStart()
  }
  
  func set(mapController: IMapController?, options: StateOptions) {
    cancellable.removeAll()
    self.mapController = mapController
    bindPublishers()

    states.forEach { $0.value.set(mapController: mapController, options: options) }

    if mapRepository?.isPositionActive ?? false {
      transitionToSate(toState: .pending, fromState: currentState?.state)
    } else {
      transitionToSate(toState: .pending, fromState: nil)
    }
  }
  
  func onPositionUpdate(position: VPSOutputSignal.Position, mapController: IMapController) {
    guard self.mapController?.id == mapController.id else { return }
    currentState?.onPositionUpdate(position: position)
  }
  
  func transitionToSate(toState: MapState, fromState: MapState?) {
    guard toState != currentState?.state else { return }
    currentState?.onExit()
    currentState = states[toState]
    currentState?.onEnter(previousState: fromState)
    mapStatePublisher.send(currentState?.state)
  }
  
  func onDestroy() {
    cancellable.removeAll()
  }
}
