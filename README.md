# BabelChrome

BabelChrome is a dedicated macOS browser for BabelForge.

It behaves like a separate Chrome-like application: it has its own profile, groups, tabs, extensions, local PHP extension host, and installable viewer modules. It does not use the personal Google Chrome profile.

## What It Does

- Opens web pages in an isolated BabelForge browser profile.
- Accepts URLs from macOS commands such as `open -a BabelChrome "https://example.com"`.
- Accepts local Markdown, Mermaid, OpenAPI, and HTML files from macOS.
- Routes local or remote Markdown, OpenAPI, and JSON documents through installable PHP viewer modules.
- Organizes tabs by groups.
- Keeps groups and tabs between launches.
- Restores the main window position, size, and maximized state between launches.
- Provides a left panel for BabelForge groups.
- Provides a Safari-like tab bar, an address bar, and embedded Chromium pages.
- Shows page favicons in tabs when Chromium exposes one.
- Supports browser extensions from the Chrome Web Store.
- Provides internal pages for settings, history, extensions, and modules.
- Exposes viewer-aware headers to local web projects through `X-BabelChrome-File-Types`.

## Common Commands

Open BabelChrome:

```bash
open -a BabelChrome
```

Open a URL:

```bash
open -a BabelChrome "https://example.com"
```

Open a local Markdown, Mermaid, OpenAPI, or HTML file:

```bash
open -a BabelChrome ./README.md
open -a BabelChrome ./diagram.mmd
open -a BabelChrome ./openapi.yaml
open -a BabelChrome ./index.html
```

Open a remote Markdown URL through the local viewer:

```bash
open -a BabelChrome "https://example.com/README.md"
```

Markdown is rendered by the Markdown PHP module with `league/commonmark` on the backend. The viewer resolves relative Markdown links to stable `babelchrome://markdown/...` URLs, keeps regular non-Markdown links navigable, serves local relative images through the local service, generates a table of contents from headings, renders Mermaid code fences and standalone Mermaid documents with locally bundled JavaScript, supports selectable themes from Settings, auto-refreshes local files when they change, and exposes source-file actions from the context menu. OpenAPI and Swagger YAML/JSON files are rendered by the OpenAPI PHP module through a bundled Swagger UI viewer, with support for internal and relative `$ref` documents and auto-refresh when local referenced files change. JSON files are rendered by the JSON viewer module with `andypf/json-viewer`.

Viewer tabs are stored with stable `babelchrome://markdown/...`, `babelchrome://openapi/...`, `babelchrome://json/...`, or generic `babelchrome://viewer/...` URLs. The temporary `http://127.0.0.1:<port>/...` viewer URL is only an internal runtime URL and is regenerated after each restart.

Open a URL in a named group:

```bash
open "babelchrome://open?group=Mook&url=https%3A%2F%2Fexample.com"
```

Open a named group URL with the compact command format:

```bash
open -a BabelChrome "babelchrome://command/group:Mook::|::url:https://example.com/search?q=a&lang=fr#top"
```

Use the helper to avoid manual URL encoding:

```bash
./tools/babelchrome-open --group "Mook" "https://example.com"
```

## Internal Pages

- `babelchrome://settings`
- `babelchrome://history`
- `babelchrome://extensions`
- `babelchrome://modules`
- `babelchrome://viewer/file/<encoded-path>`
- `babelchrome://viewer/url/<encoded-url>`

## Main Shortcuts

- `Cmd+N`: open a new tab.
- `Cmd+T`: open a new tab next to the active tab.
- `Cmd+W`: close the active tab.
- `Shift+Cmd+T`: reopen the most recently closed tab.
- `Ctrl+Tab`: select the next tab.
- `Shift+Ctrl+Tab`: select the previous tab.
- `Cmd+R`: reload the active page.
- `Cmd+Left`: go back in the active tab.
- `Cmd+Right`: go forward in the active tab.
- `Cmd+Y`: open history.
- `Cmd+,`: open settings.
- `Cmd+;`: open extensions.
- `Cmd+Option+J`: open Developer Tools.
- `Cmd+Q`: quit BabelChrome.

## Extensions

The extensions page lets you:

- search the Chrome Web Store;
- view installed profile extensions;
- add unpacked extensions;
- remove extensions;
- disable and re-enable profile extensions.

Disabling or enabling an extension takes effect after restarting BabelChrome. The extensions page shows `Disabled after restart` or `Enabled after restart` and provides a `Restart` button when a change is waiting.
BabelChrome stores disabled extension packages outside Chromium's active extension directory so they remain visible in BabelChrome without being loaded by Chromium.

## Documentation

More documentation is available in [doc/README.md](doc/README.md).
