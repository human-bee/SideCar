// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SideCar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SideCar", targets: ["SideCarApp"]),
        .library(name: "AppCore", targets: ["AppCore"]),
        .library(name: "CodexAdapter", targets: ["CodexAdapter"]),
        .library(name: "ThreadStore", targets: ["ThreadStore"]),
        .library(name: "VoiceCore", targets: ["VoiceCore"]),
        .library(name: "UIComponents", targets: ["UIComponents"])
    ],
    targets: [
        .target(name: "AppCore"),
        .target(name: "CodexAdapter", dependencies: ["AppCore"]),
        .target(name: "ThreadStore", dependencies: ["AppCore"]),
        .target(name: "VoiceCore", dependencies: ["AppCore"]),
        .target(name: "UIComponents", dependencies: ["AppCore", "ThreadStore", "VoiceCore"]),
        .executableTarget(name: "SideCarApp", dependencies: ["AppCore", "CodexAdapter", "ThreadStore", "VoiceCore", "UIComponents"]),
        .testTarget(name: "AppCoreTests", dependencies: ["AppCore"]),
        .testTarget(name: "CodexAdapterTests", dependencies: ["CodexAdapter"]),
        .testTarget(name: "ThreadStoreTests", dependencies: ["ThreadStore"]),
        .testTarget(name: "UIComponentsTests", dependencies: ["UIComponents", "AppCore", "ThreadStore"]),
        .testTarget(name: "VoiceCoreTests", dependencies: ["VoiceCore"])
    ]
)
