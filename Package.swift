// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "bclm",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "bclm", targets: ["bclm"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "bclm",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
