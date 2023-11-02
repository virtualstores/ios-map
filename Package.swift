// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VSMap",
    platforms: [
      .iOS(.v13),
      .macOS(.v11),
      .watchOS(.v6)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "VSMap",
            targets: ["VSMap"]),
    ],
    dependencies: [
        .package(url: "https://github.com/virtualstores/ios-foundation.git", .exact("1.0.3")),
        .package(url: "https://github.com/mapbox/mapbox-maps-ios.git", .exact("10.14.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "VSMap",
            dependencies: [
                .product(name: "VSFoundation", package: "ios-foundation"),
                .product(name: "MapboxMaps", package: "mapbox-maps-ios"),]),
        .testTarget(
            name: "VSMapTests",
            dependencies: ["VSMap"]),
    ]
) 
