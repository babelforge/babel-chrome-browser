# BabelChrome Documentation

BabelChrome is a native macOS AppKit application that embeds Chromium through CEF and provides a dedicated BabelForge browser shell.

It opens URLs received from macOS, including:

```bash
open -a BabelChrome "https://example.com"
```

It also supports grouped openings through a custom URL scheme:

```bash
open "babelchrome://open?group=Group%20n&url=http%3A%2F%2F127.0.0.1%3A8772"
```

## Pages

- [Installation](01-installation.md)
- [Architecture](02-architecture.md)
- [Manual Tests](03-manual-tests.md)
- [Features](04-features.md)
- [PHP Modules](05-php-modules.md)

## Current Scope

BabelChrome currently provides:

- a native macOS app bundle;
- an embedded Chromium runtime through CEF;
- a persistent BabelForge profile under `~/Library/Application Support/BabelForge/BabelChrome/Profile`;
- an explicit HTTP and media disk cache under the persistent BabelForge profile;
- persistent group and tab metadata under `~/Library/Application Support/BabelForge/BabelChrome/groups.json`;
- persistent favicon metadata under `~/Library/Application Support/BabelForge/BabelChrome/favicons.json`;
- LaunchServices document support for local Markdown, Mermaid, OpenAPI, and HTML files;
- manifest-driven local viewer service routing for Markdown, Mermaid, OpenAPI-like documents, and JSON documents;
- stable `babelchrome://markdown/...`, `babelchrome://openapi/...`, `babelchrome://json/...`, and `babelchrome://viewer/...` persisted URLs for viewer-backed tabs;
- Markdown rendering with local Mermaid, local syntax highlighting, generated table of contents, selectable themes, local auto-refresh, source-file context actions, and visible error pages;
- OpenAPI and Swagger YAML/JSON rendering through bundled Swagger UI, including internal and relative `$ref` resolution with local referenced-file auto-refresh;
- shared viewer header controls for module viewers, including an `Open with` application selector backed by BabelChrome internal endpoints and a generic message relay for compatible viewer tabs;
- a LocalServiceHost PHP module registry with Markdown and OpenAPI manifests, a framework-agnostic `runtime.web` front-controller contract, route handlers, renderers, view models, errors, Twig templates, source frontend assets, import maps, compiled public assets, and Composer dependencies sourced from the sibling `babel-chrome-modules` workspace, synchronized as runtime modules, manifest-declared viewer capabilities, menu item contributions, contextual menu item resolution, zip installation/update, enable/disable/remove actions for modules, route and settings actions, local catalog metadata, installed-vs-available version display, module metadata and hook APIs, address badge resolution, runtime context helpers, and per-module Composer vendor isolation;
- native routing from module-declared `babelchrome://<host>` URLs to LocalServiceHost module routes;
- viewer capability detection through `X-BabelChrome-File-Types`;
- module public asset serving from each module's own `public/` directory;
- a tested `ModulePackageShipper` service exposed by `tools/ship-php-module.php`, `tools/build-php-modules.sh`, and the sibling `../babel-chrome-modules/tools/dev2prod.sh` helper for packaging PHP modules as zip archives with their own Composer locks and real module-local `vendor/`;
- installable demo, no-framework PHP, and Laravel modules under the sibling `../babel-chrome-modules/src/` workspace;
- lazy session restoration that rebuilds native groups and tabs before starting the active CEF browser;
- a left AppKit panel containing the BabelForge placeholder and the groups list;
- collapsible left panel with compact group initials;
- drag-and-drop group reordering;
- a transparent macOS titlebar containing the native tab strip;
- a right AppKit panel split into address and pages panels;
- a Safari-inspired native tab strip with flexible tab widths in the titlebar area;
- favicon display in tabs when CEF exposes a page favicon;
- drag-and-drop tab reordering inside the selected group;
- drag-and-drop tab moves between groups through delayed group hover;
- one visible tab strip per selected group;
- a native address bar for the selected tab;
- local address bar suggestions from open tabs and recently closed tabs;
- favicon display in address suggestions when a matching origin or known site favicon is available;
- optional Google Suggest address bar suggestions;
- immediate selected-tab browser creation with delayed adjacent-tab preloading;
- a live page browser limit with least-recently-used eviction;
- persistent groups with create, rename, and delete actions;
- configurable tab opening strategies;
- parent-aware new tab placement;
- recently closed tab reopening;
- history, settings, extensions, and PHP modules internal pages;
- Chrome Web Store search from the extensions page;
- extension listing, removal, disable, and enable actions;
- unpacked extension folder registration;
- embedded Developer Tools with persisted docking;
- a `Cmd+N` shortcut for opening a new tab;
- a `Cmd+T` shortcut for opening a new tab next to the active tab;
- a `Cmd+W` shortcut for closing the selected tab;
- a `Shift+Cmd+T` shortcut for reopening the most recently closed tab;
- `Ctrl+Tab` and `Shift+Ctrl+Tab` tab switching;
- `Cmd+R`, `Cmd+Left`, and `Cmd+Right` page navigation;
- `Cmd+Y` history, `Cmd+,` settings, and `Cmd+;` extensions;
- `Cmd+Option+J` Developer Tools;
- normal application termination through `Cmd+Q`;
- macOS URL event handling through `NSApplicationDelegate` and an early Apple Event URL handler;
- a `babelchrome://open?group=...&url=...` command scheme;
- a `tools/babelchrome-open` helper for shell-safe URL encoding and opening;
- installation into `/Applications/BabelChrome.app`.

## Navigation

Previous: none  
Next: [Installation](01-installation.md)  
README: [README](README.md)
