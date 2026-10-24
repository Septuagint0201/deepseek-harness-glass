# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
Release names use `glass-<compatible dsh version>`.

## [glass-0.2.1-rc.3] - 2026-10-25

- Target dsh 0.2.1-rc.3 from npm next as a prerelease.
- Update the CI baseline to npm latest 0.2.1-rc.2, whose existing release is now regular Latest.
- Update bundle build number and bilingual installation and release-channel documentation.
- Verify real CLI/WebKit startup, authentication, Glass themes, cookie reconnects,
  browser handoff, downloads and owned-process shutdown against both supported versions.

## [glass-0.2.1-rc.2] - 2026-10-17

- Target dsh 0.2.1-rc.2 directly, skipping rc.1; classify the opt-in npm next-channel build as a prerelease.
- Update the compatible CLI pin, bundle build number, bilingual documentation and CI matrix.
- Retain npm latest 0.2.0-rc.2 compatibility and verify real CLI startup/authentication,
  WebKit rendering, Glass themes, cookie reconnects, browser handoff, downloads and shutdown.

## [glass-0.2.1-alpha.5] - 2026-10-17

- Target the opt-in npm alpha version dsh 0.2.1-alpha.5; retain 0.2.0-rc.2 in the CI compatibility matrix.
- Update bundle metadata, bilingual installation instructions and the pinned real-CLI test version.
- Verify authenticated startup, actual WebKit rendering, light/dark Glass overrides,
  cookie reconnects, browser handoff, downloads and owned-process shutdown with the new CLI.

## [glass-0.2.1-alpha.4] - 2026-10-15

- Target the opt-in dsh 0.2.1-alpha.4 prerelease; retain tested 0.2.0-rc.2 compatibility.
- Hand account sign-in popups and new-window links to the default browser, including
  dsh's asynchronous navigation from a preopened blank window.
- Test popup handoff, cancellation and unsupported schemes without opening a real browser.
- Verify actual WebKit frontend rendering, light/dark Glass overrides and token-free
  cookie reconnects with both supported CLIs in CI; gate publication on those checks.
- Isolate WebKit test cookies in memory and keep real CLI data in temporary homes.
- Remove the stale hard-coded CLI version from startup failure messages.
- Update bundle metadata and bilingual installation and compatibility documentation.
- Classify releases using explicit npm-channel metadata rather than version suffixes;
  npm latest builds remain regular releases even when their version includes `-rc`.

## [glass-0.2.0-rc.2] - 2026-10-07

- Update the supported npm `latest` version to dsh 0.2.0-rc.2.
- Fix WebKit download delegates, download links, attachment responses and Finder reveal.
- Preserve existing files and reserve distinct destinations for concurrent downloads.
- Install verified app bundles with atomic directory exchange; preserve the old app on failure.
- Remember window position and size across app launches using AppKit frame autosave.
- Run build, connection, download and installer checks on main pushes and pull requests.
- Publish frontend-only DMGs with SHA-256 checksums.
- Verify the installed CLI's authenticated web startup and process lifecycle.
- Retain distinct input and modal surfaces with the 0.2.0-rc.2 frontend.

## [glass-0.1.7-rc.2] - 2026-09-29

- Adapt to dsh 0.1.7-rc.2 with a frontend-only native macOS shell.
- Reuse local dsh services or silently launch the separately installed CLI.
- Support authenticated startup URLs, persistent WebKit sessions and token-redacted logs.
- Remove bundled Node.js, backend packages and backend repair tooling.
- Preserve native menus, keyboard shortcuts and Finder download reveal.
- Restore input and dialog background contrast; remove global nested blur.
- Verify connection and child-process lifecycle with isolated smoke tests.

## [0.4.0] - 2026-08-15

### Added

- Port reuse: if a dsh instance is already serving on 127.0.0.1:3080, the
  app attaches to it instead of spawning a second backend.
- Crash recovery: the embedded backend is restarted once automatically
  (0.6 s delay); a second consecutive failure shows a retry page with the
  log path.
- Menu-bar tray with show / open-in-browser / restart-backend / open-home /
  open-log / quit actions; closing the window hides it instead of quitting.
- Harness menu: restart backend and open-in-browser entries.

### Changed

- The shell only terminates a backend it spawned itself; an externally
  reused instance is never killed on quit.
## [0.3.0] - 2026-08-15

### Added

- Native SwiftUI shell with a real Liquid Glass window
  (public `glassEffect` API, macOS 26+).
- Full-window glass: `fullSizeContentView` plus a zero-safe-area hosting view,
  so the glass reaches the window's top edge.
- Dynamic text contrast: the shell samples the desktop wallpaper's average
  luminance once at launch (and on wallpaper change) and flips text between a
  light and a dark palette with 0.45/0.55 hysteresis. Window movement never
  triggers a flip.
- Layered frosting: elevated surfaces (composer, popovers, menus, hover cards)
  get per-layer translucent tints plus a `backdrop-filter` sweep.
- Self-contained distribution: bundled Node.js v24 binary and a pinned,
  npm-installed dsh backend payload; no runtime downloads.
- `repair-backend.sh` — one-shot backend payload reinstall with a smoke test.
- DMG installer with an Applications shortcut and Chinese install notes.

### Fixed

- Missing backend packages after relocating the payload (24 `@deepseek-ai`
  packages): payload installation now goes through `npm` with exact pins.
- DMG creation losing symlinks and invalidating the ad-hoc signature:
  `assemble.sh` now dereferences symlinks (`cp -RL`) before signing.
- Inline-code and citation chips rendering as solid color blocks in the wrong
  theme (they are background tokens, not text tokens).
- Text tokens leaking backdrop color at glyph edges: a 0.5% white underlay
  plus `-webkit-font-smoothing: antialiased`.

### Removed

- Electron-based prototype (private-API glass bridge) and its build pipeline.

## [0.2.0] - 2026-08-15

### Added

- Electron shell prototype (superseded by 0.3.0).

[0.4.0]: https://github.com/qniequn-boop/deepseek-harness-glass/releases/tag/v0.4.0
[0.3.0]: https://github.com/qniequn-boop/deepseek-harness-glass/releases/tag/v0.3.0
