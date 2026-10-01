// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MenuBarKit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "MenuBarKit", targets: ["MenuBarKit"]),
    ],
    targets: [
        .target(name: "MenuBarKit"),
        .testTarget(name: "MenuBarKitTests", dependencies: ["MenuBarKit"]),
    ]
)
