# Safety and security

**Could it break somebody's OP-Z, or get a bad image onto one?** That is the most important thing to report.

- **An OP-Z that will not start:** first [what to do](docs/SAFETY.md#if-it-does-not-start). Then a *Unit report* issue, so nobody repeats it.
- **A way around what the writer or the release check refuses** (signature, checksum, write guard): use GitHub's private
  *Security › Report a vulnerability* if it is offered, or an issue that says there is a problem without saying how.

It is looked at as soon as somebody can. If it is bad, the release comes down.

## What protects you

- Releases are signed (Ed25519). The app trusts only the key in `ReleaseKeys.swift`, and an image must match its promised SHA-256.
- The writer sends a fixed set of frames, writes two files, only known images, and reads both back.
- Install Galax-z OS only from a release you can trace: this repository's `Releases/`, or a fork you chose, whose app has **its own** key.
- Somebody sends you a built OS image? Do not install it.

A maintainer who loses their signing key, or thinks it was seen, has to ship an app with a new one ([docs/RELEASING.md](docs/RELEASING.md)).
