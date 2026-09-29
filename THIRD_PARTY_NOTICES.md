# Third-Party Notices

DeepSeek Harness Glass bundles or derives from the following third-party works.
All of them are distributed under permissive licenses; the full license texts
are available at the linked sources.

## DeepSeek Harness

- Project: <https://github.com/deepseek-ai/deepseek-harness>
- License: MIT
- Usage: the icon in `build/icon.icns` and the template fish in
  `glass/assets/fish.svg` derive from dsh artwork. The shell connects to the
  user's separately installed dsh and displays its web UI. No dsh engine,
  frontend npm package, or Node.js runtime is distributed in this app.

## Apple platform APIs

- The Liquid Glass window uses public SwiftUI/AppKit APIs
  (`glassEffect`, `NSVisualEffectView`, transparency and full-size-content
  window options) available on macOS 26 and later. No private APIs are used.

## Fonts

- The user interface uses fonts shipped with the dsh web frontend and macOS
  system fonts.
