// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuickCast",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "quick-cast", targets: ["QuickCast"])],
    targets: [
        .target(name: "QuickCastCore"),
        .executableTarget(name: "QuickCast", dependencies: ["QuickCastCore"]),
        .testTarget(name: "QuickCastCoreTests", dependencies: ["QuickCastCore"])
    ],
    swiftLanguageModes: [.v5]
)
