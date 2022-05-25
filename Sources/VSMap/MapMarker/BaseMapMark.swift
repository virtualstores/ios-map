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
  public var offset: CGVector
  public var floorLevelId: Int64?
  public var triggerRadius: Double?
  public var data: Any?
  public var clusterable: Bool
  public var deletable: Bool
  public var defaultVisibility: Bool
  public var focused: Bool

  public var text: String?
  public var imageUrl: String?

  public init(
    id: String,
    position: CGPoint,
    offset: CGVector,
    floorLevelId: Int64? = nil,
    triggerRadius: Double? = nil,
    data: Any? = nil,
    clusterable: Bool,
    deletable: Bool,
    defaultVisibility: Bool,
    focused: Bool,
    text: String?,
    imageUrl: String?
  ) {
    self.id = id
    self.position = position
    self.offset = offset
    self.floorLevelId = floorLevelId
    self.triggerRadius = triggerRadius
    self.data = data
    self.clusterable = clusterable
    self.deletable = deletable
    self.defaultVisibility = defaultVisibility
    self.focused = focused
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
    guard let view = MarkerView.loadNib(for: MarkerView.self, bundle: .module) else { return }

    if let imageUrl = imageUrl/*, !imageUrl.isEmpty*/ {
      view.imageView.load(url: imageUrl) { _ in
        completion(view.asImage())
      }
    } else {
      view.label.text = text ?? id
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
          self?.image = UIImage(named: "no_image_available", in: .module, with: nil)
          completion(error)
        }
      }
    }
  }

  func load(url: String, completion: @escaping (Error?) -> Void = { (_) in }) {
    if let url = URL(string: url) {
      self.load(url: url) { (error) in
        completion(error)
      }
    } else {
      self.image = UIImage(named: "no_image_available", in: .module, with: nil)
      completion(nil)
    }
  }
}
