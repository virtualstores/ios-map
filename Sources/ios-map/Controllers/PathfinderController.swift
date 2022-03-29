//
//  PathfinderController.swift
//  
//
//  Created by Théodore Roos on 2022-03-29.
//

import Foundation
import VSFoundation
import Combine
import CoreGraphics
import MapboxMaps

class PathfinderController {
  private let SOURCE_ID = "line-source"
  private let LINE_LAYER_ID = "line-layer"

  private let PROP_VISIBLE = "mark_visible"

  private let mapRepository: MapRepository
  private var cancellable = Set<AnyCancellable>()

  private var currentGoal: Goal?
  private var sortedGoals: [Goal] = []
  private var currentHeadPath: [CLLocationCoordinate2D] = []
  private var currentBodyPath: [CLLocationCoordinate2D] = []
  private var currentTailPath: [CLLocationCoordinate2D] = []

  private var lines: [String : PathfinderLine] = [:]
  private var lineFeatures: [String : Feature] = [:]

  private var _lineSource: GeoJSONSource?
  private var lineSource: GeoJSONSource {
    guard let lineSource = _lineSource else { fatalError("ERROOOOOOOOOR!") }

    return lineSource
  }

  private var _lineLayer: LineLayer?
  private var lineLayer: LineLayer {
    guard let lineLayer = _lineLayer else { fatalError("ERROOOOOOR") }

    return lineLayer
  }

  var pathfinder: IFoundationPathfinder? {
    didSet {
      self.bindPublishers()
    }
  }

  init(mapRepository: MapRepository) {
    self.mapRepository = mapRepository
  }

  func initSources() {
    _lineSource = GeoJSONSource()
    _lineSource?.data = .empty

    _lineLayer = LineLayer(id: LINE_LAYER_ID)
    _lineLayer?.source = SOURCE_ID
    _lineLayer?.lineColor = .constant(StyleColor(.red))
    _lineLayer?.visibility = .constant(.visible)
  }

  var latestRefresh: Date = Date()
  private func refreshLines() {
    let lines = lineFeatures.map { $0.value }
    let collection = FeatureCollection(features: lines)

    guard Date().timeIntervalSince(latestRefresh) > 1.0 else { return }
    Logger(verbosity: .info).log(message: "Pathfinder refresh, \(Date())")
    latestRefresh = Date()
    _lineSource?.data = .featureCollection(collection)
    try! mapRepository.style.updateGeoJSONSource(withId: SOURCE_ID, geoJSON: .featureCollection(collection))
  }

  private func create(line: PathfinderLine, completion: @escaping (Result<Feature, Error>) -> Void) {
    let positions = line.position.map { $0.asMapBoxCoordinate }
    let longitude = mapRepository.mapData.converter.convertFromMetersToMapCoordinate(input: 5)
    let latitude = mapRepository.mapData.converter.convertFromMetersToMapCoordinate(input: 10)

    var feature = Feature(geometry: .point(Point(LocationCoordinate2D(latitude: latitude, longitude: longitude))))//Feature(geometry: .multiPoint(MultiPoint(positions)))
    feature.identifier = .string(line.id)
    feature.properties = JSONObject()
    feature.properties?[self.PROP_VISIBLE] = .boolean(true)

    completion(.success(feature))
  }

  func onNewPosition(position: CGPoint) {
    let converter = mapRepository.mapData.converter
    pathfinder?.setUserPosition(position: position.fromMeterToPixel(converter: converter))
    if !currentHeadPath.isEmpty {
      let line = PathfinderLine(id: "test", position: currentHeadPath)
      create(line: line) { (result) in
        switch result {
        case .success(let feature):
          self.lines[line.id] = line
          self.lineFeatures[line.id] = feature
        case .failure(let error): Logger(verbosity: .critical).log(message: "ERROR!!!! \(error.localizedDescription)")
        }
      }
    }
    refreshLines()
  }

  func bindPublishers() {
    pathfinder?.currentGoalUpdatedPublisher
      .compactMap { $0 }
      .sink(receiveValue: { [weak self] (goal) in
        self?.currentGoal = goal
      }).store(in: &cancellable)
    pathfinder?.sortedGoalUpdatedPublisher
      .compactMap { $0 }
      .sink(receiveValue: { [weak self] (goals) in
        self?.sortedGoals = goals
      }).store(in: &cancellable)
    pathfinder?.pathUpdatedPublisher
      .compactMap { $0 }
      .sink(receiveValue: { [weak self] (path) in
        guard let converter = self?.mapRepository.mapData.converter else { return }
        let modified = path.convertFromPixelToMapCoordinate(converter: converter)
        self?.currentHeadPath = modified.head
        self?.currentBodyPath = modified.body
        self?.currentTailPath = modified.tail
      }).store(in: &cancellable)
    pathfinder?.hasGoal
      .sink(receiveValue: { [weak self] (hasGoal) in

      }).store(in: &cancellable)
  }

  func onStyleUpdated() {
    initSources()

    try! mapRepository.style.addSource(lineSource, id: SOURCE_ID)
    try! mapRepository.style.addLayer(lineLayer, layerPosition: LayerPosition.default)
  }
}

public struct PathfinderLine {
  let id: String
  let position: [CLLocationCoordinate2D]
}

extension Path {
  func convertFromPixelToMapCoordinate(converter: ICoordinateConverter) -> (head: [CLLocationCoordinate2D], body: [CLLocationCoordinate2D], tail: [CLLocationCoordinate2D]) {
    return (
      head: self.head.map { $0.fromPixelToLatLng(converter: converter) },
      body: self.body.map { $0.fromPixelToLatLng(converter: converter) },
      tail: self.tail.map { $0.fromPixelToLatLng(converter: converter) }
    )
  }
}

extension CLLocationCoordinate2D {
  var asMapBoxCoordinate: LocationCoordinate2D {
    LocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}
