# BabelChrome Documentation

Navigation: [Next: Installation](01-installation.md)

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
- [Modules](05-php-modules.md)
- [Browser Window Controller Refactor](06-browser-window-controller-refactor.md)
- [Browser Source Layout](07-browser-source-layout.md)

## Current Scope

BabelChrome currently provides:

- a native macOS app bundle;
- an embedded Chromium runtime through CEF;
- a persistent BabelForge profile under `~/Library/Application Support/BabelForge/BabelChrome/Profile`;
- an explicit HTTP and media disk cache under the persistent BabelForge profile;
- persistent group and tab metadata under `~/Library/Application Support/BabelForge/BabelChrome/groups.json`;
- persistent favicon metadata under `~/Library/Application Support/BabelForge/BabelChrome/favicons.json`;
- LaunchServices document support for local files, with direct handling for regular browser files such as HTML;
- manifest-driven local viewer service routing for file types declared by installed modules;
- stable `babelchrome://markdown/...`, `babelchrome://openapi/...`, `babelchrome://json/...`, and `babelchrome://viewer/...` persisted URLs when the corresponding viewer modules are installed;
- Markdown rendering through the optional Markdown viewer module, including local Mermaid, local syntax highlighting, generated table of contents, selectable themes, local auto-refresh, source-file context actions, and visible error pages;
- OpenAPI and Swagger YAML/JSON rendering through the optional OpenAPI viewer module, including internal and relative `$ref` resolution with local referenced-file auto-refresh;
- shared viewer header controls for module viewers, including an `Open with` application selector backed by BabelChrome internal endpoints and a generic message relay for compatible viewer tabs;
- a native module registry and installer for installed manifest discovery, manifest-declared viewer capabilities, menu item contributions, address badge metadata, zip installation/update, enable/disable/remove actions, route and settings metadata, local catalog metadata, installed-vs-available version display, and per-module dependency isolation;
- native process runtime metadata for `process-web` and `process-runtime`, including manifest validation, command definitions, port allocation, command interpolation, cwd resolution, and fallback diagnostics;
- a transitional LocalServiceHost/ExtensionHost runtime with the fresh public runtime contract for `static-web`, `process-web`, and `process-runtime`, plus route handlers, renderers, view models, errors, Twig templates, source frontend assets, import maps, compiled public assets, dependencies supplied by installed modules, contextual menu item resolution, hook APIs, runtime context helpers, readiness checks, user-confirmed setup actions, process lifecycle management, and token-protected internal APIs;
- native routing from module-declared `babelchrome://<host>` URLs to LocalServiceHost module routes;
- viewer capability detection through `X-BabelChrome-File-Types`;
- module public asset serving from each module's own `public/` directory;
- a tested runtime-aware `ModulePackageShipper` service exposed by the historical `tools/ship-php-module.php`, `tools/build-php-modules.sh`, and the meta workspace `tools/dev2prod.sh` helper for packaging Composer-based modules with their own locks and module-local `vendor/`, static web modules without Composer, and process-backed modules with their own executable runtime files;
- installable Markdown, OpenAPI, JSON, project launcher, demo, no-framework PHP, Laravel, and runtime demo modules under the sibling `../modules/` workspace;
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
- history, settings, extensions, and modules internal pages;
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
- installation into `/Applications/BabelChrome.app`;
- a responsibility-based native browser source layout under `src/Browser`, with second-level directories for address bar behavior, CEF integration, Developer Tools, drag-and-drop, extensions, groups, internal pages, modules, navigation, state, tabs, UI helpers, utilities, and window orchestration.

Navigation: [Next: Installation](01-installation.md)
