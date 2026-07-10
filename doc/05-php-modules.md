# Modules

Navigation: [Previous: Features](04-features.md) | [README](README.md) | [Next: Browser Window Controller Refactor](06-browser-window-controller-refactor.md)

BabelChrome modules are installable extension packages. The public runtime contract is language-agnostic: `static-web` serves static files, `process-web` proxies a module-owned local HTTP process, and `process-runtime` executes module-owned non-web processes. Installed modules live outside the application bundle and are discovered from:

```text
~/Library/Application Support/BabelForge/BabelChrome/Modules
```

When this browser repository is checked out through the `babel-chrome` meta workspace, editable module sources live in:

```text
../modules
```

Production module zips are generated into the meta workspace root:

```text
../zip
```

## Install Viewer Modules

BabelChrome does not bundle Markdown, OpenAPI, JSON viewers, or the project launcher module into the `.app` bundle. Those capabilities appear only after installing the matching module zip from `babelchrome://modules`.

If production zips already exist in the meta workspace, open BabelChrome and install the required files:

```text
../zip/babelforge.markdown-viewer-<version>.zip
../zip/babelforge.openapi-viewer-<version>.zip
../zip/babelforge.json-viewer-<version>.zip
../zip/babelforge.project-launcher-<version>.zip
```

Manual install flow:

1. Open `babelchrome://modules`.
2. Click `Install Module`.
3. Select the module zip.
4. Confirm the module appears in the installed modules list.
5. Keep the module enabled.

After installing a viewer module, files declared by its `file-type-handler` block become available through:

```text
babelchrome://viewer/file/<encoded-path>
babelchrome://viewer/url/<encoded-url>
```

The enabled file types are also advertised to HTTP and HTTPS pages with:

```text
X-BabelChrome-File-Types
```

If no enabled module supports a file, BabelChrome shows a `No viewer installed for this file type` page instead of pretending the viewer exists.

## Build Module Zips From Source

From the meta workspace root:

```bash
./tools/dev2prod.sh
```

To build only one module:

```bash
./tools/dev2prod.sh markdown-viewer-module
./tools/dev2prod.sh babelforge.markdown-viewer
```

The generated archives are written to:

```text
zip/
```

The browser app build does not rebuild these zips automatically. Module packaging is intentionally separate from the native app build so browser releases and module releases can evolve independently.

## Manifest Contract

Every module has a root `manifest.json`. The host reads this manifest to discover:

- module identity, version, description, and runtime requirements;
- runtime type and process command or static document root;
- custom `babelchrome://` routes;
- file type handlers;
- badges;
- menu items;
- permissions;
- optional `defaultGroup` placement for module tabs;
- optional capabilities such as `file-viewer`.

When `defaultGroup` is present, BabelChrome opens or recreates that module's tab in the named group by default. The user can still move the tab afterward; closing and opening the module again reapplies the manifest preference.

PHP is not a browser-level runtime in the fresh module contract. A Symfony, Laravel, or plain PHP module declares `process-web`, declares its PHP executable through `requiredSettings`, and starts its own PHP front controller with `{{ settings.phpPath }}`. Older `php-web`, `php-class`, `web`, or implicit-class manifests are intentionally outside the supported contract and should be rebuilt.

A static web module can declare a static document root instead of PHP code:

```json
{
  "runtime": {
    "type": "static-web",
    "documentRoot": "public",
    "index": "index.html"
  }
}
```

`static-web` modules do not need a process command, `requirements.php`, `composer.json`, or a Composer `vendor/` directory. BabelChrome serves the declared index file through the module route, and module assets still come from the module `public/` directory through tokenized `/module/<id>/assets/...` URLs.

Static text files may use BabelChrome placeholders for request-scoped values:

```html
<script src="{{ BABELCHROME_MODULE_ASSET_BASE_URL }}/app.js{{ BABELCHROME_MODULE_ASSET_TOKEN_QUERY }}"></script>
```

A process web module declares a command that starts a local HTTP server:

```json
{
  "requiredSettings": {
    "phpPath": {
      "type": "executable",
      "label": "PHP executable",
      "binary": "php",
      "minVersion": "8.4",
      "autoDetectPaths": [
        "/opt/homebrew/opt/php@8.4/bin/php",
        "/usr/local/opt/php@8.4/bin/php",
        "/usr/local/bin/php"
      ],
      "versionArgs": ["-v"]
    }
  },
  "runtime": {
    "type": "process-web",
    "startPolicy": "lazy",
    "command": "{{ settings.phpPath }}",
    "args": ["-S", "127.0.0.1:{{ port }}", "-t", "public", "public/index.php"],
    "cwd": ".",
    "readyUrl": "http://127.0.0.1:{{ port }}/health",
    "timeoutMs": 10000,
    "stop": {
      "signal": "TERM",
      "timeoutMs": 3000
    }
  }
}
```

`process-web` modules do not need a browser-owned PHP adapter, `requirements.php`, `composer.json`, or a Composer `vendor/` directory. BabelChrome assigns a local port, starts the process on first route access, waits for `readyUrl`, then proxies declared module routes to the process. Supported placeholders in `command`, `args`, `env`, and `readyUrl` are `{{ port }}`, `{{ moduleId }}`, `{{ moduleDir }}`, and `{{ settings.<key> }}`.

`requiredSettings` are rendered by the host, not by the module. This matters when the missing dependency is needed to start the module itself. For executable settings, BabelChrome can auto-detect candidate paths, validate executable permissions, check an optional minimum version, persist a manual value per module, and expose the resolved value as both `{{ settings.<key> }}` and `BABELCHROME_SETTING_<KEY>`. If a required setting is invalid, opening the module redirects to `babelchrome://settings/<module-id>?runtimeSettings=1` instead of starting the runtime.

`runtime.startPolicy` is optional and defaults to `lazy`. A `prewarm` value asks BabelChrome to start the module process ahead of first use when possible. During session restore, the module needed by the active restored tab is started before the first browser view is created. Other enabled `prewarm` modules are then started in the background with a serial queue.

The assigned port is never a stable browser URL. Users and integrations keep opening declared `babelchrome://` routes, and the native host rebuilds the process URL after app restart. Running process-web instances are stopped when the module is disabled, removed, updated, or when BabelChrome dispatches `app.will-quit`.

The modules page shows compact status badges for enabled state, readiness, and runtime state. The module details page exposes runtime diagnostics for process modules. For `process-web`, the diagnostics include the current state, start policy, prewarm status when available, assigned port, process base URL, readiness URL, command, working directory, and captured logs. `process-web` modules also expose `Start runtime`, `Restart runtime`, and `Stop runtime` actions when those actions match the current process state. The restart action stops any running instance, starts a new process, waits for readiness, and then refreshes the details page. `process-runtime` diagnostics report the mode, state, command, working directory, and captured logs for long-running instances; on-demand runtimes are normally shown as idle because they do not keep a process alive between requests. Modules that declare readiness expose a `Check readiness` action on their details page.

A process runtime module declares a command without implying an HTTP server:

```json
{
  "runtime": {
    "type": "process-runtime",
    "mode": "on-demand",
    "command": "node",
    "args": ["worker/index.js", "{{ route }}"],
    "cwd": ".",
    "timeoutMs": 10000,
    "commands": {
      "lifecycle": {
        "command": "node",
        "args": ["worker/lifecycle.js", "{{ hook }}"]
      }
    }
  }
}
```

Supported modes are `on-demand` and `long-running`. On-demand commands receive a JSON payload on stdin with module metadata, route, hook, source URL, query values, local service base URL, and advertised file types. Plain stdout is returned as text; JSON stdout can declare `statusCode`, `contentType`, `headers`, and `body`.

`process-runtime` modules do not need a browser-owned PHP adapter, `requirements.php`, `composer.json`, or a Composer `vendor/` directory. They also do not expose a browser route unless the manifest explicitly declares one in `routes`.

## Readiness And Setup

Modules may declare a read-only readiness command after their required runtime settings are already valid:

```json
{
  "readiness": {
    "type": "command",
    "command": "./bin/babelchrome-ready",
    "timeoutMs": 5000
  }
}
```

The command runs from the module root and should return JSON. It should be used for optional health checks, not for dependencies that are required before the module process can start:

```json
{
  "ready": true,
  "status": "ready",
  "messages": []
}
```

Modules may also declare a setup command:

```json
{
  "setup": {
    "type": "command",
    "command": "./bin/babelchrome-setup",
    "timeoutMs": 600000,
    "requiresConfirmation": true
  }
}
```

Setup commands are never run automatically. They are declared so BabelChrome can expose a user-confirmed setup flow from the module details page.
When a module declares setup and its readiness state is not ready, the module details page shows a `Run Setup` action. BabelChrome asks for confirmation, runs the command from the installed module root, captures stdout and stderr, and refreshes readiness after the command exits.

The command should prefer JSON stdout:

```json
{
  "ok": true,
  "status": "completed",
  "messages": ["Setup completed"]
}
```

If the command writes plain text instead, BabelChrome still displays stdout, stderr, timeout state, and exit code. Setup failure is diagnostic only; it does not crash BabelChrome, remove the module, or disable the module automatically.

## Viewer Routing

Viewer modules advertise file support through `file-type-handler`. BabelChrome uses the enabled installed modules to build the `X-BabelChrome-File-Types` request header and to resolve generic viewer URLs:

```text
babelchrome://viewer/file/<encoded-path>
babelchrome://viewer/url/<encoded-url>
```

If no installed viewer can handle the source, BabelChrome shows a local error page instead of silently opening a broken document.

## Shared Viewer Header

Markdown, OpenAPI, and JSON viewers use `babelforge/babel-chrome-viewer-kit` for the common page header.

For local files, the header includes an `Open with` selector. It calls BabelChrome internal endpoints to:

- list macOS applications that can open the current extension;
- store the chosen application for that extension;
- open the original file with the selected app.

When a viewer changes the selected application, it sends an opaque message envelope to `/internal/message-relay`:

```json
{
  "supports": "file-viewer",
  "message": {
    "event": "viewer-changed",
    "extension": "md",
    "applicationId": "com.microsoft.VSCode"
  }
}
```

The host validates the envelope without interpreting the event. Compatible viewer pages then synchronize their own controls.

## Host Integration APIs

BabelChrome exposes a small token-protected internal API from the native local HTTP host and the remaining transitional ExtensionHost. These endpoints are intended for installed modules and native host integration, not for arbitrary remote pages.

Installed module metadata:

```text
GET /internal/modules
GET /internal/file-types
GET /internal/module-hooks
GET /internal/module-menu-items
GET /internal/address-badge
GET /internal/viewer-route
```

Viewer and local file integration:

```text
GET  /internal/open-with/list/<extension>
POST /internal/open-with/set/<extension>
POST /internal/open-with/open
POST /internal/message-relay
GET  /source-status/<source-id>
GET  /asset/<source-id>
```

Module lifecycle:

```text
GET /internal/module-lifecycle?hook=<hook-name>
```

`/internal/file-types` returns the enabled file extensions contributed by modules through `file-type-handler.fileTypes`. The native browser also injects those extensions into eligible HTTP and HTTPS requests with:

```text
X-BabelChrome-File-Types: md,markdown,mmd,mermaid,yaml,yml,json
```

This header is updated when modules are installed, removed, enabled, or disabled. Web applications can combine this header with the `BabelChrome/1.0` User-Agent marker to emit `babelchrome://viewer/...` links only when BabelChrome can handle the target file type.

`fileTypes` and `file-type-handler.fileTypes` can differ in a manifest. `fileTypes` participates in viewer source matching, while `file-type-handler.fileTypes` defines the extensions advertised to HTTP and HTTPS pages.

## Address Badges

Modules can declare an address badge:

```json
{
  "badge": {
    "text": "JSON",
    "textColor": "#ffffff",
    "backgroundColor": "#8250df"
  }
}
```

The badge appears inside the address field for URLs handled by that module. When the module also declares a settings route, the badge context menu can expose `View Settings`.

## Settings Routes

Modules with settings should declare:

```json
{
  "settings": {
    "route": "babelchrome://settings/babelforge.markdown-viewer"
  }
}
```

The Modules page shows a `Settings` button only for modules that expose this route. Settings pages should be module-owned pages; they should not be mixed into the native application settings page.

## Hooks And Capabilities

The current host recognizes lifecycle hooks:

```text
app.did-start
app.will-quit
```

The host also exposes hook metadata for module-declared integration points such as:

```text
address.badge.resolve
context-menu.build
drop.local-paths
file.open.resolve
settings.section.register
tab.title.resolve
url.resolve
```

Capability strings in `supports` are used for generic targeting. For example, the current viewers declare:

```json
{
  "supports": ["file-viewer"]
}
```

The `/internal/message-relay` endpoint uses `supports` to broadcast an opaque message to compatible module pages. BabelChrome validates the envelope but does not interpret the inner message.

## Local Drag And Drop

Modules declaring `drop.local-paths` can receive native local paths dropped into drop-aware pages. The browser intercepts CEF file drops for eligible tabs and prevents the default file navigation. Tabs that do not opt into local drops keep normal browser behavior.

Project Launcher uses this mechanism to import a dropped folder or a dropped `babelchrome.json` file.

## Internal Page Context Menus

Internal BabelChrome pages use an explicit opt-in convention for button-like links:

```html
<a class="smallButton" data-can-open-menu="true" href="babelchrome://modules">Back to modules</a>
```

Button-like controls do not expose the custom link context menu by default. Navigation buttons opt in with `data-can-open-menu="true"`. State-changing actions such as `Remove`, `Disable`, `Enable`, `Install`, `Restart`, and update-source actions should not opt in.

This convention is currently implemented by BabelChrome's own generated internal pages. It is not automatically injected into arbitrary module pages. Modules can copy the convention or use a future shared UI helper, but the host-side safety net only suppresses known internal action URLs and BabelChrome-generated controls.

## Shipping

From the browser workspace, low-level packaging is available for a single module directory:

```bash
php tools/ship-php-module.php <module-directory> [target.zip]
```

From the browser workspace, all sibling workspace modules can be packaged with:

```bash
./tools/build-php-modules.sh
```

From the meta workspace, prefer:

```bash
./tools/dev2prod.sh
```

The production shipper keeps module runtime files, compiled public assets, templates, manifests, and Composer production dependencies when the runtime needs Composer. It excludes development-only files such as tests, source assets, caches, and `ai/`.

Navigation: [Previous: Features](04-features.md) | [README](README.md) | [Next: Browser Window Controller Refactor](06-browser-window-controller-refactor.md)
