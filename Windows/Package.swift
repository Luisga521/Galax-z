// swift-tools-version: 6.0
// Galax-z for Windows: the shared packages and the Android app's core, in a window of its own (`build.ps1`).
import PackageDescription

let package = Package(
    name: "GalaxzWindows",
    platforms: [.macOS(.v15)],                       // for its tests on a Mac; Windows takes no version here
    products: [
        .executable(name: "Galax-z", targets: ["GalaxzWindows"]),
        .executable(name: "galaxz-ports", targets: ["galaxz-ports"]),
    ],
    dependencies: [
        .package(path: "../Packages/GalaxzKit"),
        .package(path: "../Android/core"),
    ],
    targets: [
        // What needs no Windows: the dots drawn by the CPU, the mouse, the timed MIDI sender. Tested on a Mac too.
        .target(name: "GalaxzDesktop", dependencies: [
            .product(name: "GalaxzCore", package: "core"),
            .product(name: "OPZFirmware", package: "GalaxzKit"),
        ]),
        // The window, WinMM's MIDI, the update-mode port: Windows only (on a Mac it builds to a note saying so).
        .executableTarget(name: "GalaxzWindows", dependencies: [
            "GalaxzDesktop",
            .product(name: "GalaxzCore", package: "core"),
            .product(name: "OPZFirmware", package: "GalaxzKit"),
            .product(name: "DotKit", package: "GalaxzKit"),          // Settings' headings, in the screen's own type
            .target(name: "CGalaxzBluetooth", condition: .when(platforms: [.windows])),
        ], linkerSettings: [
            // a window, no console; the C runtime's start calls Swift's main
            .unsafeFlags(["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"], .when(platforms: [.windows])),
        ]),
        // Bluetooth MIDI: only WinRT reaches it on Windows, so a little C++/WinRT behind a C door (empty elsewhere)
        .target(name: "CGalaxzBluetooth", cxxSettings: [
            .unsafeFlags(["-fexceptions", "-fcxx-exceptions"], .when(platforms: [.windows])),
        ], linkerSettings: [
            .linkedLibrary("WindowsApp", .when(platforms: [.windows])),
        ]),
        // The update mode from a terminal: which port, and what is installed (read-only).
        .executableTarget(name: "galaxz-ports", dependencies: ["GalaxzDesktop", .product(name: "OPZFirmware", package: "GalaxzKit")]),
        .testTarget(name: "GalaxzDesktopTests", dependencies: [
            "GalaxzDesktop",
            .product(name: "GalaxzCore", package: "core"),
            .product(name: "OPZFirmware", package: "GalaxzKit"),
        ]),
    ],
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx20                      // C++/WinRT
)
