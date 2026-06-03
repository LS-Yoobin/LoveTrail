// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GardenCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "GardenCore", targets: ["GardenCore"]),
    ],
    targets: [
        .target(name: "GardenCore"),
        .testTarget(name: "GardenCoreTests", dependencies: ["GardenCore"]),
    ]
)
