---
name: run
description: |
  Build, launch, and smoke-test the Clippy app on this project. Use when the
  user says "run it", "build and open", "test the app", "launch clippy", or
  wants to see a change working in the real app. Kills any running instance
  first so you're never looking at a stale build.
---

# Run Clippy

1. Kill any running instance (ignore error if none): `pkill -f dist/Clippy.app`
2. Debug build + bundle: `Support/build-app.sh debug`
3. Launch: `open dist/Clippy.app`

Run these directly via Bash — see `/Users/jbanas/Workspace/clippy/CLAUDE.md` ("Working with this repo": never delegate shell to a subagent).

## Notes

- Calendar/EventKit behavior (permission prompt, event reads) only works from
  the built `dist/Clippy.app`, not from a raw `swift build` binary — this is
  why step 2 always bundles, even for a quick check.
- If calendar permission seems stuck or you need to re-trigger the TCC prompt:
  `tccutil reset Calendar com.jbanas.clippy`, then repeat steps 2-3.
- For unit tests instead of a live run, use `swift test` (or `swift test
  --filter <TestClass>/<testMethod>`) directly — no bundling needed.
