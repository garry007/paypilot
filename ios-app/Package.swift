// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PayPilot",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PayPilot",
            targets: ["PayPilot"]
        )
    ],
    targets: [
        .target(
            name: "PayPilot",
            path: "Sources/PayPilot"
        ),
        .testTarget(
            name: "PayPilotTests",
            dependencies: ["PayPilot"],
            path: "Tests/PayPilotTests"
        )
    ]
)
