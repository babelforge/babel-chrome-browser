# Features

## Application Role

BabelChrome is a native macOS browser shell for BabelForge. It embeds Chromium through CEF, uses a dedicated BabelForge profile, and accepts URLs from macOS.
BabelChrome restores the main window position, size, and maximized state between launches.

The installed application is:

```text
/Applications/BabelChrome.app
```

The bundle identifier is:

```text
fr.babelforge.babel-chrome
```

## Isolated Browser Profile

BabelChrome stores Chromium profile data under:

```text
~/Library/Application Support/BabelForge/BabelChrome/Profile
```

This profile is separate from the personal Google Chrome profile. Cookies, sessions, extensions, local storage, and browser data belong to BabelChrome.

BabelChrome also configures Chromium with an explicit HTTP disk cache inside the profile:

```text
~/Library/Application Support/BabelForge/BabelChrome/Profile/Default/Cache
```

This cache can speed up reloads between launches when a site allows its resources to be cached. It does not replace page restoration: open tabs are restored as tab metadata and URLs, then CEF recreates browser views lazily. On startup, BabelChrome rebuilds the native groups and tabs first, starts only the restored active tab immediately after reconstruction, and preloads adjacent tabs afterward.

## Opening URLs

BabelChrome supports plain macOS openings:

```bash
open -a BabelChrome
open -a BabelChrome "https://example.com"
```

Plain HTTP and HTTPS URLs open in the `default` group.

BabelChrome is also declared as a viewer for local Markdown, Mermaid, OpenAPI, and HTML files:

```bash
open -a BabelChrome ./README.md
open -a BabelChrome ./diagram.mmd
open -a BabelChrome ./index.html
```

Supported local file extensions are `md`, `markdown`, `mdown`, `mkd`, `mmd`, `mermaid`, `yaml`, `yml`, `json`, `html`, and `htm`. HTML files open as direct `file://` tabs. Markdown and Mermaid files open through the local Symfony viewer service. YAML, YML, and JSON files are routed to the OpenAPI viewer only when their filename contains `openapi` or `swagger`.

Remote Markdown URLs also open through the local viewer service:

```bash
open -a BabelChrome "https://example.com/README.md"
```

Markdown rendering uses `league/commonmark` inside the Markdown viewer module. Viewer frontend source assets and import-map metadata live in the module source workspace, and compiled runtime assets are served from that module's own `public/` directory.

Markdown, OpenAPI, and JSON viewers share a common viewer header from the `babelforge/babelchrome-viewer-kit` package. The kit provides the document title area and an `Open with` control for local files. The control lists macOS applications that declare support for the current file extension, stores the selected application as a shared BabelChrome preference for that extension, and asks BabelChrome to open the original local file with that application.

The Markdown viewer resolves Markdown links and assets according to the opened document:

- relative links to Markdown-like files are exposed as stable `babelchrome://markdown/file/...` links and opened through the local Markdown viewer;
- remote links to Markdown-like files are exposed as stable `babelchrome://markdown/url/...` links and opened through the local Markdown viewer;
- URL fragments such as `README.md#section` are preserved;
- regular non-Markdown links remain navigable as normal links;
- local relative images are served through the local viewer service;
- fenced Mermaid blocks and standalone `.mmd` or `.mermaid` files are rendered as diagrams with bundled local JavaScript;
- `h1`, `h2`, and `h3` headings are used to generate a table of contents;
- four Markdown themes are available from Settings: GitHub Light, GitHub Dark, Reader, and Compact;
- code blocks are highlighted with bundled local `highlight.js`.

Markdown viewer tabs use stable app URLs such as `babelchrome://markdown/file/<encoded-path>` or `babelchrome://markdown/url/<encoded-url>`. BabelChrome converts those stable URLs to a temporary local service URL only when Chromium needs to load the rendered page. This avoids stale random ports after an application restart.

When a local Markdown file changes on disk, the viewer checks the source timestamp and refreshes the rendered page automatically. A manual `Cmd+R` also rebuilds the viewer URL with the current Markdown theme.

The Markdown page context menu includes source actions for local files:

- `Open Source File` opens the original Markdown file with macOS;
- `Reveal in Finder` selects the original Markdown file in Finder.

If a Markdown source cannot be loaded, BabelChrome displays a local viewer error page instead of a blank page. If a linked image cannot be loaded through the local asset endpoint, the viewer returns an inline SVG placeholder that names the missing asset.

OpenAPI-like files named with `openapi` or `swagger` and ending in `yaml`, `yml`, or `json` are routed to the OpenAPI viewer when opened explicitly:

```bash
open -a BabelChrome ./openapi.yaml
```

OpenAPI rendering uses the bundled Swagger UI frontend. The local viewer accepts JSON and YAML sources, validates that they expose the usual `openapi` or `swagger`, `info`, and `paths` root fields, resolves internal and relative `$ref` documents, and shows a visible local error page when the source cannot be parsed as a usable OpenAPI specification.

OpenAPI viewer tabs use stable app URLs such as `babelchrome://openapi/file/<encoded-path>` or `babelchrome://openapi/url/<encoded-url>`. Local OpenAPI files auto-refresh when the source timestamp changes on disk, including local files loaded through relative `$ref` values.

Example OpenAPI files are stored under:

```text
src/ExtensionHost/resources/
```

## PHP Modules

BabelChrome includes the first LocalServiceHost module registry.

No PHP module is bundled into BabelChrome for now. A module becomes available only after installing a production zip into the user modules directory. Markdown and OpenAPI viewers are regular modules produced by the sibling `babel-chrome-modules` workspace, then installed like any other module.

Installed module manifests declare viewer capabilities such as supported file extensions and optional filename fragments. Their PHP entrypoint classes, document renderers, view models, error classes, Twig templates, source frontend assets, import map metadata, compiled public assets, and Composer dependencies live in their own module package.

The native app asks the LocalServiceHost for the matching installed viewer module instead of duplicating Markdown/OpenAPI rules in native code. The historical stable URLs `babelchrome://markdown/...` and `babelchrome://openapi/...` remain compatible when the corresponding module is installed; internally, the legacy `/markdown` and `/openapi` service endpoints delegate to module entrypoints.

The current Markdown/OpenAPI/JSON modules still reuse LocalServiceHost platform services for source loading and source registration. Viewer-specific PHP, Twig, source frontend assets, import maps, compiled public assets, and Composer vendors live in the modules.

BabelChrome supports a framework-agnostic web module contract. A web module declares a front controller in `manifest.json`:

```json
{
  "runtime": {
    "type": "web",
    "entrypoint": "public/index.php"
  },
  "entrypoint": "public/index.php"
}
```

The front controller belongs to the module. It may be plain PHP, Symfony, Laravel, or another PHP project layout. BabelChrome does not use framework-specific adapters. It prepares a standard request environment, exposes `BABELCHROME_*` runtime variables, and executes the declared front controller.

By default, web modules run in the LocalServiceHost PHP process for compatibility with existing viewer modules. A module that needs strict Composer dependency isolation can request a dedicated PHP process:

```json
{
  "runtime": {
    "type": "web",
    "entrypoint": "public/index.php",
    "processIsolation": true
  }
}
```

This is required for framework modules such as Laravel when their dependencies conflict with classes already loaded by the LocalServiceHost.

Important runtime variables include:

```text
BABELCHROME_MODULE_ID
BABELCHROME_MODULE_ROUTE
BABELCHROME_MODULE_DIR
BABELCHROME_MODULE_ASSET_BASE_URL
BABELCHROME_LOCAL_SERVICE_BASE_URL
BABELCHROME_LOCAL_SERVICE_TOKEN
BABELCHROME_SOURCE_URL
```

The older class-entrypoint runtime remains available for compatibility, but new modules should use `runtime.type = web`.

Editable BabelChrome module source packages live outside the app source tree, in the sibling workspace:

```text
../babel-chrome-modules/src/
```

Production module zips are generated into:

```text
../babel-chrome-modules/zip/
```

The macOS app build does not copy module packages into the application bundle. Module source packages are built independently into zip files, and those zips are installed explicitly from the modules page.

The current module source packages are:

```text
../babel-chrome-modules/src/json-viewer
../babel-chrome-modules/src/markdown-viewer
../babel-chrome-modules/src/openapi-viewer
../babel-chrome-modules/src/project-launcher
../babel-chrome-modules/src/demo-module
../babel-chrome-modules/src/plain-php-module
../babel-chrome-modules/src/laravel-module
```

Shared viewer UI code lives in its own Composer package:

```text
babelforge/babelchrome-viewer-kit
```

Viewer modules require this package through a GitHub VCS Composer repository and keep the resulting dependency inside their own module-local `vendor/` directory. The package is not bundled into BabelChrome itself.

User-installed modules are expected to live outside the `.app` bundle:

```text
~/Library/Application Support/BabelForge/BabelChrome/Modules
```

Each module owns its own Composer dependencies. BabelChrome does not share or merge module vendors. A module package must therefore include its own:

```text
vendor/
```

`tools/build-php-modules.sh` runs `composer install --no-dev --classmap-authoritative` inside each workspace module before packaging. The Markdown and OpenAPI modules therefore ship with real module-local Composer dependencies, not only a placeholder autoloader.

Module source directories are development workspaces. They may contain `assets/`, `importmap.php`, `tests/`, `var/`, `ai/`, build files, and other development-only files. `ModulePackageShipper` excludes those development paths from production zips and keeps runtime files such as `manifest.json`, `composer.json`, `composer.lock`, `src/`, `templates/`, `vendor/`, and `public/`.

The LocalServiceHost exposes module metadata through its internal API:

```text
/internal/modules
/internal/file-types
/internal/module-hooks
/internal/module-menu-items
/internal/address-badge
/internal/open-with/list/<extension>
/internal/open-with/set/<extension>
/internal/open-with/open
```

`/internal/modules` returns installed modules only. BabelChrome currently has no built-in module catalog and does not claim to know the latest version available outside the installed packages.

`/internal/file-types` returns the file extensions advertised by enabled modules that declare a `file-type-handler` block. The native browser injects those extensions into HTTP and HTTPS requests as:

```text
X-BabelChrome-File-Types: md,markdown,mmd,mermaid,yaml,yml,json
```

This header is intentionally limited to file type capabilities. It does not expose installed module identifiers, module names, or module versions.

The `/internal/open-with/...` endpoints are token-protected LocalServiceHost endpoints used by viewer modules:

- `GET /internal/open-with/list/<extension>` returns the shared default application id, when still available, and the macOS applications discovered for that extension;
- `POST /internal/open-with/set/<extension>` stores a shared default application id for that extension after validating that the application is available;
- `POST /internal/open-with/open` opens a registered local source or explicit local file with the selected application, falling back to the macOS default app when no application id is provided.

These endpoints are deliberately file-extension based and module-agnostic. Viewer modules decide whether and where to expose the control, while BabelChrome owns the shared system integration.

Servers can redirect BabelChrome to the generic viewer dispatcher without knowing which module will handle the source:

```text
babelchrome://viewer/file/%2FUsers%2Fuser%2FDocuments%2FREADME.md
babelchrome://viewer/url/https%3A%2F%2Fexample.com%2FREADME.md
```

BabelChrome resolves those stable URLs through the installed viewer modules. If no enabled viewer module handles the source, BabelChrome displays a `No viewer installed for this file type` page while keeping the stable `babelchrome://viewer/...` address.

`/internal/module-hooks` returns the enabled module hook index. It can also be filtered with:

```text
/internal/module-hooks?hook=<hook-name>
```

This is the first explicit contract for future native integrations such as context-menu contributors, settings sections, badge providers, and tab metadata providers.

`/internal/module-menu-items` returns a flat list of module-contributed menu items for a hook. It accepts an optional comma-separated context filter:

```text
/internal/module-menu-items?hook=context-menu.build&context=markdown.local-file
```

Modules can declare menu contributions in `manifest.json` through `menuItems`:

```json
{
  "menuItems": [
    {
      "id": "markdown.open-source-file",
      "label": "Open Source File",
      "hook": "context-menu.build",
      "route": "babelchrome://markdown/action/open-source-file",
      "contexts": ["markdown.local-file"],
      "shortcut": "Cmd+Option+M"
    }
  ]
}
```

Modules can declare file types that should be visible to HTTP pages through the optional `file-type-handler` block:

```json
{
  "file-type-handler": {
    "fileTypes": ["md", "markdown", "mmd", "mermaid"]
  }
}
```

This is separate from `fileTypes`, which is still used by BabelChrome's viewer router to decide whether a URL or file should be opened by a viewer module.

The Markdown and OpenAPI modules declare source-file menu items for future native context-menu wiring when installed. The PHP Modules page also displays declared menu items for debugging module manifests.

The native Settings page links to the internal PHP Modules page:

```text
babelchrome://modules
```

From `babelchrome://modules`, modules can be installed from zip packages, updated by reinstalling a zip with the same module id, disabled, enabled, and removed.
The page also displays module-declared `babelchrome://<host>` routes, file type badges, hook badges, installed versions, and a `Settings` action when the module manifest exposes a settings route.

Enabled modules that declare routes can also be opened from this page. BabelChrome opens the module through the LocalServiceHost using:

```text
/module/<module-id>/<route>
```

The native app creates the tokenized local URL internally, so module pages can use normal local HTTP navigation without exposing the token in user-facing commands.

Module-declared `babelchrome://<host>` URLs are also resolved natively. For example, the demo module declares `scheme=babelchrome`, `host=demo`, and `handler=index`, so it can be opened with:

```bash
open -a BabelChrome "babelchrome://demo"
```

The original URL is forwarded to the module route as `sourceUrl`.

Enabled modules can also declare application lifecycle hooks. BabelChrome currently dispatches:

- `app.did-start` after the native window and restored tabs have been rebuilt;
- `app.will-quit` before the LocalServiceHost PHP process is stopped.

The Project Launcher module uses these hooks to snapshot running managed servers on quit, stop those servers before BabelChrome exits, and restart the same servers on the next BabelChrome launch. Restarted servers receive fresh manager-chosen ports, while user-facing stable URLs such as `babelchrome://server/<project-id>` remain unchanged.

Module route handlers receive a `ModuleRequest` object with a runtime context. The context exposes the LocalServiceHost base URL, the current access token, the original `sourceUrl`, and helper methods for generating tokenized module asset and module route URLs:

```text
ModuleRequest.context.baseUrl
ModuleRequest.context.token
ModuleRequest.context.sourceUrl
ModuleRequest.context.moduleAssetUrl(...)
ModuleRequest.context.moduleRouteUrl(...)
ModuleRequest.context.tokenizedUrl(...)
```

Modules can also serve static files from their own `public/` directory through:

```text
/module/<module-id>/assets/<path>
```

The endpoint is token-protected and rejects paths that resolve outside the module `public/` directory.

Zip installation is validated before extraction:

- absolute paths are rejected;
- parent-directory traversal entries are rejected;
- backslash paths are rejected;
- symlink entries are rejected;
- the archive must contain `manifest.json` at its root or inside one top-level directory.

Future external modules can be prepared with the low-level dev2prod shipper:

```bash
php tools/ship-php-module.php <module-directory> [target.zip]
```

The shipper expects a module directory containing at least `manifest.json`, `composer.json`, `src/`, and `vendor/`. Optional public files can be shipped under `public/`. The shipper excludes development-only directories such as `tests`, `var`, `ai`, `.git`, `build`, `coverage`, and `node_modules`.
The packaging logic is implemented by the tested `ModulePackageShipper` service, while the CLI script is only a thin command-line wrapper.

All workspace modules can be packaged into the production zip directory with:

```bash
./tools/build-php-modules.sh
```

This command compiles module assets when a module exposes `bin/console`, copies each module into a temporary build directory, refreshes the production `vendor/` from its own `composer.lock` in that temporary copy, and creates the zip package. The editable module remains a dev workspace with its full dev dependencies.

From the sibling `../babel-chrome-modules` workspace, the equivalent module-oriented helper is:

```bash
./tools/dev2prod.sh
```

It accepts one module directory name or manifest id:

```bash
./tools/dev2prod.sh markdown-viewer
./tools/dev2prod.sh babelforge.openapi-viewer
```

If the BabelChrome workspace is not the sibling `../babel-chrome` directory, set:

```bash
BABEL_CHROME_WORKSPACE=/path/to/babel-chrome ./tools/dev2prod.sh
```

A minimal installable demo module is available at:

```text
../babel-chrome-modules/src/demo-module
```

It can be packaged for manual testing with:

```bash
cd ../babel-chrome-modules
./tools/dev2prod.sh demo-module
```

Then open `babelchrome://modules`, install `../babel-chrome-modules/zip/babelforge.demo-module-1.0.0.zip`, and use the module `Open` action.

BabelChrome also supports grouped openings:

```bash
open "babelchrome://open?group=Group%20n&url=http%3A%2F%2F127.0.0.1%3A8772"
```

For shell calls that should stay readable, BabelChrome also accepts this compact command format:

```bash
open -a BabelChrome "babelchrome://command/group:Group n::|::url:http://127.0.0.1:8772"
```

The `babelchrome://command/...` prefix is intentional: macOS `open -a` reliably forwards this hierarchical URL form to BabelChrome, while the opaque `babelchrome:group:...` form is not reliably delivered by LaunchServices.

When a grouped URL is opened:

- the group is created if it does not exist;
- the group is selected;
- an existing tab with the same requested URL is focused when found;
- otherwise, a new tab is created.

## Shell Helper

The helper avoids manual URL encoding:

```bash
./tools/babelchrome-open --print --group "Group n" "http://127.0.0.1:8772"
./tools/babelchrome-open --group "Group n" "http://127.0.0.1:8772"
```

The `--print` mode only prints the generated `babelchrome://open` URL.

## Groups

Groups are displayed in the left panel from top to bottom.

Supported group actions:

- select a group;
- create a group from the plus button;
- delete a group from the context menu;
- rename a group from the context menu;
- reorder groups by dragging them in the left panel;
- open URLs into a group from the command line.

The default group is named:

```text
default
```

Groups and tab metadata are persisted in:

```text
~/Library/Application Support/BabelForge/BabelChrome/groups.json
```

Known favicons are persisted by URL origin in:

```text
~/Library/Application Support/BabelForge/BabelChrome/favicons.json
```

## Left Panel

The left panel contains:

- the BabelForge placeholder;
- the groups list;
- a collapse or expand button.

When collapsed, the panel shows compact group initials:

- `Default` becomes `D`;
- `Mook` becomes `M`;
- `Default Views` becomes `DV`.

The panel keeps stable sizing and does not disappear when many tabs are opened.

## Tabs

Tabs are native AppKit controls styled like compact browser tabs. They are displayed in the transparent macOS titlebar area, beside the native window traffic lights.

Supported tab behavior:

- `Cmd+N` opens a new tab.
- `Cmd+T` opens a new tab next to the active tab.
- The plus button opens a new tab.
- `Cmd+W` closes the active tab.
- `Shift+Cmd+T` reopens recently closed tabs in last-in-first-out order.
- `Ctrl+Tab` selects the next tab.
- `Shift+Ctrl+Tab` selects the previous tab.
- The selected tab stays wider than inactive tabs.
- Inactive tabs shrink to fit the available width.
- Tabs can be reordered by dragging them in the tab bar.
- Tabs can be moved between groups by dragging a tab over a group, waiting for that group's tabs to appear, then either dropping on the group to append or dropping into the visible tab bar to choose the position.
- Tabs display the page favicon when Chromium exposes one, including restored tabs when the origin favicon is already stored.
- The tab close control uses an SVG close icon.

When the last tab is closed in a group, BabelChrome opens the configured default page:

```text
https://www.google.fr
```

## Tab Opening Strategies

BabelChrome supports configurable tab opening strategies from `babelchrome://settings`.

The original strategy opens new tabs at the end of the tab bar.

The parent-group strategy opens tabs next to the tab that created them. For example, if the tab bar contains `A, B, C, D` and tab `B` opens `E`, the result is:

```text
A, B, E, C, D
```

If `B` later opens `F`, the result is:

```text
A, B, E, F, C, D
```

If `E` opens `G`, the result is:

```text
A, B, E, G, F, C, D
```

## Address Bar

The address bar displays the selected tab URL and supports direct navigation.

Supported behavior:

- entering a URL and pressing Return navigates the active tab;
- typing in the field shows local suggestions from open tabs and recently closed tabs;
- when enabled in Settings, typing also queries Google Suggest after a short debounce;
- suggestions display a favicon when BabelChrome knows one for the suggestion URL origin, or when a Google suggestion text clearly matches a previously visited site host;
- selecting an open-tab suggestion focuses that tab;
- selecting a recently closed URL navigates the active tab to that URL;
- selecting a Google suggestion navigates the active tab to a Google search for that text;
- `Up`, `Down`, and `Return` control the suggestion panel;
- `Esc` closes suggestions and restores the selected tab URL in the address field;
- `Cmd+C` and `Cmd+V` work in the URL field;
- selecting a tab updates the URL field;
- browser navigation updates the URL field.

## Page Navigation

Supported browser navigation shortcuts:

- `Cmd+Left`: go back in the active tab when possible;
- `Cmd+Right`: go forward in the active tab when possible;
- `Cmd+R`: reload the active tab.

## Link Opening

Opening a link in a new tab is supported from page interactions.

Supported behavior:

- command-clicking a link opens it in a new tab;
- context menu entries can open links in a new tab when provided by Chromium;
- new tabs opened from a page can use the selected tab opening strategy.

## History

The history page is available at:

```text
babelchrome://history
```

It can also be opened with:

```text
Cmd+Y
```

The page currently lists:

- open tabs;
- recently closed tabs with a re-open action;
- recently closed tabs.

## Settings

The settings page is available at:

```text
babelchrome://settings
```

It can also be opened with:

```text
Cmd+,
```

Current settings include:

- tab opening strategy;
- address suggestion mode, either local only or local plus Google Suggest;
- a link to the extensions page;
- displayed paths and defaults used by BabelChrome.

## Extensions

The extensions page is available at:

```text
babelchrome://extensions
```

It supports:

- searching the Chrome Web Store;
- listing extensions installed in the BabelChrome profile;
- adding unpacked extension folders;
- removing extensions;
- disabling profile extensions;
- re-enabling disabled profile extensions.

Disable and Enable changes are applied reliably on the next BabelChrome restart. An extension already loaded by Chromium can remain active during the current session.

When an extension state change is waiting, the extensions page shows:

- `Disabled after restart`;
- `Enabled after restart`;
- a `Restart` button.

BabelChrome stores disabled extension packages outside Chromium's active profile extension directory. On startup, disabled packages are removed from `Default/Extensions` before CEF reads the profile, and enabled packages are restored there when necessary.

## Developer Tools

Developer Tools can be opened with:

```text
Cmd+Option+J
```

Developer Tools can also be opened from the page context menu.

Supported behavior:

- the Developer Tools panel can be shown inside the page area;
- the panel can be docked left, right, top, or bottom;
- the panel can be resized from the border touching the page;
- the selected dock position is persisted;
- the panel can be closed from its toolbar;
- the default tool is Console.

## Window Title

When a tab is active, the main window title follows the selected page title:

```text
BabelChrome - <page title>
```

## Pointer Feedback

Clickable native controls use a pointing hand cursor on hover.

## Navigation

Previous: [Manual Tests](03-manual-tests.md)  
Next: [PHP Modules](05-php-modules.md)  
README: [README](README.md)
