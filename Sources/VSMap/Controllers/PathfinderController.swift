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
import Turf

class PathfinderController: Disposable {
  let tag = "PathfinderController"
  let SOURCE_ID_HEAD = "pathfinding-source-head"
  let SOURCE_ID_BODY = "pathfinding-source-body"
  let SOURCE_ID_TAIL = "pathfinding-source-tail"
  let SOURCE_ID_END = "end-source"

  let LAYER_ID_HEAD = "pathfinding-head"
  let LAYER_ID_BODY = "pathfinding-body"
  let LAYER_ID_TAIL = "pathfinding-tail"
  let LAYER_ID_END = "pathfinding-end"

  private let PROP_VISIBLE = "mark_visible"

  @Inject var mapRepository: MapRepository
  private var cancellable = Set<AnyCancellable>()

  private var _onCurrentGoalChangePublisher: CurrentValueSubject<PathfindingGoal?, Never> = .init(nil)
  private var _onGoalsUpdatedPublisher: CurrentValueSubject<[PathfindingGoal]?, Never> = .init(nil)
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

//  var style: Style { mapRepository.style }
  var converter: ICoordinateConverter { mapRepository.mapData.converter }
  var mapOptions: VSFoundation.MapOptions { mapRepository.mapOptions }
  var pathfindingStyle: VSFoundation.MapOptions.PathfindingStyle { mapOptions.pathfindingStyle }
  var floorLevelId: Int64 { mapRepository.floorLevelId }
  var latestRefreshLines: Date = Date()

  deinit {
    Logger(verbosity: .info).log(tag: tag, message: "deinit")
    dispose()
  }

  func dispose() {
    Logger(verbosity: .info).log(tag: tag, message: "dispose")
    cancellable.removeAll()
    pathfinder = nil
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

    _lineSourceHead = GeoJSONSource(id: SOURCE_ID_HEAD)
    _lineSourceBody = GeoJSONSource(id: SOURCE_ID_BODY)
    _lineSourceTail = GeoJSONSource(id: SOURCE_ID_TAIL)
    _lineSourceEnd = GeoJSONSource(id: SOURCE_ID_END)

    _lineLayerHead = LineLayer(id: LAYER_ID_HEAD, source: lineSourceHead.id)
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

    _lineLayerBody = LineLayer(id: LAYER_ID_BODY, source: lineSourceBody.id)
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

    _lineLayerTail = LineLayer(id: LAYER_ID_TAIL, source: lineSourceTail.id)
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

    _circleLayerEnd = CircleLayer(id: LAYER_ID_END, source: lineSourceEnd.id)
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

  func onNewPosition(position: CGPoint, std: Double) {
    updateLocation(newLocation: position)
    guard
      !allGoals.isEmpty,
      Date().timeIntervalSince(latestRefreshLines) > 0.5,
      currentPosition != position
    else { return }
    currentPosition = position
    self.std = max(1.5, min(5.0, std * 1.645))
    refreshLines(body: false, tail: false)
  }

  var currentPosition: CGPoint?
  var std: Double = 1.5
  var currentCoordinate: CLLocationCoordinate2D? { currentPosition?.convertFromMeterToLatLng(converter: converter) }
  private func refreshLines(head: Bool = true, body: Bool = true, tail: Bool = true) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      guard !allGoals.isEmpty else {
        mapRepository.map.updateGeoJSONSource(withId: SOURCE_ID_HEAD, geoJSON: .geometry(.lineString(LineString([]))))
        mapRepository.map.updateGeoJSONSource(withId: SOURCE_ID_BODY, geoJSON: .geometry(.lineString(LineString([]))))
        mapRepository.map.updateGeoJSONSource(withId: SOURCE_ID_TAIL, geoJSON: .geometry(.lineString(LineString([]))))
        mapRepository.map.updateGeoJSONSource(withId: SOURCE_ID_END, geoJSON: .geometry(.point(Point(CLLocationCoordinate2D(latitude: 0, longitude: 0)))))
        return
      }

      latestRefreshLines = Date()
      if head {
        var path = slice(path: currentHeadPath, coordinate: currentCoordinate) ?? currentHeadPath
        if path.count > 4 {
          path.removeLast(4)
        }
        //if let distance = distance(in: path) {
        //  print("DISTANCE", currentCoordinate?.fromLatLngToMeter(converter: converter).distance(to: path.last!.fromLatLngToMeter(converter: converter)), distance)
        //}
        mapRepository.map.updateGeoJSONSource(withId: SOURCE_ID_HEAD, geoJSON: .geometry(.lineString(LineString(path))))
        if let coordinate = currentHeadPath.last {
          mapRepository.map.updateGeoJSONSource(withId: SOURCE_ID_END, geoJSON: .geometry(.point(Point(coordinate))))
        }
      }

      if body, mapOptions.pathfindingStyle.showPathfindingBody {
        mapRepository.map.updateGeoJSONSource(withId: SOURCE_ID_BODY, geoJSON: .geometry(.lineString(LineString(currentBodyPath))))
      }

      if tail, mapOptions.pathfindingStyle.showPathfindingTail {
        mapRepository.map.updateGeoJSONSource(withId: SOURCE_ID_TAIL, geoJSON: .geometry(.lineString(LineString(currentTailPath))))
      }
    }
  }

  func slice(path: [CLLocationCoordinate2D], coordinate: CLLocationCoordinate2D?) -> [CLLocationCoordinate2D]? {
    LineString(path).sliced(from: coordinate)?.coordinates
  }

  func slice2(path: [CLLocationCoordinate2D], coordinate: CLLocationCoordinate2D?) -> [CLLocationCoordinate2D]? {
    var slicedPath = LineString(path).sliced(from: coordinate)?.coordinates

    guard slicedPath?.count ?? 0 > 4 else { return slicedPath }
    slicedPath = slicedPath?.dropFirst(2).map({ $0 })
    guard
      let slicedPath = slicedPath,
      let meterCoordinate = coordinate?.fromLatLngToMeter(converter: converter)
    else { return slicedPath }
    let meterPath = slicedPath.map({ $0.fromLatLngToMeter(converter: converter) })
    let meterScaleUserPositionRadius = CGFloat(std)

    let angle = atan2(
      (meterPath[0].y - meterCoordinate.y),
      (meterPath[0].x - meterCoordinate.x)
    )

    let meterScalePointOnCircle = CGPoint(
      x: meterScaleUserPositionRadius * cos(angle) + meterCoordinate.x,
      y: meterScaleUserPositionRadius * sin(angle) + meterCoordinate.y
    )

    let latLngPointOnCircle = meterScalePointOnCircle.convertFromMeterToLatLng(converter: converter)

    return LineString(slicedPath).sliced(from: latLngPointOnCircle)?.coordinates
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

    pathfinder?.goalsUpdatedPublisher
      .compactMap { $0 }
      .sink(receiveValue: { [weak self] (goals) in
        self?._onGoalsUpdatedPublisher.send(goals.map { $0.asGoal })
      }).store(in: &cancellable)

    pathfinder?.sortedGoalUpdatedPublisher
      .compactMap { $0 }
      .sink(receiveValue: { [weak self] (goals) in
        self?._onSortedGoalChangePublisher.send(goals.map { $0.asGoal })
      }).store(in: &cancellable)

    pathfinder?.pathUpdatedPublisher
      //.compactMap { $0 }
      .sink(receiveValue: { [weak self] (path) in
        guard let self = self else { return }
        guard let modified = path?.convertFromPixelToMapCoordinate(converter: converter) else { return }
        let shouldUpdate = currentHeadPath != modified.head || currentBodyPath != modified.body
        currentHeadPath = modified.head
        currentBodyPath = modified.body
        currentTailPath = modified.tail
        if shouldUpdate {
          refreshLines()
        }
      }).store(in: &cancellable)

//    pathfinder?.hasGoal
//      .sink(receiveValue: { [weak self] (hasGoal) in
//
//      }).store(in: &cancellable)
  }

  func onStyleUpdated() {
    initSources()

    try? mapRepository.map.addSource(lineSourceHead)
    try? mapRepository.map.addLayer(lineLayerHead, layerPosition: LayerPosition.below("text-layer copy"))
    try? mapRepository.map.addLayer(lineLayerHead, layerPosition: LayerPosition.below("text-layer"))
    try? mapRepository.map.addLayer(lineLayerHead, layerPosition: LayerPosition.below("marker-layer"))

    try? mapRepository.map.addSource(lineSourceBody)
    try? mapRepository.map.addLayer(lineLayerBody, layerPosition: LayerPosition.below(LAYER_ID_HEAD))

    try? mapRepository.map.addSource(lineSourceTail)
    try? mapRepository.map.addLayer(lineLayerTail, layerPosition: LayerPosition.below(LAYER_ID_BODY))

    try? mapRepository.map.addSource(lineSourceEnd)
    //try? mapRepository.map.addLayer(circleLayerEnd, layerPosition: LayerPosition.above(LAYER_ID_HEAD))
  }

  private func checkIfSwaplocationIsNeeded(goal: PathfindingGoal)  {

  }

  func reset() {
    currentHeadPath.removeAll()
    currentBodyPath.removeAll()
    currentTailPath.removeAll()
    pathfinder?.set(goals: [], completion: nil)
    pathfinder?.setUserPosition(position: nil)
  }
}

extension PathfinderController: IPathfinderController {
  var state: State { .hidden }

  var onCurrentGoalChangePublisher: CurrentValueSubject<PathfindingGoal?, Never> { _onCurrentGoalChangePublisher }
  var onGoalsUpdatedPublisher: CurrentValueSubject<[PathfindingGoal]?, Never> { _onGoalsUpdatedPublisher }
  var onSortedGoalChangePublisher: CurrentValueSubject<[PathfindingGoal], Never> { _onSortedGoalChangePublisher }
  
  var currentGoal: PathfindingGoal? { onCurrentGoalChangePublisher.value }
  var sortedGoals: [PathfindingGoal] { onSortedGoalChangePublisher.value }

  func add(goal: PathfindingGoal, completion: (() -> ())?) {
    allGoals[goal.id] = goal
    filterAndSetGoals(completion: completion)
  }

  func add(goals: [PathfindingGoal], completion: (() -> ())?) {
    goals.forEach { allGoals[$0.id] = $0 }
    filterAndSetGoals(completion: completion)
  }

  func set(goals: [PathfindingGoal], completion: (() -> ())?) {
    allGoals.removeAll()
    goals.forEach { allGoals[$0.id] = $0 }
    filterAndSetGoals(completion: completion)
  }

  private func filterAndSetGoals(completion: (() -> ())?) {
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
      completion?()
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

  func remove(id: String, completion: (() -> ())?) {
    allGoals.removeValue(forKey: id)
    pathfinder?.remove(id: id, completion: {
      self.refreshLines()
      completion?()
    })
  }

  func remove(ids: [String], completion: (() -> ())?) {
    ids.forEach { allGoals.removeValue(forKey: $0) }
    pathfinder?.remove(ids: ids, completion: {
      self.refreshLines()
      completion?()
    })
  }

  func remove(goal: PathfindingGoal, completion: (() -> ())?) {
    remove(id: goal.id, completion: completion)
  }

  func remove(goals: [PathfindingGoal], completion: (() -> ())?) {
    remove(ids: goals.map({ $0.id }), completion: completion)
  }

  func removeAll(completion: (() -> ())?) {
    allGoals.removeAll()
    pathfinder?.set(goals: [], completion: {
      self.refreshLines()
      completion?()
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
    try? mapRepository.map.updateLayer(withId: LAYER_ID_HEAD, type: LineLayer.self) { $0.visibility = .constant(.visible) }
  }

  func showBody() {
    try? mapRepository.map.updateLayer(withId: LAYER_ID_BODY, type: LineLayer.self) { $0.visibility = .constant(.visible) }
  }

  func showTail() {
    try? mapRepository.map.updateLayer(withId: LAYER_ID_TAIL, type: LineLayer.self) { $0.visibility = .constant(.visible) }
  }

  func hidePathfinding() {
    hideHead()
    hideBody()
    hideTail()
  }

  func hideHead() {
    try? mapRepository.map.updateLayer(withId: LAYER_ID_HEAD, type: LineLayer.self) { $0.visibility = .constant(.none) }
  }

  func hideBody() {
    try? mapRepository.map.updateLayer(withId: LAYER_ID_BODY, type: LineLayer.self) { $0.visibility = .constant(.none) }
  }

  func hideTail() {
    try? mapRepository.map.updateLayer(withId: LAYER_ID_TAIL, type: LineLayer.self) { $0.visibility = .constant(.none) }
  }

  func hasGoal() -> Bool {
    pathfinder?.hasGoal ?? false
  }

  func updateLocation(newLocation: CGPoint) {
    pathfinder?.setUserPosition(position: newLocation.fromMeterToPixel(converter: converter).flipY(converter: converter))
  }

  func forceRefresh(withTSP: Bool, overridePosition: CGPoint?, completion: (() -> ())?) {
    pathfinder?.forceRefresh(withTSP: withTSP, overridePosition: overridePosition, completion: completion)
  }
}

extension SwapLocation.Point {
  func asGoal(floorLevelId: Int64) -> PathfindingGoal {
    PathfindingGoal(id: "SwapLocation-\(name ?? "")", position: coordinate, data: self, type: .target, floorLevelId: floorLevelId)
  }
}
