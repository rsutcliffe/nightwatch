// swift-tools-version: 5.9
import PackageDescription

// The sky maths is the Mac app's SkyCore, pinned to a revision so a change on the Mac side can never break this build.
// The revision is main's merge of the Mac repo's PR 191 ("SkyCore builds for iOS 17 as well as macOS 14").
let package = Package(
    name: "NightwatchPhone",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PhoneCore", targets: ["PhoneCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/rsutcliffe/nightwatch.git", revision: "bc78d2c08d1e3807a561d6f808e04f2c3fcac800")
    ],
    targets: [
        .target(name: "PhoneCore", dependencies: [.product(name: "SkyCore", package: "nightwatch")]),
        .testTarget(name: "PhoneCoreTests", dependencies: ["PhoneCore", .product(name: "SkyCore", package: "nightwatch")])
    ]
)
