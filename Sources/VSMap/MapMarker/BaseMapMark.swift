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
  public var itemPosition: ItemPosition
  public var triggerRadius: Double?
  public var data: Any?
  public var clusterable: Bool
  public var deletable: Bool
  public var defaultVisibility: Bool
  public var focused: Bool
  public var scale: Double = 1.0

  public var text: String?
  public var imageUrl: String?

  public var position: CGPoint { itemPosition.point }
  public var offset: CGVector { itemPosition.offset }
  public var floorLevelId: Int64 { itemPosition.floorLevelId }

  public init(
    id: String,
    itemPosition: ItemPosition,
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
    self.itemPosition = itemPosition
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
//        completion(view.asImage().resizeImage(scale: self.scale))
        let image = view.asImage()
        completion(image.resizeImage(targetSize: image.size * self.scale))
      }
    } else {
      view.label.text = text ?? id
      let image = view.asImage()
      completion(image.resizeImage(targetSize: image.size * self.scale))
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
