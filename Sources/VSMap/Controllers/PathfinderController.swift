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

  private var allGoals: [String : PathfindingGoal] = [:]
  private var currentHeadPath: [CLLocationCoordinate2D] = []
  private var currentBodyPath: [CLLocationCoordinate2D] = []
  private var currentTailPath: [CLLocationCoordinate2D] = []

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

  var pathfinder: IPathfinder? {
    didSet {
      bindPublishers()
    }
  }

  var style: Style { mapRepository.style }
  var converter: ICoordinateConverter { mapRepository.mapData.converter }
  var mapOptions: VSFoundation.MapOptions { mapRepository.mapOptions }
  var pathfindingStyle: VSFoundation.MapOptions.PathfindingStyle { mapOptions.pathfindingStyle }
  var floorLevelId: Int64 { mapRepository.floorLevelId }
  var latestRefreshLines: Date = Date()

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
    guard _lineSourceHead == nil else { return }

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

  func onNewPosition(position: CGPoint) {
    updateLocation(newLocation: position)
    guard Date().timeIntervalSince(latestRefreshLines) > 0.5, currentPosition != position else { return }
    currentPosition = position
    refreshLines(body: false, tail: false)
  }

  var currentPosition: CGPoint?
  var currentCoordinate: CLLocationCoordinate2D? { currentPosition?.convertFromMeterToLatLng(converter: converter) }
  private func refreshLines(head: Bool = true, body: Bool = true, tail: Bool = true) {
    DispatchQueue.main.async { [self] in
      guard !allGoals.isEmpty else {
        try? style.updateGeoJSONSource(withId: SOURCE_ID_HEAD, geoJSON: .geometry(.lineString(LineString([]))))
        try? style.updateGeoJSONSource(withId: SOURCE_ID_BODY, geoJSON: .geometry(.lineString(LineString([]))))
        try? style.updateGeoJSONSource(withId: SOURCE_ID_TAIL, geoJSON: .geometry(.lineString(LineString([]))))
        try? style.updateGeoJSONSource(withId: SOURCE_ID_END, geoJSON: .geometry(.point(Point(CLLocationCoordinate2D(latitude: 0, longitude: 0)))))
        return
      }

      latestRefreshLines = Date()
      if head {
        let path = slice(path: currentHeadPath, coordinate: currentCoordinate) ?? currentHeadPath
        //if let distance = distance(in: path) {
        //  print("DISTANCE", currentCoordinate?.fromLatLngToMeter(converter: converter).distance(to: path.last!.fromLatLngToMeter(converter: converter)), distance)
        //}
        try? style.updateGeoJSONSource(withId: SOURCE_ID_HEAD, geoJSON: .geometry(.lineString(LineString(path))))
        if let coordinate = currentHeadPath.last {
          try? style.updateGeoJSONSource(withId: SOURCE_ID_END, geoJSON: .geometry(.point(Point(coordinate))))
        }
      }

      if body, mapOptions.pathfindingStyle.showPathfindingBody {
        try? style.updateGeoJSONSource(withId: SOURCE_ID_BODY, geoJSON: .geometry(.lineString(LineString(currentBodyPath))))
      }

      if tail, mapOptions.pathfindingStyle.showPathfindingTail {
        try? style.updateGeoJSONSource(withId: SOURCE_ID_TAIL, geoJSON: .geometry(.lineString(LineString(currentTailPath))))
      }
    }
  }

  func slice(path: [CLLocationCoordinate2D], coordinate: CLLocationCoordinate2D?) -> [CLLocationCoordinate2D]? {
    LineString(path).sliced(from: coordinate)?.coordinates
  }

  func distance(in path: [CLLocationCoordinate2D]) -> Double {
    guard path.count > 1 else { return 0 }
    var distance: Double = 0.0
    let convertedPath = path.map({ $0.fromLatLngToMeter(converter: converter) })
    for i in 0...convertedPath.count - 2 {
      distance += convertedPath[i].distance(to: convertedPath[i+1])
    }
    return distance
  }

  func bindPublishers() {
    pathfinder?.currentGoalUpdatedPublisher
      .compactMap { $0 }
      .sink(receiveValue: { [weak self] (goal) in
        self?._onCurrentGoalChangePublisher.send(goal.asGoal)
      }).store(in: &cancellable)

    pathfinder?.sortedGoalUpdatedPublisher
      .compactMap { $0 }
      .sink(receiveValue: { [weak self] (goals) in
        self?._onSortedGoalChangePublisher.send(goals.map { $0.asGoal })
      }).store(in: &cancellable)

    pathfinder?.pathUpdatedPublisher
      .compactMap { $0 }
      .sink(receiveValue: { [weak self] (path) in
        guard let converter = self?.converter else { return }
        let modified = path.convertFromPixelToMapCoordinate(converter: converter)
        self?.currentHeadPath = modified.head
        self?.currentBodyPath = modified.body
        self?.currentTailPath = modified.tail
      }).store(in: &cancellable)

//    pathfinder?.hasGoal
//      .sink(receiveValue: { [weak self] (hasGoal) in
//
//      }).store(in: &cancellable)
  }

  func onStyleUpdated() {
    initSources()

    try? style.addSource(lineSourceHead, id: SOURCE_ID_HEAD)
    try? style.addLayer(lineLayerHead, layerPosition: LayerPosition.below("marker-layer"))

    try? style.addSource(lineSourceBody, id: SOURCE_ID_BODY)
    try? style.addLayer(lineLayerBody, layerPosition: LayerPosition.below(LAYER_ID_HEAD))

    try? style.addSource(lineSourceTail, id: SOURCE_ID_TAIL)
    try? style.addLayer(lineLayerTail, layerPosition: LayerPosition.below(LAYER_ID_BODY))

    try? style.addSource(lineSourceEnd, id: SOURCE_ID_END)
    //try? style.addLayer(circleLayerEnd, layerPosition: LayerPosition.above(LAYER_ID_HEAD))
  }

  deinit {
    cancellable.removeAll()
  }

  private func checkIfSwaplocationIsNeeded(goal: PathfindingGoal)  {

  }
}

extension PathfinderController: IPathfinderController {
  var state: State { .hidden }

  var onCurrentGoalChangePublisher: CurrentValueSubject<PathfindingGoal?, Never> { _onCurrentGoalChangePublisher }
  var onSortedGoalChangePublisher: CurrentValueSubject<[PathfindingGoal], Never> { _onSortedGoalChangePublisher }
  
  var currentGoal: PathfindingGoal? { onCurrentGoalChangePublisher.value }
  var sortedGoals: [PathfindingGoal] { onSortedGoalChangePublisher.value }

  func add(goal: PathfindingGoal, completion: @escaping (() -> Void)) {
    allGoals[goal.id] = goal
    filterAndSetGoals(completion: completion)
  }

  func add(goals: [PathfindingGoal], completion: @escaping (() -> Void)) {
    goals.forEach { allGoals[$0.id] = $0 }
    filterAndSetGoals(completion: completion)
  }

  func set(goals: [PathfindingGoal], completion: @escaping (() -> Void)) {
    allGoals.removeAll()
    goals.forEach { allGoals[$0.id] = $0 }
    filterAndSetGoals(completion: completion)
  }

  private func filterAndSetGoals(completion: @escaping (() -> Void)) {
    let goals = filterGoals(forFloorLevel: false)
    var filteredGoals = filterGoals()
    goals.forEach { goal in
      guard let floorLevelId = goal.floorLevelId else { return }
      if floorLevelId != mapRepository.floorLevelId {
        guard let swapLocation = mapRepository.swapLocations[self.floorLevelId]?.first, let name = swapLocation.name, filteredGoals.contains(where: { $0.id.contains(name) }) else { return }
        filteredGoals.append(swapLocation.point.asGoal(floorLevelId: self.floorLevelId))
      }
    }

    pathfinder?.set(goals: filteredGoals.map { $0.asGoal.convertFromMeterToPixel(converter: converter) }) {
      self.refreshLines()
      completion()
    }
  }

  private func filterGoals(forFloorLevel: Bool = true) -> [PathfindingGoal] {
    let goals: [PathfindingGoal] = allGoals.values.map { $0 }
    if forFloorLevel {
      return goals.filter { $0.floorLevelId == floorLevelId }
    } else {
      return goals
    }
  }

  func remove(id: String, completion: @escaping (() -> Void)) {
    pathfinder?.remove(id: id, completion: {
      self.refreshLines()
      completion()
    })
  }

  func remove(ids: [String], completion: @escaping () -> Void) {
    pathfinder?.remove(ids: ids, completion: {
      self.refreshLines()
      completion()
    })
  }

  func remove(goal: PathfindingGoal, completion: @escaping (() -> Void)) {
    remove(id: goal.id, completion: completion)
  }

  func remove(goals: [PathfindingGoal], completion: @escaping (() -> Void)) {
    remove(ids: goals.map({ $0.id }), completion: completion)
  }

  func removeAll(completion: @escaping () -> Void) {
    pathfinder?.set(goals: [], completion: {
      self.refreshLines()
      completion()
    })
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
    try? style.updateLayer(withId: LAYER_ID_HEAD, type: LineLayer.self) { $0.visibility = .constant(.visible) }
  }

  func showBody() {
    try? style.updateLayer(withId: LAYER_ID_BODY, type: LineLayer.self) { $0.visibility = .constant(.visible) }
  }

  func showTail() {
    try? style.updateLayer(withId: LAYER_ID_TAIL, type: LineLayer.self) { $0.visibility = .constant(.visible) }
  }

  func hidePathfinding() {
    hideHead()
    hideBody()
    hideTail()
  }

  func hideHead() {
    try? style.updateLayer(withId: LAYER_ID_HEAD, type: LineLayer.self) { $0.visibility = .constant(.none) }
  }

  func hideBody() {
    try? style.updateLayer(withId: LAYER_ID_BODY, type: LineLayer.self) { $0.visibility = .constant(.none) }
  }

  func hideTail() {
    try? style.updateLayer(withId: LAYER_ID_TAIL, type: LineLayer.self) { $0.visibility = .constant(.none) }
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

extension SwapLocation.Point {
  func asGoal(floorLevelId: Int64) -> PathfindingGoal {
    PathfindingGoal(id: "SwapLocation-\(name ?? "")", position: coordinate, data: self, type: .target, floorLevelId: floorLevelId)
  }
}
