// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AIAgentLaunch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AgentLaunchCore",
            targets: ["AgentLaunchCore"]
        ),
        .executable(
            name: "AIAgentLaunch",
            targets: ["AIAgentLaunch"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0")
    ],
    targets: [
        .target(
            name: "AgentLaunchCore"
        ),
        .executableTarget(
            name: "AIAgentLaunch",
            dependencies: [
                "AgentLaunchCore",
                .product(name: "Sparkle", package: "Sparkle")
            ]
        ),
        .testTarget(
            name: "AgentLaunchCoreTests",
            dependencies: ["AgentLaunchCore"]
        )
    ]
)
