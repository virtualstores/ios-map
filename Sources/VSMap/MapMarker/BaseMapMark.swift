//
// BaseMapMark.swift
// VSMap
//
// Created by Hripsime on 2022-02-18.
// Copyright (c) 2022 Virtual Stores

import Foundation
import VSFoundation
import CoreGraphics
import UIKit

public class BaseMapMark: MapMark {
  public var id: String
  public var position: CGPoint
  public var floorLevelId: Int64?
  public var triggerRadius: Double?
  public var data: Any?
  public var clusterable: Bool
  public var deletable: Bool
  public var defaultVisibility: Bool
  public var focused: Bool
  public var offsetX: Double
  public var offsetY: Double

  public var text: String?
  public var imageUrl: String?

  public init(
    id: String,
    position: CGPoint,
    floorLevelId: Int64?,
    triggerRadius: Double?,
    data: UIImage?,
    clusterable: Bool,
    deletable: Bool,
    defaultVisibility: Bool,
    focused: Bool,
    offsetX: Double,
    offsetY: Double,
    text: String?,
    imageUrl: String?
  ) {
    self.id = id
    self.position = position
    self.floorLevelId = floorLevelId
    self.triggerRadius = triggerRadius
    self.data = data
    self.clusterable = clusterable
    self.deletable = deletable
    self.defaultVisibility = defaultVisibility
    self.focused = focused
    self.offsetY = offsetY
    self.offsetX = offsetX
    self.text = text
    self.imageUrl = imageUrl
  }

  public func createViewHolder(completion: @escaping (MapMarkViewHolder) -> ()) {
    let marker =  MapMarkViewHolder(id: self.id)

    createMarker { (image) in
      marker.renderedBitmap = image
      completion(marker)
    }
  }

  private func createMarker(completion: @escaping (UIImage) -> Void) {
    let view = MarkerView.loadNib(for: MarkerView.self, bundle: Bundle.module)
    let id = Bundle.module.path(forResource: "MarkerView", ofType: "nib")
    let bundle = Bundle(identifier: id ?? "")

    guard let view = view else {
      return
    }

    if let imageUrl = imageUrl {
      view.imageView.load(url: imageUrl) { _ in
        completion(view.asImage())
      }
    } else {
      view.label.text = text
      completion(view.asImage())
    }
  }
}

extension UIImageView {
  func load(url: URL, completion: @escaping (Error?) -> Void = { (_) in }) {
    DispatchQueue.global().async { [weak self] in
      do {
        let data = try Data(contentsOf: url)
        if let image = UIImage(data: data) {
          DispatchQueue.main.async {
            self?.image = image
            completion(nil)
          }
        }
      } catch {
        print(#function, error.localizedDescription)
        DispatchQueue.main.async {
          self?.image = UIImage(named: "no_image_available")
        }
        completion(error)
      }
    }
  }

  func load(url: String, completion: @escaping (Error?) -> Void = { (_) in }) {
    if let url = URL(string: url) {
      self.load(url: url) { (error) in
        completion(error)
      }
    }
  }
}
