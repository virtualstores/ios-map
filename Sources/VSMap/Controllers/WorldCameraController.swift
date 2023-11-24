//
//  WorldCameraController.swift
//  VSMap
//
//  Created by Hripsime on 2022-02-16.
//

import Foundation
import CoreGraphics
import VSFoundation
import MapboxMaps
import SwiftUI

class WorldCameraController: ICameraController {
  public var requestedCameraMode: CameraModes?
  public var actualCameraMode: CameraMode? {
    didSet {
      actualCameraMode?.onEnter()
    }
  }

  private var mapView: MapView
  private var mapRepository: MapRepository
  private var rtlsOptions: RtlsOptions?
  private var lastLocation: Location?
  private var revertCameraModeTimer: Timer?
  private var revertCameraInterval = 4.0

  public init(mapView: MapView, mapRepository: MapRepository) {
    self.mapView = mapView
    self.mapRepository = mapRepository
  }

  func setInitialCameraMode(for mode: CameraModes) {
    createCameraMode()
  }

  public func updateLocation(with newLocation: CLLocationCoordinate2D, direction: Double) {
    actualCameraMode?.onLocationUpdated(newLocation: newLocation, direction: direction)
  }

  public func updateCameraMode(with mode: CameraModes) {
    requestedCameraMode = mode
    createCameraMode()
  }

  public func setAutoCameraResetDelay(with milliseconds: Double) {
    revertCameraInterval = milliseconds
  }

  func resetCameraMode() { createCameraMode() }

  private func createCameraMode() {
    mapView.viewport.transition(to: mapView.viewport.makeFollowPuckViewportState(options: FollowPuckViewportStateOptions(zoom: 16, bearing: .heading, pitch: 25)))
  }

  private func revertCameraModeAfter(interval: Double) {
    self.revertCameraModeTimer?.invalidate()
    self.revertCameraModeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false, block: { (_) in
      self.createCameraMode()
      self.revertCameraModeTimer?.invalidate()
      self.revertCameraModeTimer = nil
    })
  }
}

extension WorldCameraController: LocationConsumer {
  public func locationUpdate(newLocation: Location) {
    self.lastLocation = newLocation
  }
}

extension WorldCameraController: GestureManagerDelegate {
  public func gestureManager(_ gestureManager: GestureManager, didBegin gestureType: GestureType) {
    self.revertCameraModeTimer?.invalidate()
    //Logger(verbosity: .debug).log(message: "didBegin")
  }

  public func gestureManager(_ gestureManager: GestureManager, didEnd gestureType: GestureType, willAnimate: Bool) {
    self.revertCameraModeAfter(interval: revertCameraInterval)
    //Logger(verbosity: .debug).log(message: "didEnd")
  }

  public func gestureManager(_ gestureManager: GestureManager, didEndAnimatingFor gestureType: GestureType) {
    //Logger(verbosity: .debug).log(message: "didEndAnimatingFor")
  }
}
