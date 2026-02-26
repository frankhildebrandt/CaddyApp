// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CaddyApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CaddyApp", targets: ["CaddyApp"])
    ],
    targets: [
        .executableTarget(
            name: "CaddyApp",
            path: "Sources/CaddyApp"
        )
    ]
)
