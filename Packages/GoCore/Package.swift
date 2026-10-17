// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GoCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GoCore", targets: ["GoCore"])
    ],
    targets: [
        .target(name: "GoCore"),
        .testTarget(name: "GoCoreTests", dependencies: ["GoCore"])
    ]
)
