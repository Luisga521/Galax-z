// swift-tools-version: 6.0
import PackageDescription

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
        .target(name: "OPZLink", dependencies: ["OPZModel"], resources: [.copy("Resources/OPFree/demo-session.json")]),
        // The OS side: LDR images, patch records, the strict update-mode writer (port of Firmware/tools/flash.py).
        .target(name: "OPZFirmware", resources: [.copy("Resources/firmware")]),
        .testTarget(name: "GalaxzKitTests", dependencies: ["OPZModel", "OPZLink", "OPZFirmware", "DotKit", "OPZStage", "OPZPlay", "ChopKit"], resources: [.copy("Fixtures")]),
        // Galax-z's protocol code against a real OP-Z on the Mac, read-only (`swift run galaxz-probe`).
        .executableTarget(name: "galaxz-probe", dependencies: ["OPZModel", "OPZLink"]),
        // Galax-z's screens as pictures, with no unit and no window (`swift run galaxz-shots DIR`).
        .executableTarget(name: "galaxz-shots", dependencies: ["ChopKit", "OPZStage", "OPZModel", "OPZLink", "DotKit"]),
        // A virtual OP-Z on this Mac's MIDI (`swift run galaxz-fakeopz`).
        .executableTarget(name: "galaxz-fakeopz", dependencies: ["OPZLink", "OPZModel"]),
        // Make, sign and check Galax-z OS releases (`swift run galaxz-release`).
        .executableTarget(name: "galaxz-release", dependencies: ["OPZFirmware"]),
        // Render a boot animation from the library to the frames the OP-Z plays (`swift run galaxz-frames galaxy …`).
        .executableTarget(name: "galaxz-frames", dependencies: ["OPZFirmware"]),
    ]
)
