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
  public let offset: CGVector
  public let floorLevelId: Int64?
  public let triggerRadius: Double?
  public let data: Any?
  public let clusterable: Bool
  public let defaultVisibility: Bool
  public let focused: Bool
  public let zoneId: String?

  public let type: MapMarkType
  public var itemPosition: ItemPosition?
  public var zonePosition: ZonePosition?
  public var scale: Double = 1.0
  public var alpha: Double = 1.0
  public var backgroundColor: UIColor?

  public enum MapMarkType {
    case arrow
    case imageUrl(String)
    case image(UIImage)
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
    zoneId: String? = nil,
    type: MapMarkType
  ) {
    self.id = id
    self.position = position
    self.offset = .zero
    self.floorLevelId = floorLevelId
    self.triggerRadius = triggerRadius
    self.data = data
    self.clusterable = clusterable
    self.defaultVisibility = defaultVisibility
    self.focused = focused
    self.zoneId = zoneId
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
    self.offset = .zero// itemPosition.offset
    self.floorLevelId = itemPosition.floorLevelId
    self.itemPosition = itemPosition
    self.triggerRadius = triggerRadius
    self.data = data
    self.clusterable = clusterable
    self.defaultVisibility = defaultVisibility
    self.focused = focused
    self.zoneId = nil
    self.type = type
  }

  public init(
    id: String,
    zonePosition: ZonePosition,
    triggerRadius: Double? = nil,
    data: Any? = nil,
    clusterable: Bool,
    defaultVisibility: Bool,
    focused: Bool,
    type: MapMarkType
  ) {
    self.id = id
    self.position = zonePosition.point
    self.offset = .zero
    self.floorLevelId = zonePosition.floorLevelId
    self.zonePosition = zonePosition
    self.triggerRadius = triggerRadius
    self.data = data
    self.clusterable = clusterable
    self.defaultVisibility = defaultVisibility
    self.focused = focused
    self.zoneId = zonePosition.id
    self.type = type
  }

  public func createViewHolder(completion: @escaping (MapMarkViewHolder) -> ()) {
    let marker =  MapMarkViewHolder(id: id)

    createMarker { (image, anchorPoint) in
      marker.renderedBitmap = image
      marker.anchorPoint = anchorPoint
      completion(marker)
    }
  }

  private func createMarker(completion: @escaping (_ image: UIImage, _ anchorPoint: String?) -> Void) {
    guard let view = MarkerView.loadNib(for: MarkerView.self, bundle: .module) else { return }
    if let color = backgroundColor {
      view.backgroundImageView.tintColor = color
    }
    switch type {
    case .arrow:
      let view = ArrowView.loadNib(for: ArrowView.self, bundle: .module) ?? view
      var angle = 0.0
      var anchorPoint: String?
      if let position = itemPosition {
        angle = atan2(-position.offset.dy, -position.offset.dx)
        angle = angle > .pi / 2 ? (.pi - angle) : (.pi / 2 - angle)
        switch angle.radiansToDegrees {
        case 135..., ..<(-180): anchorPoint = "bottom"
        case -135...(-45): anchorPoint = "left"
        case -45...45: anchorPoint = "top"
        case 45...135: anchorPoint = "right"
        default: break
        }
      }
      let image = view
        .asImage()
        .alpha(alpha)
        .rotate(radians: angle)
      completion(image.resizeImage(targetSize: image.size * scale), anchorPoint)
    case .imageUrl(let url):
      view.imageView.load(url: url) { [weak self] (error) in
        guard let self = self else { return }
        if let error = error {
          print("Error loading image for MapMark: \(id)", error)
        }
        let image = view
          .asImage()
          .alpha(alpha)
        completion(image.resizeImage(targetSize: image.size * scale), nil)
      }
    case .image(let image):
      view.imageView.image = image
      let image = view
        .asImage()
        .alpha(alpha)
      completion(image.resizeImage(targetSize: image.size * scale), nil)
    case .text(let text):
      view.label.text = text
      let image = view
        .asImage()
        .alpha(alpha)
      completion(image.resizeImage(targetSize: image.size * scale), nil)
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
      load(url: url, completion: completion)
    } else {
      image = UIImage(named: "no_image_available", in: .module, with: nil)
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

  func rotate(radians: Double) -> UIImage {
    var newSize = CGRect(origin: CGPoint.zero, size: size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
    // Trim off the extremely small float value to prevent core graphics from rounding it up
    newSize.width = floor(newSize.width)
    newSize.height = floor(newSize.height)

    UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
    guard let context = UIGraphicsGetCurrentContext() else { return self }

    // Move origin to middle
    context.translateBy(x: newSize.width/2, y: newSize.height/2)
    // Rotate around middle
    context.rotate(by: CGFloat(radians))
    // Draw the image at its center
    self.draw(in: CGRect(x: -size.width/2, y: -size.height/2, width: size.width, height: size.height))

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
