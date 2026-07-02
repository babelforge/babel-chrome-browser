# PHP Modules

Navigation: [README](README.md) | [Previous: Features](04-features.md)

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
../zip/babelforge.markdown-viewer-1.0.0.zip
../zip/babelforge.openapi-viewer-1.0.0.zip
../zip/babelforge.json-viewer-1.0.0.zip
../zip/babelforge.project-launcher-1.0.0.zip
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

Navigation: [README](README.md) | [Previous: Features](04-features.md)
