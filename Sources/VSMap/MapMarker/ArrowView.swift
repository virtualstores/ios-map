//
//  ArrowView.swift
//  VSMap
//
//  Created by Théodore Roos on 2025-03-12.
//

import UIKit

final class ArrowView: UIView {
  @IBOutlet var imageView: UIImageView!
  func changeImage(to type: String) {
    switch type {
    case "up": imageView.image = UIImage(systemName: "arrowshape.up.fill")
    case "down": imageView.image = UIImage(systemName: "arrowshape.down.fill")
    case "right": imageView.image = UIImage(systemName: "arrowshape.right.fill")
    case "left": imageView.image = UIImage(systemName: "arrowshape.left.fill")
    default: break
    }
  }
}
