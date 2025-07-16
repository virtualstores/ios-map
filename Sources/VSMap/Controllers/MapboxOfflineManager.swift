// MapboxOfflineManager.swift
// Mapbox Offline Maps

// Created by: CJ on 2025-04-30
// Copyright (c) 2025

import MapboxMaps
import VSFoundation

class MapboxOfflineManager {
  private let SOURCE_ID = "offline-area-source"
  private let LAYER_ID = "offline-area-layer"

  @Inject var mapRepository: MapRepository

  private var mapBoxToken: String { mapRepository.map.resourceOptions.accessToken }

  private var _source: GeoJSONSource? = nil
  private var source: GeoJSONSource {
    guard let source = _source else { fatalError("Offline Area Source is not initialized") }

    return source
  }

  private var _layer: LineLayer? = nil
  private var layer: LineLayer {
    guard let layer = _layer else { fatalError("markerLayer is not initialized") }

    return layer
  }

  func initSource() {
    _source = GeoJSONSource()
    _source?.data = .empty

    _layer = LineLayer(id: LAYER_ID)
    _layer?.source = SOURCE_ID
    _layer?.lineColor = .constant(.init(.red))
    _layer?.lineWidth = .constant(2)
  }

  var area = [[[CLLocationCoordinate2D]]]()
  func refreshLines() {
    try? mapRepository.style.updateGeoJSONSource(withId: SOURCE_ID, geoJSON: .feature(.init(geometry: .multiPolygon(.init(area)))))
  }

  private lazy var offlineManager: OfflineManager = {
    OfflineManager.init(resourceOptions: ResourceOptions(accessToken: mapBoxToken))
  }()

  private lazy var tileStore: TileStore = {
    let tileStore = TileStore.default
    tileStore.setOptionForKey(TileStoreOptions.diskQuota, value: NSNull())
    return tileStore
  }()

  private var downloads: [Cancelable] = []

  func downloadTileRegion(
    style: StyleURI,
    region: MapboxDownloadRegion,
    zoomRange: ClosedRange<UInt8>,
    styleProgressHandler: @escaping(Float) -> (),
    tileProgressHandler: @escaping(Float) -> (),
    completionHandler: @escaping(Bool) -> (),
    debugMode: Bool
  ) {
    let group = DispatchGroup()

    var downloadError = false

    // - - - - - - - -

    // 1. Create style package with loadStylePack() call.

    let stylePackLoadOptions = StylePackLoadOptions(
      glyphsRasterizationMode: .ideographsRasterizedLocally,
      metadata: ["stylePack": "stylePackValue"]
    )!

    group.enter()
    if debugMode {
      print("Downloading style pack...")
    }

    let stylePackDownload = offlineManager.loadStylePack(for: style, loadOptions: stylePackLoadOptions) { (progress) in
      // These closures do not get called from the main thread. In this case
      // we're updating the UI, so it's important to dispatch to the main
      // queue.
      DispatchQueue.main.async {
        if debugMode {
          print("StylePack = \(progress)")
        }
        styleProgressHandler(Float(progress.completedResourceCount) / Float(progress.requiredResourceCount))
      }

    } completion: { (result) in
      DispatchQueue.main.async {
        defer {
          group.leave()
        }

        switch result {
        case let .success(stylePack):
          if debugMode {
            print("Success: StylePack = \(stylePack)")
          }

        case let .failure(error):
          if debugMode {
            print("stylePack download Error = \(error)")
          }
          downloadError = true
        }
      }
    }

    if debugMode {
      print("Starting downloading all regions...")
    }

    if debugMode {
      print("Starting download for \(region.regionId)...")
    }

    // 2. Create an offline region with tiles for the Standard or Satellite-Streets style.
    // If you are using a raster tileset you may need to set a different pixelRatio. The default is UIScreen.main.scale.
    let styleOptions = TilesetDescriptorOptions(styleURI: style, zoomRange: zoomRange)

    let styleDescriptor = offlineManager.createTilesetDescriptor(for: styleOptions)


    // Load the tile region
    let tileRegionLoadOptions = TileRegionLoadOptions(
      // .point(Point(region.coordinate))
      geometry: .polygon(Polygon(region.coordinates)),
      descriptors: [styleDescriptor],
      metadata: [region.tileRegionTag: region.tileRegionValue],
      acceptExpired: true)!

    // Use the the default TileStore to load this region. You can create
    // custom TileStores are are unique for a particular file path, i.e.
    // there is only ever one TileStore per unique path.
    group.enter()
    if debugMode {
      print("Downloading tile region for \(region.regionId)...")
    }

    let tileRegionDownload = tileStore.loadTileRegion(forId: region.regionId, loadOptions: tileRegionLoadOptions) { (progress) in
      // These closures do not get called from the main thread. In this case
      // we're updating the UI, so it's important to dispatch to the main
      // queue.
      DispatchQueue.main.async {
        tileProgressHandler(Float(progress.completedResourceCount) / Float(progress.requiredResourceCount))
        if debugMode {
          print("\(region.regionId) TileRegionProgress: \(progress)")
        }
      }
    } completion: { result in
      DispatchQueue.main.async {
        defer {

          group.leave()
        }

        switch result {
        case let .success(tileRegion):
          if debugMode {
            print("\(region.regionId) Success tileRegion = \(tileRegion)")
          }

        case let .failure(error):
          if debugMode {
            print("\(region.regionId) tileRegion download Error = \(error)")
          }
          downloadError = true
        }
      }
    }

    // Wait for both downloads before moving to the next state
    group.notify(queue: .main) {
      if debugMode {
        print("Download completed for all regions... Error = \(downloadError)")
      }
      if !downloadError {
        self.area.append(region.coordinates)
        self.refreshLines()
      }
      completionHandler(downloadError)
    }
    downloads = [stylePackDownload, tileRegionDownload]
  }

  func cancelDownloads() {
    // Canceling will trigger `.canceled` errors that will then change state
    downloads.forEach { $0.cancel() }
  }

  func onStyleUpdated() {
    initSource()

    try? mapRepository.style.addSource(source, id: SOURCE_ID)
    try? mapRepository.style.addLayer(layer, layerPosition: LayerPosition.below("puck"))
    try? mapRepository.style.addLayer(layer, layerPosition: LayerPosition.default)
    hide()
  }
}

extension MapboxOfflineManager: IMapboxOfflineManager {
  func downloadTileRegion(
    region: MapboxDownloadRegion,
    zoomRange: ClosedRange<UInt8> = 1...23,
    styleProgressHandler: @escaping(Float) -> () = {_ in },
    tileProgressHandler: @escaping(Float) -> () = {_ in },
    completionHandler: @escaping(Bool) -> () = {_ in },
    debugMode: Bool = false
  ) {
    downloadTileRegion(
      style: .satellite,
      region: region,
      zoomRange: zoomRange,
      styleProgressHandler: styleProgressHandler,
      tileProgressHandler: tileProgressHandler,
      completionHandler: completionHandler,
      debugMode: debugMode
    )
  }

  func show() {
    try? mapRepository.style.updateLayer(withId: LAYER_ID, type: LineLayer.self) { $0.visibility = .constant(.visible) }
  }

  func hide() {
    try? mapRepository.style.updateLayer(withId: LAYER_ID, type: LineLayer.self) { $0.visibility = .constant(.none) }
  }
}

extension TileRegionLoadProgress {
  public override var description: String {
    "TileRegionLoadProgress: \(completedResourceCount) / \(requiredResourceCount)"
  }
}

extension StylePackLoadProgress {
  public override var description: String {
    "StylePackLoadProgress: \(completedResourceCount) / \(requiredResourceCount)"
  }
}

extension TileRegion {
  public override var description: String {
    "TileRegion \(id): \(completedResourceCount) / \(requiredResourceCount)"
  }
}

extension StylePack {
  public override var description: String {
    "StylePack \(styleURI): \(completedResourceCount) / \(requiredResourceCount)"
  }
}
