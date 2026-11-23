# Releasing a Galax-z OS version

A release is one signed file, `Releases/galaxz-vN.galaxz`, and an entry in `Releases/feed.json`. Apps fetch both from the
repository's `main` branch (`ReleaseFeed.defaultURL`), so the repository has to be public for them to find it.

What it holds: a build and its patch records (addresses, the bytes expected there, our bytes), what is new, and the SHA-256 of the
image they make. No code of TE's but the few bytes each edit replaces ([what exactly](../DISCLAIMER.md#what-of-tes-is-in-here)).

## Once

```bash
cd Packages/GalaxzKit
swift run galaxz-release keygen      # the signing key: ~/Library/Application Support/Galax-z/release-key, only you can read it
```

Put the public key it prints in `Sources/OPZFirmware/ReleaseKeys.swift`. **Keep a copy of the key file somewhere safe and never
commit it.** Whoever has it can sign releases that every Galax-z app will trust; if it is lost, a new app version with a new key is
the only way on. To change keys, ship an app that trusts both first.

## Each time

1. The build works **on a unit** (`Firmware/README.md`, the protocol), its records say so, and it has `notes` in
   `Firmware/builds/galaxz-vN.json` (what is new, a line each, for people).
2. ```bash
   Tools/sync-firmware.sh
   cd Packages/GalaxzKit && swift test
   swift run galaxz-release make galaxz-vN /path/to/TE/os.ldr ../../Releases
   swift run galaxz-release verify ../../Releases/galaxz-vN.galaxz /path/to/TE/os.ldr
   swift run galaxz-release feed ../../Releases
   ```
3. Check the printed image SHA-256 is the one that ran on the unit. Commit `Releases/` and push to `main`.
4. Where the public repository is made from a private one, bring it across: `Tools/make-public.sh FOLDER OWNER "what changed"`,
   look, push. A GitHub release with the `.galaxz` file attached is a nice extra; the apps read the feed on `main`.

A build the app ships with is never replaced by a release of the same name: a version's records are frozen once it is out.

## What the app refuses

A signature by another key · a file changed by one byte · a record that is a draft, or not for TE's 1.2.45 · a build and records that
do not match · records that do not make the promised image · a feed entry that points anywhere but beside the feed · anything not
over HTTPS. Tests: `ReleaseTests.swift`.
