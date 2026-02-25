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
    targets: [
        .target(
            name: "AgentLaunchCore"
        ),
        .executableTarget(
            name: "AIAgentLaunch",
            dependencies: ["AgentLaunchCore"]
        ),
        .testTarget(
            name: "AgentLaunchCoreTests",
            dependencies: ["AgentLaunchCore"]
        )
    ]
)
