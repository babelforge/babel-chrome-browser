# BabelChrome

BabelChrome is a dedicated macOS browser for BabelForge.

It behaves like a separate Chrome-like application: it has its own profile, groups, tabs, extensions, local PHP extension host, and installable viewer modules. It does not use the personal Google Chrome profile.

## What It Does

- Opens web pages in an isolated BabelForge browser profile.
- Accepts URLs from macOS commands such as `open -a BabelChrome "https://example.com"`.
- Accepts local files from macOS and routes supported files through installed viewer modules.
- Organizes tabs by groups.
- Keeps groups and tabs between launches.
- Restores the main window position, size, and maximized state between launches.
- Provides a left panel for BabelForge groups.
- Provides a Safari-like tab bar, an address bar, and embedded Chromium pages.
- Shows page favicons in tabs when Chromium exposes one.
- Supports browser extensions from the Chrome Web Store.
- Provides internal pages for settings, history, extensions, and modules.
- Exposes viewer-aware headers to local web projects through `X-BabelChrome-File-Types` when enabled modules declare file handlers.

## Core Versus Modules

BabelChrome itself is the native browser shell: CEF, tabs, groups, address bar, profile isolation, extension management, internal pages, and the local ExtensionHost runtime.

Document viewers are not built into the browser bundle. Markdown, Mermaid, OpenAPI, JSON, and project-launcher behavior come from installable PHP modules. A file type is handled only when a matching module is installed and enabled from `babelchrome://modules`.

When the browser repository is checked out through the `babel-chrome` meta workspace, common module sources live under the sibling `modules/` directory. Before installation, build production zip files from the meta workspace root:

```bash
./tools/dev2prod.sh
```

That command produces installable archives such as:

```text
zip/babelforge.markdown-viewer-<version>.zip
zip/babelforge.openapi-viewer-<version>.zip
zip/babelforge.json-viewer-<version>.zip
zip/babelforge.project-launcher-<version>.zip
```

See [doc/05-php-modules.md](doc/05-php-modules.md) for the full install workflow.

## Common Commands

Open BabelChrome:

```bash
open -a BabelChrome
```

Open a URL:

```bash
open -a BabelChrome "https://example.com"
```

Open a local file:

```bash
open -a BabelChrome ./README.md
open -a BabelChrome ./diagram.mmd
open -a BabelChrome ./openapi.yaml
open -a BabelChrome ./index.html
```

HTML files can open as direct Chromium `file://` pages. Markdown, Mermaid, OpenAPI, and JSON files require the corresponding viewer module.

Open a remote Markdown URL through the local viewer, when the Markdown viewer module is installed:

```bash
open -a BabelChrome "https://example.com/README.md"
```

When installed, the Markdown viewer module renders Markdown with `league/commonmark`, resolves relative Markdown links to stable `babelchrome://markdown/...` URLs, serves local relative images through the local service, generates a table of contents from headings, renders Mermaid code fences and standalone Mermaid documents with locally bundled JavaScript, supports selectable themes from Settings, auto-refreshes local files when they change, and exposes source-file actions from the context menu.

When installed, the OpenAPI viewer module renders OpenAPI and Swagger YAML/JSON documents through bundled Swagger UI, with support for internal and relative `$ref` documents and auto-refresh when local referenced files change. When installed, the JSON viewer module renders JSON documents with `andypf/json-viewer`.

Viewer tabs are stored with stable `babelchrome://markdown/...`, `babelchrome://openapi/...`, `babelchrome://json/...`, or generic `babelchrome://viewer/...` URLs only when the relevant module exists. The temporary `http://127.0.0.1:<port>/...` viewer URL is only an internal runtime URL and is regenerated after each restart.

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
