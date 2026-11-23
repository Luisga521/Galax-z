# Contributing

**Thank you for being here.** Galax-z is a work in progress and gets better with every pair of hands: testing on another OP-Z, a bug found, a bug
fixed, Windows, Linux, a drawing, a better sentence. It is worked on in spare time, so an answer can take a while; please help each other too.

| You have | Do |
|---|---|
| A result from your OP-Z, good or bad | A *Unit report* issue. The most useful thing there is |
| A bug | Look in [KNOWN-ISSUES.md](docs/KNOWN-ISSUES.md), then a *Bug* issue |
| A fix, with its test | A pull request |
| An hour, and no idea where to start | [WORTH-DOING.md](docs/WORTH-DOING.md), *Worth doing now* |
| Windows or Linux | [PORTING.md](docs/PORTING.md), and a *Help wanted* issue so people find each other |
| A bigger idea | A discussion first, or build it in your fork and show it |
| Your own direction | Fork it ([FORKING.md](docs/FORKING.md)), and open a *Fork* issue |
| Something that could break an OP-Z | [SECURITY.md](SECURITY.md) |
| A synth or an effect | [OP-FREE](https://github.com/mutlisensor/op-free/blob/main/CONTRIBUTING.md) |
| A question for TE's support | Put TE's own OS back first, and leave Galax-z out of it |

## What a pull request needs

- One thing, with its test. `swift test` and `Firmware/tools/test_*.py` pass.
- Claims carry their label: [unit], [code], [inferred]. Say what you did **not** check.
- **Nothing of TE's**: no images, dumps, keys, listings, sounds, artwork. Expected bytes only as many as the patch needs.
- A version's patch records are frozen once it is out. A new record, a new build.
- Nothing that loosens what the writer refuses ([docs/SAFETY.md](docs/SAFETY.md#never)).
- Only sources with a licence that allows it, named in [OWNERSHIP.md](OWNERSHIP.md), `REUSE.toml` and [THIRD_PARTY.md](THIRD_PARTY.md).
- Written with AI? Say so. You answer for it.

Contributions come under the [MIT licence](LICENSE), as the rest. Use whatever name you like, and leave your private e-mail out of your commits
(GitHub has a no-reply address for that).

Be kind, and leave people's private lives alone ([DISCLAIMER.md](DISCLAIMER.md#the-people-here)). We are all doing this for the love of a small grey box.
