// swift-tools-version: 6.2
import CompilerPluginSupport
import Foundation
import PackageDescription

let package = Package(
    name: "CodexBar",
    platforms: [
        // Windows support via Swift for Windows toolchain
        // Also supports Linux for CLI
        .macOS(.v14),  // Keep for Linux/cross-platform builds
    ],
    dependencies: [
        .package(url: "https://github.com/steipete/Commander", from: "0.2.1"),
        .package(url: "https://github.com/apple/swift-log", from: "1.9.1"),
        .package(url: "https://github.com/apple/swift-syntax", from: "600.0.1"),
    ],
    targets: [
        .target(
            name: "CodexBarCore",
            dependencies: [
                "CodexBarMacroSupport",
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]),
        .macro(
            name: "CodexBarMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ]),
        .target(
            name: "CodexBarMacroSupport",
            dependencies: [
                "CodexBarMacros",
            ]),
        .executableTarget(
            name: "CodexBarCLI",
            dependencies: [
                "CodexBarCore",
                .product(name: "Commander", package: "Commander"),
            ],
            path: "Sources/CodexBarCLI",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]),
        .testTarget(
            name: "CodexBarLinuxTests",
            dependencies: ["CodexBarCore", "CodexBarCLI"],
            path: "TestsLinux",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("SwiftTesting"),
            ]),
    ])
