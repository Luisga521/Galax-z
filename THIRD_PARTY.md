# Third-party notices

Keep this file with any copy or fork, and with any app you hand out.

## OP-FREE (MIT)

<https://github.com/mutlisensor/op-free>. Galax-z is independent of OP-FREE and not endorsed by it. From it come, as
Swift ports or after its code: the SysEx, StateSync and file-service clients and the pattern bank (`OPFree` folders in the app), the engine
catalogue, the demo session and test fixtures; in part, the update-mode framing, the patch-record format and the frame of the two engines;
and most of what this project knows about the OP-Z. File by file: OWNERSHIP.md and REUSE.toml in the repository.

    MIT License
    
    Copyright (c) 2026 Lourens Smit and the op-z-engines contributors
    
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

OP-FREE itself credits [opz-firmware-notes](https://github.com/ioma8/opz-firmware-notes) for several of its safety rules.

## Salamander Grand Piano V3 (CC BY 3.0)

By Alexander Holm, <https://github.com/sfzinstruments/SalamanderGrandPiano>, licence <https://creativecommons.org/licenses/by/3.0/>.
`Firmware/engines/piano/opzk_piano.aif` is made from it: 30 notes cut, levelled, re-tuned, compressed and re-encoded. It is under the same
licence; keep this credit with it.

## teenage engineering

OP-Z and OP-1 are trademarks of teenage engineering. None of their firmware images, engines, sounds, artwork or fonts are here.
The few bytes of theirs that patch records carry: DISCLAIMER.md in the repository.

## Linux

How older Yamaha keyboards speak USB-MIDI was learned from the kernel's USB audio quirks. No kernel code is here.

## swift-crypto and BoringSSL (Apache 2.0; BoringSSL's own notices)

Apple's [swift-crypto](https://github.com/apple/swift-crypto) 5.0.3, pinned in `Packages/GalaxzKit/Package.resolved`, does on Windows what
CryptoKit does on Apple's systems: release signatures (Ed25519) and SHA-256. It is built into the Windows programs, and with it Google's
BoringSSL, under the licences in swift-crypto's `LICENSE.txt` and `Sources/CCryptoBoringSSL/LICENSE`. Nothing of it is in the Apple apps.

## Swift's runtime (Apache 2.0 with the Runtime Library Exception)

The Windows zip carries the Swift runtime and Foundation as swift.org builds them (`swiftCore.dll`, `Foundation.dll`, ICU's data in
`_FoundationICU.dll`, …), unchanged. Licence: <https://swift.org/LICENSE.txt>.

## Microsoft's C++ runtime

`vcruntime140.dll`, `vcruntime140_1.dll` and `msvcp140.dll` sit beside the Windows programs, unchanged, as Microsoft's Visual C++
redistributable allows, for computers that have never had them.

## puff (zlib licence)

`Packages/GalaxzKit/Sources/OPZLink/Inflate.swift` is written for Galax-z in Swift, following the way Mark Adler's `puff.c` (in zlib's
`contrib/puff`) decodes deflate. Altered and rewritten; not the original.
