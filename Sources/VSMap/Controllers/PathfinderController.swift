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
  let SOURCE_ID_HEAD = "pathfinding-source-head"
  let SOURCE_ID_BODY = "pathfinding-source-body"
  let SOURCE_ID_TAIL = "pathfinding-source-tail"
  let SOURCE_ID_END = "end-source"

  let LAYER_ID_HEAD = "pathfinding-head"
  let LAYER_ID_BODY = "pathfinding-body"
  let LAYER_ID_TAIL = "pathfinding-tail"
  let LAYER_ID_END = "pathfinding-end"

  private let PROP_VISIBLE = "mark_visible"

  private var mapRepository: MapRepository
  private var cancellable = Set<AnyCancellable>()

  private var _onCurrentGoalChangePublisher: CurrentValueSubject<PathfindingGoal?, Never> = .init(nil)
  private var _onSortedGoalChangePublisher: CurrentValueSubject<[PathfindingGoal], Never> = .init([])

  private var _currentGoal: PathfindingGoal?
  private var _sortedGoals: [PathfindingGoal] = []
  private var allGoals: [String : PathfindingGoal] = [:]
  private var currentHeadPath: [CLLocationCoordinate2D] = []
  private var currentBodyPath: [CLLocationCoordinate2D] = []
  private var currentTailPath: [CLLocationCoordinate2D] = []

  private var lines: [String : PathfinderLine] = [:]
  private var lineFeatures: [String : Feature] = [:]

  private var _lineSourceHead: GeoJSONSource?
  private var lineSourceHead: GeoJSONSource {
    guard let lineSource = _lineSourceHead else { fatalError("ERROOOOOOOOOR!") }

    return lineSource
  }

  private var _lineSourceBody: GeoJSONSource?
  private var lineSourceBody: GeoJSONSource {
    guard let lineSource = _lineSourceBody else { fatalError("ERROOOOOOOOOR!") }

    return lineSource
  }

  private var _lineSourceTail: GeoJSONSource?
  private var lineSourceTail: GeoJSONSource {
    guard let lineSource = _lineSourceTail else { fatalError("ERROOOOOOOOOR!") }

    return lineSource
  }

  private var _lineSourceEnd: GeoJSONSource?
  private var lineSourceEnd: GeoJSONSource {
    guard let lineSource = _lineSourceEnd else { fatalError("ERROOOOOOOOOR!") }

    return lineSource
  }

  private var _lineLayerHead: LineLayer?
  private var lineLayerHead: LineLayer {
    guard let lineLayer = _lineLayerHead else { fatalError("ERROOOOOOR") }

    return lineLayer
  }

  private var _lineLayerBody: LineLayer?
  private var lineLayerBody: LineLayer {
    guard let lineLayer = _lineLayerBody else { fatalError("ERROOOOOOR") }

    return lineLayer
  }

  private var _lineLayerTail: LineLayer?
  private var lineLayerTail: LineLayer {
    guard let lineLayer = _lineLayerTail else { fatalError("ERROOOOOOR") }

    return lineLayer
  }

  private var _circleLayerEnd: CircleLayer?
  private var circleLayerEnd: CircleLayer {
    guard let circleLayerEnd = _circleLayerEnd else { fatalError("ERROOOOOOR") }

    return circleLayerEnd
  }

  var pathfinder: IFoundationPathfinder? {
    didSet {
      self.bindPublishers()
    }
  }

  var style: Style { mapRepository.style }
  var converter: ICoordinateConverter { mapRepository.mapData.converter }
  var mapOptions: VSFoundation.MapOptions { mapRepository.mapOptions }
  var pathfindingStyle: VSFoundation.MapOptions.PathfindingStyle { mapOptions.pathfindingStyle }

  init(mapRepository: MapRepository) {
    self.mapRepository = mapRepository
  }

  func onFloorChange(mapRepository: MapRepository) {
    self.mapRepository = mapRepository
    if filterGoals().isEmpty {
      hidePathfinding()
    } else {
      showPathfinding()
    }
  }

  func initSources() {
    guard _lineSourceHead == nil else {
      return
    }

    _lineSourceHead = GeoJSONSource()
    _lineSourceHead?.data = .empty
    _lineSourceBody = GeoJSONSource()
    _lineSourceBody?.data = .empty
    _lineSourceTail = GeoJSONSource()
    _lineSourceTail?.data = .empty
    _lineSourceEnd = GeoJSONSource()
    _lineSourceEnd?.data = .empty

    _lineLayerHead = LineLayer(id: LAYER_ID_HEAD)
    _lineLayerHead?.source = SOURCE_ID_HEAD
    _lineLayerHead?.lineCap = .constant(LineCap(rawValue: pathfindingStyle.pathStyleHead.lineCap) ?? .round)
    _lineLayerHead?.lineJoin = .constant(LineJoin(rawValue: pathfindingStyle.pathStyleHead.lineJoin) ?? .round)
    _lineLayerHead?.lineColor = .constant(StyleColor(pathfindingStyle.pathStyleHead.lineColor))
    _lineLayerHead?.visibility = .constant(.visible)
    _lineLayerHead?.lineWidth = .expression(
      Exp(.interpolate) {
        Exp(.exponential) { 2 }
        Exp(.zoom)
        [
          0.0: pathfindingStyle.pathStyleHead.lineWidth,
          7.5: pathfindingStyle.pathStyleHead.lineWidth * 2.5,
          10.0: pathfindingStyle.pathStyleHead.lineWidth * 5
        ]
      }
    )

    _lineLayerBody = LineLayer(id: LAYER_ID_BODY)
    _lineLayerBody?.source = SOURCE_ID_BODY
    _lineLayerBody?.lineCap = .constant(LineCap(rawValue: pathfindingStyle.pathStyleBody.lineCap) ?? .round)
    _lineLayerBody?.lineJoin = .constant(LineJoin(rawValue: pathfindingStyle.pathStyleBody.lineJoin) ?? .round)
    _lineLayerBody?.lineColor = .constant(StyleColor(pathfindingStyle.pathStyleBody.lineColor))
    _lineLayerBody?.visibility = .constant(.visible)
    _lineLayerBody?.lineWidth = .expression(
      Exp(.interpolate) {
        Exp(.exponential) { 2 }
        Exp(.zoom)
        [
          0.0: pathfindingStyle.pathStyleBody.lineWidth,
          7.5: pathfindingStyle.pathStyleBody.lineWidth * 2.5,
          10.0: pathfindingStyle.pathStyleBody.lineWidth * 5
        ]
      }
    )

    _lineLayerTail = LineLayer(id: LAYER_ID_TAIL)
    _lineLayerTail?.source = SOURCE_ID_TAIL
    _lineLayerTail?.lineCap = .constant(LineCap(rawValue: pathfindingStyle.pathStyleTail.lineCap) ?? .round)
    _lineLayerTail?.lineJoin = .constant(LineJoin(rawValue: pathfindingStyle.pathStyleTail.lineJoin) ?? .round)
    _lineLayerTail?.lineColor = .constant(StyleColor(pathfindingStyle.pathStyleTail.lineColor))
    _lineLayerTail?.visibility = .constant(.visible)
    _lineLayerTail?.lineWidth = .expression(
      Exp(.interpolate) {
        Exp(.exponential) { 2 }
        Exp(.zoom)
        [
          0.0: pathfindingStyle.pathStyleTail.lineWidth,
          7.5: pathfindingStyle.pathStyleTail.lineWidth * 2.5,
          10.0: pathfindingStyle.pathStyleTail.lineWidth * 5
        ]
      }
    )

    _circleLayerEnd = CircleLayer(id: LAYER_ID_END)
    _circleLayerEnd?.source = SOURCE_ID_END
    _circleLayerEnd?.circleColor = .constant(StyleColor(pathfindingStyle.lineEndStyle?.color ?? pathfindingStyle.pathStyleHead.lineColor))
    _circleLayerEnd?.visibility = .constant(.visible)
    _circleLayerEnd?.circleRadius = .expression(
      Exp(.interpolate) {
        Exp(.exponential) { 2 }
        Exp(.zoom)
        [
          7.5: pathfindingStyle.pathStyleHead.lineWidth * 2,
          10.0: pathfindingStyle.pathStyleHead.lineWidth * 4
        ]
      }
    )
  }

  var latestRefresh: Date = Date()
  func onNewPosition(position: CGPoint) {
    updateLocation(newLocation: position)
    guard Date().timeIntervalSince(self.latestRefresh) > 1.0 else { return }
    refreshLines()
  }

  private func refreshLines() {
      guard !allGoals.isEmpty else {
          try? self.style.updateGeoJSONSource(withId: self.SOURCE_ID_HEAD, geoJSON: .geometry(.lineString(LineString([]))))
          try? self.style.updateGeoJSONSource(withId: self.SOURCE_ID_BODY, geoJSON: .geometry(.lineString(LineString([]))))
          try? self.style.updateGeoJSONSource(withId: self.SOURCE_ID_TAIL, geoJSON: .geometry(.lineString(LineString([]))))
          try? self.style.updateGeoJSONSource(withId: self.SOURCE_ID_END, geoJSON: .geometry(.lineString(LineString([]))))
          return
      }

      self.latestRefresh = Date()
      try? self.style.updateGeoJSONSource(withId: self.SOURCE_ID_HEAD, geoJSON: .geometry(.lineString(LineString(self.currentHeadPath))))
      try? self.style.updateGeoJSONSource(withId: self.SOURCE_ID_BODY, geoJSON: .geometry(.lineString(LineString(self.currentBodyPath))))
      try? self.style.updateGeoJSONSource(withId: self.SOURCE_ID_TAIL, geoJSON: .geometry(.lineString(LineString(self.currentTailPath))))

      guard let coordinate = self.currentHeadPath.last else { return }
      try? self.style.updateGeoJSONSource(withId: self.SOURCE_ID_END, geoJSON: .geometry(.point(Point(coordinate))))
  }

  func bindPublishers() {
    pathfinder?.currentGoalUpdatedPublisher
      .compactMap { $0 }
      .sink(receiveValue: { [weak self] (goal) in
        self?._currentGoal = goal.asPathfindeingGoal
        self?._onCurrentGoalChangePublisher.send(goal.asPathfindeingGoal)
      }).store(in: &cancellable)
      
    pathfinder?.sortedGoalUpdatedPublisher
      .compactMap { $0 }
      .sink(receiveValue: { [weak self] (goals) in
        let pathfindingGoals = goals.map { $0.asPathfindeingGoal }
        self?._sortedGoals = pathfindingGoals
        self?._onSortedGoalChangePublisher.send(pathfindingGoals)
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

    try? mapRepository.style.addSource(lineSourceHead, id: SOURCE_ID_HEAD)
    try? mapRepository.style.addLayer(lineLayerHead, layerPosition: LayerPosition.below("marker-layer"))

    try? mapRepository.style.addSource(lineSourceBody, id: SOURCE_ID_BODY)
    try? mapRepository.style.addLayer(lineLayerBody, layerPosition: LayerPosition.below(LAYER_ID_HEAD))

    try? mapRepository.style.addSource(lineSourceTail, id: SOURCE_ID_TAIL)
    try? mapRepository.style.addLayer(lineLayerTail, layerPosition: LayerPosition.below(LAYER_ID_BODY))

    try? mapRepository.style.addSource(lineSourceEnd, id: SOURCE_ID_END)
    try? mapRepository.style.addLayer(circleLayerEnd, layerPosition: LayerPosition.above(LAYER_ID_HEAD))
  }
    
  deinit {
    cancellable.removeAll()
  }

  private func checkIfSwaplocationIsNeeded(goal: PathfindingGoal)  {

  }
}

extension PathfinderController: IPathfindingController {
  var state: State { .hidden }

  var onCurrentGoalChangePublisher: CurrentValueSubject<PathfindingGoal?, Never> { _onCurrentGoalChangePublisher }
  var onSortedGoalChangePublisher: CurrentValueSubject<[PathfindingGoal], Never> { _onSortedGoalChangePublisher }
  
  var currentGoal: PathfindingGoal? { _currentGoal }
  var sortedGoals: [PathfindingGoal] { _sortedGoals }

  func add(goal: PathfindingGoal, completion: @escaping (() -> Void)) {
    allGoals[goal.id] = goal
    filterAndSetGoals(completion: completion)
  }

  func add(goals: [PathfindingGoal], completion: @escaping (() -> Void)) {
    goals.forEach { goal in
      allGoals[goal.id] = goal
    }
    filterAndSetGoals(completion: completion)
  }

  func set(goals: [PathfindingGoal], completion: @escaping (() -> Void)) {
    allGoals.removeAll()
    goals.forEach { goal in
      allGoals[goal.id] = goal
    }
    filterAndSetGoals(completion: completion)
  }

  private func filterAndSetGoals(completion: @escaping (() -> Void)) {
//    pathfinder?.set(goals: filterGoals().map { $0.asGoal }, completion: {
//      DispatchQueue.main.async {
//        completion()
//      }
//    })

    pathfinder?.set(goals: filterGoals().map { $0.asGoal.convertFromMeterToPixel(converter: converter) }) {
      self.refreshLines()
      completion()
    }
  }

  private func filterGoals() -> [PathfindingGoal] {
    allGoals.values.filter { $0.floorLevelId == mapRepository.floorLevelId }.map { $0 }
  }

  func remove(goal: PathfindingGoal, completion: @escaping (() -> Void)) {
    pathfinder?.remove(goal: goal.asGoal, completion: completion)
    refreshLines()
  }

  func remove(goals: [PathfindingGoal], completion: @escaping (() -> Void)) {
    pathfinder?.remove(goals: goals.map { $0.asGoal }, completion: completion)
    refreshLines()
  }

  func popGoal() {
    pathfinder?.popGoal()
    refreshLines()
  }

  func showPathfinding() {
    showHead()
    showBody()
    showTail()
  }

  func showHead() {
    _lineLayerHead?.visibility = .constant(.visible)
  }

  func showBody() {
    _lineLayerBody?.visibility = .constant(.visible)
  }

  func showTail() {
    _lineLayerTail?.visibility = .constant(.visible)
  }

  func hidePathfinding() {
    hideHead()
    hideBody()
    hideTail()
  }

  func hideHead() {
    _lineLayerHead?.visibility = .constant(.none)
  }

  func hideBody() {
    _lineLayerBody?.visibility = .constant(.none)
  }

  func hideTail() {
    _lineLayerTail?.visibility = .constant(.none)
  }

  func hasGoal() -> Bool {
    pathfinder?.hasGoal.value ?? false
  }

  func updateLocation(newLocation: CGPoint) {
    pathfinder?.setUserPosition(position: newLocation.fromMeterToPixel(converter: converter).flipY(converter: converter))
  }

  func forceRefresh(withTSP: Bool, overridePosition: CGPoint?, completion: @escaping (() -> Void)) {
    pathfinder?.forceRefresh(withTSP: withTSP, overridePosition: overridePosition, completion: completion)
  }
}

