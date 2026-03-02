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
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.0.1")
    ],
    targets: [
        .executableTarget(
            name: "CaddyApp",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ],
            path: "Sources/CaddyApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CaddyAppTests",
            dependencies: [
                "CaddyApp"
            ]
        )
    ]
)
