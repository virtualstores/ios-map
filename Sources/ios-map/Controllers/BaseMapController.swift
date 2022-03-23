//
//  BaseMapController.swift
//  VSMap
//
//  Created by Hripsime on 2022-02-13.
//

import Foundation
import CoreLocation
import CoreGraphics
import VSFoundation
import MapboxMaps

public class BaseMapController: IMapController {
    public var dragDidBegin: (() -> Void)? = nil
    public var dragDidEnd: (() -> Void)? = nil

    var mapData: MapData?

    public var location: ILocation {
        guard let location = internalLocation else {
            fatalError("Map not loadede")
        }

        return location
    }

    public var camera: ICameraController? {
        guard let camera = cameraController else {
            fatalError("Camera not loadede")
        }

        return camera
    }

    //Controllers for helpin baseController to setup map
    var internalLocation: LocationController?
    var cameraController: CameraController?

    private var mapViewContainer: TT2MapView
    private var currentStyle: Style?

    private var styleLoaded: Bool = false

    public init(with token: String, view: TT2MapView) {
        self.mapViewContainer = view
        self.mapViewContainer.setup(with: token)
    }

    /// Map loader which will receave all needed  setup information
    public func loadMap(with mapData: MapData) {
        self.mapData = mapData

        guard let style = mapData.rtlsOptions.mapBoxUrl, let styleURI = StyleURI(rawValue: style) else { return }

        mapViewContainer.mapStyle = mapData.style
        mapViewContainer.addLoadingView()
        mapViewContainer.mapView.mapboxMap.loadStyleURI(styleURI) { [weak self] result in
            switch result {
            case .success(let style):
                self?.currentStyle = style
                self?.onStyleLoaded()
                self?.setupCamera(with: .free)
                self?.mapViewContainer.dismissLoadingScreen()
            case let .failure(error):
                Logger.init(verbosity: .debug).log(message: "The map failed to load the style: \(error)")
            }
        }
    }

    public func start() {
        mapViewContainer.addLoadingView()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setupUserMarker()
        }
    }

    private func onStyleLoaded() {
        internalLocation = LocationController()
        guard let location = internalLocation else { return }

        mapViewContainer.mapView.location.overrideLocationProvider(with: location)
        mapViewContainer.mapView.location.locationProvider.startUpdatingLocation()
        mapViewContainer.mapView.location.locationProvider.startUpdatingHeading()
        mapViewContainer.mapView.location.options.activityType = .other
        mapViewContainer.mapView.location.options.puckBearingSource = .heading

        styleLoaded = true
        internalLocation?.setOptions(options: mapViewContainer.mapView.location.options)
    }

      private func setupUserMarker() {
          guard styleLoaded else { return }
          let image = mapData?.style?.userMarkerImage

          if let userMarkerImage = image {
              let config = Puck2DConfiguration(topImage: userMarkerImage, bearingImage: nil, shadowImage: nil, scale: .constant(1.5), showsAccuracyRing: true)
              mapViewContainer.mapView.location.options.puckType = .puck2D(config)
          } else {
              mapViewContainer.mapView.location.options.puckType = .puck2D()
          }

          DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
              self.mapViewContainer.dismissLoadingScreen()
          }
      }

    private func setupCamera(with mode: CameraModes) {
        guard let mapData = self.mapData else { return }

        cameraController = CameraController(mapView: mapViewContainer.mapView, mapData: mapData)

        if let controller = cameraController {
            //controller.resetCameraToMapBounds()
            controller.updateCameraMode(with: mode)
            mapViewContainer.mapView.location.addLocationConsumer(newConsumer: controller)
            mapViewContainer.mapView.gestures.delegate = cameraController
        }
    }

    public func updateUserLocation(newLocation: CGPoint?, std: Float?) {
        guard let position = newLocation, let converter = mapData?.converter, let std = std else { return }

        let mapPosition = position.convertFromMeterToLatLng(converter: converter)
        let convertedStd = converter.convertFromMetersToPixels(input: Double(std))
        let mapStd = converter.convertFromPixelsToMapCoordinate(input: convertedStd)

        location.updateUserLocation(newLocation: mapPosition, std: Float(mapStd))
        cameraController?.updateLocation(with: mapPosition, direction: Double(std))
    }

    public func updateUserDirection(newDirection: Double) {
        location.updateUserDirection(newDirection: newDirection)
    }

    public func stop() {
        mapViewContainer.addLoadingView()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.mapViewContainer.mapView.location.options.puckType = .none
            self.mapViewContainer.mapView.location.locationProvider.stopUpdatingLocation()
            self.mapViewContainer.mapView.location.locationProvider.stopUpdatingHeading()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.mapViewContainer.dismissLoadingScreen()
            }
        }
    }

    public func reset() { }
}

