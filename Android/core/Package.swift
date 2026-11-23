// swift-tools-version: 6.0
// Galax-z for Android: the shared packages, built as one library the Android app loads (`../build.sh`).
import PackageDescription

let package = Package(
    name: "GalaxzAndroid",
    platforms: [.macOS(.v15)],                       // for its tests on a Mac; Android takes no version here
    products: [.library(name: "GalaxzAndroid", type: .dynamic, targets: ["GalaxzAndroid"])],
    dependencies: [.package(path: "../../Packages/GalaxzKit")],
    targets: [
        // jni.h, from the NDK.
        .systemLibrary(name: "CJNI"),
        // AAudio, Android's audio streams, from the NDK.
        .systemLibrary(name: "CAAudio"),
        // What `App/Live.swift` and `App/DotDisplay.swift` do on iOS, driven by the Kotlin app through JNI.
        .target(name: "GalaxzAndroid", dependencies: [
            .target(name: "CJNI", condition: .when(platforms: [.android])),
            .target(name: "CAAudio", condition: .when(platforms: [.android])),
            .product(name: "OPZModel", package: "GalaxzKit"),
            .product(name: "OPZLink", package: "GalaxzKit"),
            .product(name: "OPZStage", package: "GalaxzKit"),
            .product(name: "OPZPlay", package: "GalaxzKit"),
            .product(name: "DotKit", package: "GalaxzKit"),
            .product(name: "ChopKit", package: "GalaxzKit"),
        ]),
        // The session and the screen with the demo OP-Z, on this Mac (`swift test` here).
        .testTarget(name: "GalaxzAndroidTests", dependencies: ["GalaxzAndroid", .product(name: "OPZLink", package: "GalaxzKit"),
                                                               .product(name: "OPZStage", package: "GalaxzKit")]),
    ],
    swiftLanguageModes: [.v5]
)
