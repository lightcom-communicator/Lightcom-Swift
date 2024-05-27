// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Lightcom-Swift",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Lightcom-Swift",
            targets: ["Lightcom-Swift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/aeoliux/hsauth-swift", branch: "main"),
        .package(url: "https://github.com/M3DZIK/swift-libcrypto", branch: "main"),
        .package(url: "https://github.com/apple/swift-crypto.git", .upToNextMajor(from: "3.4.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Lightcom-Swift",
            dependencies: [
                .product(name: "LibCrypto", package: "swift-libcrypto"),
                .product(name: "hsauth-swift", package: "hsauth-swift"),
                .product(name: "Crypto", package: "swift-crypto")
            ]
        ),
        .testTarget(
            name: "Lightcom-SwiftTests",
            dependencies: ["Lightcom-Swift"]),
    ]
)
