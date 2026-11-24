// swift-tools-version: 6.0
import PackageDescription

/// swift-crypto, only where Apple's CryptoKit is not (Windows; Android and Linux to check the same code builds).
let crypto = Target.Dependency.product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.windows, .linux, .android]))

let package = Package(
    name: "GalaxzKit",
    platforms: [.iOS(.v18), .macOS(.v15), .macCatalyst(.v18)],
    products: [
        .library(name: "OPZModel", targets: ["OPZModel"]),
        .library(name: "OPZLink", targets: ["OPZLink"]),
        .library(name: "OPZFirmware", targets: ["OPZFirmware"]),
        .library(name: "DotKit", targets: ["DotKit"]),
        .library(name: "OPZStage", targets: ["OPZStage"]),
        .library(name: "OPZPlay", targets: ["OPZPlay"]),
        .library(name: "ChopKit", targets: ["ChopKit"]),
    ],
    dependencies: [
        // Apple's CryptoKit API where there is no CryptoKit (Windows, Linux): release signatures and SHA-256. Pinned exactly;
        // Package.resolved holds its commit.
        .package(url: "https://github.com/apple/swift-crypto.git", exact: "5.0.3"),
    ],
    targets: [
        // The OP-Z's formats: the pattern bank, the global block, the settings files; op-free's engine catalogue.
        .target(name: "OPZModel", resources: [.copy("Resources/OPFree/engines.json")]),
        // A matrix of lights to draw on, its type and its motion. No frameworks: the same on every platform.
        .target(name: "DotKit"),
        // Galax-z's screens, drawn on it from what the OP-Z says.
        .target(name: "OPZStage", dependencies: ["DotKit", "OPZModel", "OPZPlay", "ChopKit"]),
        // Playing the OP-Z: keys into chords and grooves, performance moves, learned controllers. Pure: events in, MIDI commands out.
        .target(name: "OPZPlay", dependencies: ["OPZModel"]),
        // Vocal chops: a source cut up, played and worked on. Pure: samples in, samples out.
        .target(name: "ChopKit"),
        // Talking to an OP-Z: SysEx framing, the StateSync replica, the file service, CoreMIDI, the demo OP-Z.
        .target(name: "OPZLink", dependencies: ["OPZModel", .target(name: "CZlib", condition: .when(platforms: [.android, .linux]))],
                resources: [.copy("Resources/OPFree/demo-session.json")]),
        // The system's zlib, where Apple's Compression is not (Android, Linux).
        .systemLibrary(name: "CZlib"),
        // The OS side: LDR images, patch records, the strict update-mode writer (port of Firmware/tools/flash.py).
        .target(name: "OPZFirmware", dependencies: [crypto], resources: [.copy("Resources/firmware")]),
        .testTarget(name: "GalaxzKitTests", dependencies: ["OPZModel", "OPZLink", "OPZFirmware", "DotKit", "OPZStage", "OPZPlay", "ChopKit", crypto], resources: [.copy("Fixtures")]),
        // Galax-z's protocol code against a real OP-Z on the Mac, read-only (`swift run galaxz-probe`).
        .executableTarget(name: "galaxz-probe", dependencies: ["OPZModel", "OPZLink"]),
        // Galax-z's screens as pictures, with no unit and no window (`swift run galaxz-shots DIR`).
        .executableTarget(name: "galaxz-shots", dependencies: ["ChopKit", "OPZStage", "OPZModel", "OPZLink", "DotKit"]),
        // A virtual OP-Z on this Mac's MIDI (`swift run galaxz-fakeopz`).
        .executableTarget(name: "galaxz-fakeopz", dependencies: ["OPZLink", "OPZModel"]),
        // Make, sign and check Galax-z OS releases (`swift run galaxz-release`).
        .executableTarget(name: "galaxz-release", dependencies: ["OPZFirmware", crypto]),
        // Render a boot animation from the library to the frames the OP-Z plays (`swift run galaxz-frames galaxy …`).
        .executableTarget(name: "galaxz-frames", dependencies: ["OPZFirmware"]),
    ]
)
