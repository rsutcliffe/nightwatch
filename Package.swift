// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Nightwatch",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SkyCore", targets: ["SkyCore"]),
        .library(name: "NightwatchUI", targets: ["NightwatchUI"]),
        .executable(name: "Nightwatch", targets: ["Nightwatch"])
    ],
    dependencies: [
        .package(url: "https://github.com/gavineadie/SatelliteKit.git", exact: "2.1.2")
    ],
    targets: [
        .target(name: "CAstronomyEngine", path: "Sources/CAstronomyEngine"),
        .target(
            name: "SkyCore",
            dependencies: ["CAstronomyEngine", "SatelliteKit"],
            path: "Sources/SkyCore",
            resources: [.copy("Resources")]
        ),
        .target(name: "NightwatchUI", dependencies: ["SkyCore"], path: "Sources/NightwatchUI"),
        .executableTarget(name: "Nightwatch", dependencies: ["SkyCore", "NightwatchUI"], path: "Sources/Nightwatch", exclude: ["Info.plist"]),
        .testTarget(
            name: "SkyCoreTests",
            dependencies: ["SkyCore"],
            path: "Tests/SkyCoreTests",
            resources: [.copy("Fixtures")]
        )
    ]
)
