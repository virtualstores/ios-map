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
  public let id: String
  public let position: CGPoint
  public let offset: CGVector = .zero
  public let floorLevelId: Int64?
  public let triggerRadius: Double?
  public let data: Any?
  public let clusterable: Bool
  public let defaultVisibility: Bool
  public let focused: Bool

  public let type: MapMarkType
  public var itemPosition: ItemPosition?
  public var scale: Double = 1.0
  public var alpha: Double = 1.0

  public enum MapMarkType {
    case imageUrl(String)
    case text(String)
  }

  public init(
    id: String,
    position: CGPoint,
    floorLevelId: Int64,
    triggerRadius: Double? = nil,
    data: Any? = nil,
    clusterable: Bool,
    defaultVisibility: Bool,
    focused: Bool,
    type: MapMarkType
  ) {
    self.id = id
    self.position = position
    self.floorLevelId = floorLevelId
    self.triggerRadius = triggerRadius
    self.data = data
    self.clusterable = clusterable
    self.defaultVisibility = defaultVisibility
    self.focused = focused
    self.type = type
  }

  public init(
    id: String,
    itemPosition: ItemPosition,
    triggerRadius: Double? = nil,
    data: Any? = nil,
    clusterable: Bool,
    defaultVisibility: Bool,
    focused: Bool,
    type: MapMarkType
  ) {
    self.id = id
    self.position = itemPosition.point
    self.floorLevelId = itemPosition.floorLevelId
    self.itemPosition = itemPosition
    self.triggerRadius = triggerRadius
    self.data = data
    self.clusterable = clusterable
    self.defaultVisibility = defaultVisibility
    self.focused = focused
    self.type = type
  }

  public func createViewHolder(completion: @escaping (MapMarkViewHolder) -> ()) {
    let marker =  MapMarkViewHolder(id: id)

    createMarker { (image) in
      marker.renderedBitmap = image
      completion(marker)
    }
  }

  private func createMarker(completion: @escaping (UIImage) -> Void) {
    guard let view = MarkerView.loadNib(for: MarkerView.self, bundle: .module) else { return }

    switch type {
    case .imageUrl(let url):
      view.imageView.load(url: url) { [self] _ in
        let image = view.asImage()
        let scale = image.size * self.scale
        completion(image.alpha(alpha).resizeImage(targetSize: scale))
      }
    case .text(let text):
      view.label.text = text
      let image = view.asImage()
      let scale = image.size * self.scale
      completion(image.alpha(alpha).resizeImage(targetSize: scale))
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

extension UIImage {
  func alpha(_ value:CGFloat) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(size, false, scale)
    draw(at: CGPoint.zero, blendMode: .normal, alpha: value)
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return newImage!
  }

  func resizeImage(targetSize: CGSize) -> UIImage {
    let size = size

    let widthRatio  = targetSize.width  / size.width
    let heightRatio = targetSize.height / size.height

    // Figure out what our orientation is, and use that to form the rectangle
    let newSize: CGSize
    if(widthRatio > heightRatio) {
      newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
    } else {
      newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
    }

    // This is the rect that we've calculated out and this is what is actually used below
    let rect = CGRect(origin: .zero, size: newSize)

    // Actually do the resizing to the rect using the ImageContext stuff
    UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
    draw(in: rect)
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return newImage!
  }
}

extension CGSize {
  static func * (lhs: CGSize, rhs: Double) -> CGSize {
    CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
  }
}
