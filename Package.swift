// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ios-map",
    platforms: [
      .iOS(.v13),
      .macOS(.v11),
      .watchOS(.v6)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ios-map",
            targets: ["ios-map"]),
    ],
    dependencies: [
        .package(url: "https://github.com/virtualstores/ios-foundation.git", .branch("develop")),
        .package(url: "https://github.com/mapbox/mapbox-maps-ios.git", .exact("10.2.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "ios-map",
            dependencies: [
                .product(name: "VSFoundation", package: "ios-foundation"),
                .product(name: "MapboxMaps", package: "mapbox-maps-ios"),]),
        .testTarget(
            name: "ios-mapTests",
            dependencies: ["ios-map"]),
    ]
) 
