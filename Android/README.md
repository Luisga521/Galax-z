# Galax-z for Android

**A test build.** The same screens as on the iPad, from the same Swift code, in an Android app. Seen working on a Pixel
2 XL (Android 15) with an OP-Z over Bluetooth.

## How it is made

| | |
|---|---|
| `core/` | The shared packages (`Packages/GalaxzKit`) built for Android with the [Swift SDK for Android](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html), as one library, `libGalaxzAndroid.so`. `Core.swift` is `App/Live.swift` without tasks or actors; `JNI.swift` is what Kotlin calls, under one lock. |
| `app/` | A Kotlin app with no libraries: `DotView` draws the dots with OpenGL ES (`App/DotShaders.swift` in GLSL), `MidiLink` finds the OP-Z through Android's MIDI service (a USB-C cable, or Bluetooth LE MIDI) and sends with each message's time, `Sound` chooses where the OP-Z is heard (`App/AudioOut.swift`; `core/…/SoundPath.swift` joins the two AAudio streams), `MainActivity` is the window and a small Settings. |
| `build.sh` | Builds both: `Android/build/Galax-z.apk`. `build.sh install` puts it on the phone plugged in. |

`swift test` in `core/` runs the session and every page against the demo OP-Z on a Mac.

## Building

You need the [swift.org toolchain 6.4.3](https://www.swift.org/install/macos/) and its Swift SDK for Android, the Android
NDK r30 (`swift sdk` links it in with the SDK's `scripts/setup-android-sdk.sh`), the Android SDK (platform 36), a JDK 17 or
newer, and Gradle. Then:

```sh
Android/build.sh
```

The APK is signed with Android's debug key: a build to install by hand (allow *Install unknown apps*), not for a store.
It is for arm64 phones, Android 11 and later.

## What works, and what is not there yet

| | |
|---|---|
| Every page, touch, swipes, a keyboard's arrows and digits | yes, as on the iPad |
| The OP-Z over Bluetooth | works: it searches while no cable is in, and read a project on a Pixel |
| The OP-Z over a USB-C cable | works when the phone is in charge of the cable; when the OP-Z takes charge, the phone says so and opens Android's USB preferences (an app cannot swap the roles). It opens by itself when an OP-Z is plugged in |
| The OP-Z's sound through the phone | works (tap OUT in the corner, or Settings › SOUND) |
| CHOPS: the sampler, its kits, recording (microphone or the OP-Z), opening sound files | built, as on the iPad; seen on the emulator |
| Settings: GENERAL (screen, sound, demo, backups, USB, key test, link check, credits), LEARN, GALAX-Z OS | built to match the iPad's, item for item |
| Installing Galax-z OS | not on Android: the Mac does it |

Backups and link checks go to `Android/data/org.galaxz.app/files/`, which a computer sees over USB.

**The cable.** The OP-Z and a phone can each take charge of a USB-C cable. With some USB-C to USB-C cables they fight over it and the phone
never sees the OP-Z; another cable did it on a Pixel. A USB-C OTG adapter and a USB-A to USB-C cable put the phone in charge every time. When
Android asks what the USB is for, the OP-Z took charge: plug it in again.
