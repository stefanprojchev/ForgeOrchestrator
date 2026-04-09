// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "ForgeOrchestrator",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "ForgeOrchestrator", targets: ["ForgeOrchestrator"]),
    ],
    dependencies: [
        .package(path: "../ForgeCore"),
    ],
    targets: [
        .target(
            name: "ForgeOrchestrator",
            dependencies: [
                .product(name: "ForgeCore", package: "ForgeCore"),
            ]
        ),
        .testTarget(
            name: "ForgeOrchestratorTests",
            dependencies: ["ForgeOrchestrator"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
