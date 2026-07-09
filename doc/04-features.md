# Features

Navigation: [Previous: Manual Tests](03-manual-tests.md) | [README](README.md) | [Next: Modules](05-php-modules.md)

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

BabelChrome is also declared as an opener for local Markdown, Mermaid, OpenAPI, JSON, and HTML files:

```bash
open -a BabelChrome ./README.md
open -a BabelChrome ./diagram.mmd
open -a BabelChrome ./index.html
```

Supported local file extensions are `md`, `markdown`, `mdown`, `mkd`, `mmd`, `mermaid`, `yaml`, `yml`, `json`, `html`, and `htm`. HTML files open as direct `file://` tabs. Markdown, Mermaid, OpenAPI, and JSON rendering require the matching installed viewer module. If no enabled module handles the file type, BabelChrome displays a `No viewer installed for this file type` page.

Remote Markdown URLs open through the local viewer service when the Markdown viewer module is installed:

```bash
open -a BabelChrome "https://example.com/README.md"
```

Markdown rendering uses `league/commonmark` inside the optional Markdown viewer module. Viewer frontend source assets and import-map metadata live in the module source workspace, and compiled runtime assets are served from that module's own `public/` directory.

Markdown, OpenAPI, and JSON viewer modules share a common viewer header from the `babelforge/babel-chrome-viewer-kit` package. The kit provides the document title area and an `Open with` control for local files. The control lists macOS applications that declare support for the current file extension, stores the selected application as a shared BabelChrome preference for that extension, and asks BabelChrome to open the original local file with that application.

When installed, the Markdown viewer resolves Markdown links and assets according to the opened document:

- relative links to Markdown-like files are exposed as stable viewer links and opened through the local Markdown viewer;
- remote links to Markdown-like files are exposed as stable viewer links and opened through the local Markdown viewer;
- URL fragments such as `README.md#section` are preserved;
- regular non-Markdown links remain navigable as normal links;
- local relative images are served through the local viewer service;
- fenced Mermaid blocks and standalone `.mmd` or `.mermaid` files are rendered as diagrams with bundled local JavaScript;
- `h1`, `h2`, and `h3` headings are used to generate a table of contents;
- four Markdown themes are available from Settings: GitHub Light, GitHub Dark, Reader, and Compact;
- code blocks are highlighted with bundled local `highlight.js`.

Markdown viewer tabs use stable app URLs such as `babelchrome://viewer/file/<encoded-path>`, `babelchrome://viewer/url/<encoded-url>`, or module-owned `babelchrome://markdown/...` routes. BabelChrome converts those stable URLs to a temporary local service URL only when Chromium needs to load the rendered page. This avoids stale random ports after an application restart.

When a local Markdown file changes on disk, the viewer checks the source timestamp and refreshes the rendered page automatically. A manual `Cmd+R` also rebuilds the viewer URL with the current Markdown theme.

The Markdown page context menu includes source actions for local files:

- `Open Source File` opens the original Markdown file with macOS;
- `Reveal in Finder` selects the original Markdown file in Finder.

If a Markdown source cannot be loaded, BabelChrome displays a local viewer error page instead of a blank page. If a linked image cannot be loaded through the local asset endpoint, the viewer returns an inline SVG placeholder that names the missing asset.

OpenAPI-like files named with `openapi` or `swagger` and ending in `yaml`, `yml`, or `json` are routed to the OpenAPI viewer when the OpenAPI viewer module is installed:

```bash
open -a BabelChrome ./openapi.yaml
```

OpenAPI rendering uses the Swagger UI frontend bundled inside the optional OpenAPI viewer module. The local viewer accepts JSON and YAML sources, validates that they expose the usual `openapi` or `swagger`, `info`, and `paths` root fields, resolves internal and relative `$ref` documents, and shows a visible local error page when the source cannot be parsed as a usable OpenAPI specification.

OpenAPI viewer tabs use stable app URLs such as `babelchrome://viewer/file/<encoded-path>`, `babelchrome://viewer/url/<encoded-url>`, or module-owned `babelchrome://openapi/...` routes. Local OpenAPI files auto-refresh when the source timestamp changes on disk, including local files loaded through relative `$ref` values.

Example OpenAPI files are stored under:

```text
src/ExtensionHost/resources/
```

## Modules

BabelChrome includes a native module registry and installer, a native local HTTP host for `process-web` routes, and a transitional LocalServiceHost runtime for internal APIs plus runtime paths that have not yet moved fully native.

No module is bundled into BabelChrome for now. A module becomes available only after installing a production zip into the user modules directory. Markdown and OpenAPI viewers are regular modules produced by the sibling `babel-chrome` workspace, then installed like any other module.

Installed module manifests declare viewer capabilities such as supported file extensions and optional filename fragments. Modules keep their document renderers, view models, error classes, frontend assets, import map metadata, compiled public assets, process commands, and dependencies inside their own module package. Static and process-backed modules keep the files required by their declared runtime. The native manifest loader requires `runtime.type` and validates required `runtime.command` fields for `process-web` and `process-runtime` modules.

The native app asks the native module registry for the matching installed viewer module instead of duplicating Markdown, OpenAPI, or JSON rules in native code. The generic `babelchrome://viewer/...` URLs are preferred for external integrations. Module-owned stable URLs such as `babelchrome://markdown/...`, `babelchrome://openapi/...`, and `babelchrome://json/...` remain compatible when the corresponding module is installed.

The current Markdown/OpenAPI/JSON modules still reuse LocalServiceHost platform services for source loading and source registration. Viewer-specific PHP, Twig, source frontend assets, import maps, compiled public assets, and Composer vendors live in the modules and run behind the `process-web` contract.

BabelChrome supports a framework-agnostic `process-web` module contract. A PHP web module declares a module-owned HTTP process in `manifest.json`:

```json
{
  "runtime": {
    "type": "process-web",
    "command": "php",
    "args": ["-S", "127.0.0.1:{{ port }}", "-t", "public", "public/index.php"],
    "cwd": ".",
    "readyUrl": "http://127.0.0.1:{{ port }}/health",
    "timeoutMs": 10000
  }
}
```

The front controller belongs to the module. It may be plain PHP, Symfony, Laravel, or another PHP project layout. BabelChrome does not use framework-specific adapters and does not embed PHP as a module runtime. The module starts its own process, validates required executables through `readiness`, and receives BabelChrome context through headers and environment values.

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

Older `php-web`, `php-class`, `web`, and implicit-class manifests are not part of the fresh public contract and should be rebuilt as `process-web`, `process-runtime`, or `static-web`.

BabelChrome also supports `static-web` modules. A static web module declares a module-owned document root and index file, needs no PHP entrypoint or Composer vendor directory, and can use request-scoped `BABELCHROME_*` placeholders in text assets. Public CSS, JavaScript, image, and JSON files are still served from the module `public/` directory through the tokenized module asset endpoint.

When this browser repository is checked out through the `babel-chrome` meta workspace, editable BabelChrome module source packages live outside the app source tree, in the sibling workspace:

```text
../modules/
```

Production module zips are generated into:

```text
../zip/
```

The macOS app build does not copy module packages into the application bundle. Module source packages are built independently into zip files, and those zips are installed explicitly from the modules page.

The current module source packages are:

```text
../modules/json-viewer-module
../modules/markdown-viewer-module
../modules/openapi-viewer-module
../modules/project-launcher-module
../modules/demo-module
../modules/plain-php-module
../modules/laravel-module
../modules/process-runtime-demo-module
../modules/process-web-demo-module
../modules/node-process-web-demo-module
```

Shared viewer UI code lives in its own Composer package:

```text
babelforge/babel-chrome-viewer-kit
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

The transitional LocalServiceHost exposes module runtime and integration metadata through its internal API for module pages and native/runtime bridges:

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

The Markdown and OpenAPI modules declare source-file menu items for native context-menu wiring when installed. The Modules page also displays declared menu items for debugging module manifests.

The native Settings page links to the internal Modules page:

```text
babelchrome://modules
```

From `babelchrome://modules`, modules can be installed from zip packages, updated by reinstalling a zip with the same module id, disabled, enabled, and removed. These package and enabled-state mutations are native filesystem operations. BabelChrome stops native `process-web` instances directly before update, disable, or removal, then still asks LocalServiceHost to stop any transitional runtime process while the migration continues.
The page also displays module-declared `babelchrome://<host>` routes, file type badges, hook badges, installed versions, and a `Settings` action when the module manifest exposes a settings route.

For `process-web` modules, BabelChrome owns native runtime diagnostics, restart, stop, port allocation, command interpolation, environment preparation, readiness waiting, log capture, tokenized route proxying, and tokenized module `public/` asset serving. For on-demand `process-runtime` modules, BabelChrome now executes route commands natively, passes a JSON payload on stdin, decodes plain or JSON stdout, and maps the result to the tokenized module route response.

Enabled modules that declare routes can also be opened from this page. `process-web` modules are opened through the native local HTTP host using:

```text
/module/<module-id>/<route>
```

The native app creates the tokenized local URL internally. For `process-web`, it starts the module runtime if needed and proxies the request to the current module-owned process port. For on-demand `process-runtime`, it runs the route command directly and returns the command output as the HTTP response. Remaining non-native runtime paths still use LocalServiceHost during the migration.

Module-declared `babelchrome://<host>` URLs are also resolved natively. For example, the demo module declares `scheme=babelchrome`, `host=demo`, and `handler=index`, so it can be opened with:

```bash
open -a BabelChrome "babelchrome://demo"
```

The original URL is forwarded to the module route as `sourceUrl`.

Enabled modules can also declare application lifecycle hooks. BabelChrome currently dispatches:

- `app.did-start` after the native window and restored tabs have been rebuilt;
- `app.will-quit` before the ExtensionHost process is stopped.

The Project Launcher module uses these hooks to snapshot running managed servers on quit, stop those servers before BabelChrome exits, and restart the same servers on the next BabelChrome launch. Restarted servers receive fresh manager-chosen ports, while user-facing stable URLs such as `babelchrome://server/<project-id>` remain unchanged.

ExtensionHost-backed route handlers receive a `ModuleRequest` object with a runtime context. The context exposes the LocalServiceHost base URL, the current access token, the original `sourceUrl`, and helper methods for generating tokenized module asset and module route URLs:

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

Native `process-web` module requests receive equivalent context through HTTP headers, including `X-BabelChrome-Module-Id`, `X-BabelChrome-Module-Route`, `X-BabelChrome-Source-Url`, `X-BabelChrome-Local-Service-Base-Url`, `X-BabelChrome-Local-Service-Token`, `X-BabelChrome-Module-Asset-Base-Url`, `X-BabelChrome-Module-Asset-Token-Query`, and `X-BabelChrome-File-Types`. Stable values that are known before the process starts are also injected into the process environment, including `BABELCHROME_LOCAL_SERVICE_BASE_URL`, `BABELCHROME_LOCAL_SERVICE_TOKEN`, `BABELCHROME_MODULE_ASSET_BASE_URL`, `BABELCHROME_MODULE_ASSET_TOKEN_QUERY`, and `BABELCHROME_FILE_TYPES`.

Native on-demand `process-runtime` commands receive the same core context through their stdin JSON payload and process environment. The stdin payload includes the module id, module name, module version, installed module path, route, hook name when relevant, original source URL, tokenized LocalServiceHost base URL/token for transitional helper APIs, request query parameters, and current `X-BabelChrome-File-Types` value.

The native zip installer validates archives before extraction:

- absolute paths are rejected;
- parent-directory traversal entries are rejected;
- backslash paths are rejected;
- symlink entries are rejected;
- the archive must contain `manifest.json` at its root or inside one top-level directory.

External modules can be prepared with the low-level dev2prod shipper:

```bash
php tools/ship-php-module.php <module-directory> [target.zip]
```

Despite its historical filename, the shipper is runtime-aware. It expects a module directory containing `manifest.json`, then validates and packages the files needed by the declared runtime:

- PHP runtimes keep Composer production dependencies and PHP application files;
- `static-web` runtimes keep the declared static document root and public assets;
- `process-web` runtimes keep executable files and production dependencies needed to start a local HTTP process;
- `process-runtime` runtimes keep executable files and production dependencies needed by non-web commands.

The shipper excludes development-only directories such as `tests`, `ai`, `.git`, `build`, and `coverage`. Runtime-owned directories such as `var` or `node_modules` are kept only when the declared process runtime needs them.
The packaging logic is implemented by the tested `ModulePackageShipper` service, while the CLI script is only a thin command-line wrapper.

All workspace modules can be packaged into the production zip directory with:

```bash
./tools/build-php-modules.sh
```

This command compiles module assets when a module exposes `bin/console`, copies each module into a temporary build directory, refreshes the production `vendor/` from its own `composer.lock` in that temporary copy, and creates the zip package. The editable module remains a dev workspace with its full dev dependencies.

From the sibling `../babel-chrome` workspace, the equivalent module-oriented helper is:

```bash
./tools/dev2prod.sh
```

It accepts one module directory name or manifest id:

```bash
./tools/dev2prod.sh markdown-viewer-module
./tools/dev2prod.sh babelforge.openapi-viewer
```

If the BabelChrome workspace is not the sibling `../babel-chrome` directory, set:

```bash
BABEL_CHROME_WORKSPACE=/path/to/babel-chrome ./tools/dev2prod.sh
```

A minimal installable demo module is available at:

```text
../modules/demo-module
```

It can be packaged for manual testing with:

```bash
cd ../babel-chrome
./tools/dev2prod.sh demo-module
```

Then open `babelchrome://modules`, install `../zip/babelforge.demo-module-1.0.0.zip`, and use the module `Open` action.

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

Navigation: [Previous: Manual Tests](03-manual-tests.md) | [README](README.md) | [Next: Modules](05-php-modules.md)
