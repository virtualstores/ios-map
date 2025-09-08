//
//  MapMachineStates.swift
//  VSMap
//
//  Created by Théodore Roos on 2025-03-27.
//

import Foundation
import VSFoundation

protocol IMapControllerState: Disposable {
  var state: MapState { get }
  func set(mapController: IMapController?, options: StateOptions)
  func onEnter(previousState: MapState?)
  func onQRCodeStart()
  func onPathfindingActivated()
  func onPathfindingDeactivated()
  func onPositionUpdate(position: VPSOutputSignal.Position)
  func onExit()
}

extension IMapControllerState {
  func dispose() {}
  func onQRCodeStart() {}
  func onPathfindingActivated() {}
  func onPathfindingDeactivated() {}
  func onPositionUpdate(position: VPSOutputSignal.Position) {}
  func onExit() {}
}

class MapControllerStatePending {
  @OptionalInject var mapRepository: MapRepository?
  var stateMachine: IMapStateMachine
  private var previousState: MapState?
  private var mapController: IMapController?
  private var options = StateOptions()

  init(stateMachine: IMapStateMachine, previousState: MapState? = nil, mapController: IMapController? = nil) {
    self.stateMachine = stateMachine
    self.previousState = previousState
    self.mapController = mapController
  }
}

extension MapControllerStatePending: IMapControllerState {
  func dispose() {
    mapRepository = nil
    previousState = nil
    mapController = nil
  }
  
  var state: MapState { .pending }

  func set(mapController: IMapController?, options: StateOptions) {
    self.mapController = mapController
    self.options = options
  }

  func onEnter(previousState: MapState?) {
    self.previousState = previousState
    mapController?.camera.updateCameraMode(with: .containMap)
    mapController?.set(userMarkerVisibility: false)
    mapController?.path.hidePathfinding()
    if options.controlStartScanLocationVisibility {
      mapController?.marker.setStartLocationsVisibility(isVisible: false)
    }
  }

  func onPathfindingActivated() {
    guard
      mapRepository?.isPositionActive ?? false,
      mapRepository?.currentPosition?.trustedPosition ?? false || mapRepository?.isReferenceAngleCertain ?? false
    else { stateMachine.transitionToSate(toState: .locationUnknown, fromState: state); return }
    stateMachine.transitionToSate(toState: .locationKnown, fromState: state)
  }
}

class MapControllerStateLocationKnown {
  var stateMachine: IMapStateMachine
  private var mapController: IMapController?
  private var options = StateOptions()

  init(stateMachine: IMapStateMachine, mapController: IMapController? = nil) {
    self.stateMachine = stateMachine
    self.mapController = mapController
  }
}

extension MapControllerStateLocationKnown: IMapControllerState {
  var state: MapState { .locationKnown }

  func dispose() {
    mapController = nil
  }

  func onEnter(previousState: MapState?) {
    mapController?.camera.updateCameraMode(with: .followUser3D())
    mapController?.set(userMarkerVisibility: true)
    mapController?.path.hidePathfinding()
    mapController?.path.showHead()
    if options.controlStartScanLocationVisibility {
      mapController?.marker.setStartLocationsVisibility(isVisible: false)
    }
  }

  //func adjustZoomLevel(for std: Double) {
  //  let rtls = mapRepository.mapData.rtlsOptions
  //  let squareMeters = rtls.boundingBoxInMeters?.squareMeters ?? rtls.squareMeters
  //  let zoomLevel = FollowUser3DOptions().getZoomLevelForArea(mapSquareMeters: squareMeters)
  //  let zoomIncrement = 0.3
  //  switch std {
  //  case ..<5: cameraController?.set(override: .followUser3D(zoomLevel - zoomIncrement))
  //  case 5..<10: cameraController?.set(override: .followUser3D(zoomLevel - (zoomIncrement * 2)))
  //  case 10..<15: cameraController?.set(override: .followUser3D(zoomLevel - (zoomIncrement * 3)))
  //  case 15..<20: cameraController?.set(override: .followUser3D(zoomLevel - (zoomIncrement * 4)))
  //  case 20...: cameraController?.set(override: .followUser3D(zoomLevel - (zoomIncrement * 5)))
  //  default: break
  //  }
  //}

  func set(mapController: IMapController?, options: StateOptions) {
    self.mapController = mapController
    self.options = options
  }

  func onPathfindingDeactivated() {
    stateMachine.transitionToSate(toState: .pending, fromState: state)
  }
}

class MapControllerStateLocationUnknown {
  var stateMachine: IMapStateMachine
  private var mapController: IMapController?
  private var options = StateOptions()

  private var lastLocationUpdateTime: Date = .init()
  private var lastKnownLocation: VPSOutputSignal.Position?

  init(stateMachine: IMapStateMachine, mapController: IMapController? = nil, lastLocationUpdateTime: Date = .init(), lastKnownLocation: VPSOutputSignal.Position? = nil) {
    self.stateMachine = stateMachine
    self.mapController = mapController
    self.lastLocationUpdateTime = lastLocationUpdateTime
    self.lastKnownLocation = lastKnownLocation
  }
}

extension MapControllerStateLocationUnknown: IMapControllerState {
  var state: MapState { .locationUnknown }

  func dispose() {
    mapController = nil
  }
  
  func onEnter(previousState: MapState?) {
    lastLocationUpdateTime = .init()
    mapController?.camera.updateCameraMode(with: .containMap)
    mapController?.set(userMarkerVisibility: false)
    mapController?.path.hidePathfinding()
    if options.controlStartScanLocationVisibility {
      mapController?.marker.setStartLocationsVisibility(isVisible: true)
    }
  }
  
  func set(mapController: IMapController?, options: StateOptions) {
    self.mapController = mapController
    self.options = options
  }

  func onQRCodeStart() {
    stateMachine.transitionToSate(toState: .locationKnown, fromState: state)
  }
  
  func onPathfindingDeactivated() {
    stateMachine.transitionToSate(toState: .pending, fromState: state)
  }
  
  func onPositionUpdate(position: VPSOutputSignal.Position) {
    guard lastKnownLocation?.point != position.point else { return }
    lastKnownLocation = position

    if !position.trustedPosition {
      lastLocationUpdateTime = .init()
    } else if Date().timeIntervalSince(lastLocationUpdateTime) >= 10 {
      stateMachine.transitionToSate(toState: .locationKnown, fromState: state)
    }
  }
  
  func onExit() {
    lastLocationUpdateTime = .init()
  }
}
