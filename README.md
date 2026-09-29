# DeepSeek Harness Glass

A native macOS Liquid Glass window for the locally installed
[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) web UI.
This fork continues the native menus and keyboard shortcuts from PR #1 on a
separate branch. It targets **dsh 0.1.7-rc.2** and distributes only the Swift
frontend shell: no Node.js, dsh engine, npm packages, or copied web frontend.

[中文说明](README.zh.md)

## Requirements and installation

- macOS 26 or later, Apple Silicon.
- A separately installed dsh and its required Node.js runtime. For the tested
  version: `npm install -g @deepseek-ai/dsh@0.1.7-rc.2`.
- Confirm `dsh --version` and `dsh web --no-open` work in your terminal.

The app uses `DSH_HOME` when set, otherwise `~/.dsh`. Data, credentials,
plugins, migrations, and updates are managed by your dsh installation.
The shell does not install or upgrade dsh.

## Connection and lifecycle

1. Probe `http://127.0.0.1:3080/`, or the last successfully connected local
   endpoint. `DSH_WEB_URL` overrides that address, including a custom port.
2. Reuse a verified dsh service. dsh 0.1.7-rc.2 requires the authenticated
   startup URL on first connection. Paste the full URL printed by `dsh web`
   into the connection screen, or provide it in `DSH_WEB_URL`. WebKit keeps
   the session cookie; the shell saves only the address without the token.
3. If the connection is refused, silently run the user's installed
   `dsh web --no-open --host <local-host> --port <port>` at that endpoint.
   No terminal or browser window opens. The shell reads the complete startup
   URL, including its authentication token, from stdout.
4. Closing the window keeps the app in the menu bar. Quitting stops only the
   child started by Glass. Existing external processes are never stopped;
   their restart menu action reconnects instead. An owned process that exits
   unexpectedly gets one automatic retry.

A login/interactive zsh loads your shell's fnm/nvm/Homebrew configuration when
launching from Finder. `DSH_EXECUTABLE` can select an absolute executable path;
its Node runtime still needs to be available in that shell's PATH. Only local
HTTP URLs are supported. Services on other ports are not automatically scanned;
provide their startup URL. An occupied, unauthorized, or unresponsive endpoint
will show a connection message rather than start a duplicate service.

## Native features

- Native Liquid Glass window with transparent `WKWebView` and CSS token overrides.
- Native menus, keyboard shortcuts, reload, browser handoff, and menu-bar residency.
- Downloads with Finder reveal, shared CLI state, and layered translucent surfaces.
- Token-redacted startup logs at `~/Library/Logs/DeepSeek Harness Glass.log`.

## Building and testing

Install Xcode Command Line Tools with the macOS 26 SDK. No npm dependencies or
backend downloads are needed to build the app.

```sh
APP_PATH="$PWD/glass/dist/DeepSeek Harness.app" glass/assemble.sh
python3 glass/Tests/smoke.py
# Also exercise your installed dsh using a temporary, isolated DSH_HOME:
GLASS_TEST_REAL_DSH=1 python3 glass/Tests/smoke.py
```

Without `APP_PATH`, assembly installs in `/Applications/DeepSeek Harness.app`.
The app is ad-hoc signed, not notarized. Release CI builds the same frontend-only
bundle and packages it as a DMG.

## Troubleshooting

If dsh is missing, install it separately and retry. If startup fails, inspect the
log and verify the CLI command in your terminal. If a service already exists but
requires authorization, paste its full startup link. Restarting that external
process generates a new launch token; use its newly printed link when needed.
The shell does not read or synthesize dsh credentials.

## Project layout

```
glass/Sources/main.swift                native window, menus, WebKit, CSS
glass/Sources/BackendController.swift   local connection and process lifecycle
glass/Tests/                           connection and lifecycle smoke tests
glass/assemble.sh                      compile and sign the frontend-only app
glass/Info.plist                        bundle metadata
build/icon.icns                         app icon
```

## Disclaimer and license

This is an independent, unofficial wrapper, not affiliated with or endorsed by
DeepSeek. MIT; see [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
