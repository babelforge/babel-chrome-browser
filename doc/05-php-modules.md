# PHP Modules

Navigation: [Previous: Features](04-features.md) | [README](README.md) | [Next: Browser Window Controller Refactor](06-browser-window-controller-refactor.md)

BabelChrome modules are installable PHP packages. They live outside the application bundle after installation and are discovered from:

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

- module identity, version, description, and PHP requirement;
- runtime entrypoint;
- custom `babelchrome://` routes;
- file type handlers;
- badges;
- menu items;
- permissions;
- optional `defaultGroup` placement for module tabs;
- optional capabilities such as `file-viewer`.

When `defaultGroup` is present, BabelChrome opens or recreates that module's tab in the named group by default. The user can still move the tab afterward; closing and opening the module again reapplies the manifest preference.

A web module declares a front controller:

```json
{
  "runtime": {
    "type": "web",
    "entrypoint": "public/index.php"
  },
  "entrypoint": "public/index.php"
}
```

Framework modules that need strict Composer isolation can request process isolation:

```json
{
  "runtime": {
    "type": "web",
    "entrypoint": "public/index.php",
    "processIsolation": true
  }
}
```

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

BabelChrome exposes a small token-protected internal API from the ExtensionHost. These endpoints are intended for installed modules and native host integration, not for arbitrary remote pages.

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

The PHP Modules page shows a `Settings` button only for modules that expose this route. Settings pages should be module-owned pages; they should not be mixed into the native application settings page.

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

The production shipper keeps module runtime files, Composer dependencies, compiled public assets, templates, and manifests. It excludes development-only files such as tests, source assets, caches, and `ai/`.

Navigation: [Previous: Features](04-features.md) | [README](README.md) | [Next: Browser Window Controller Refactor](06-browser-window-controller-refactor.md)
