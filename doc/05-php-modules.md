# PHP Modules

Navigation: [README](README.md) | [Previous: Features](04-features.md)

BabelChrome modules are installable PHP packages. They live outside the application bundle after installation and are discovered from:

```text
~/Library/Application Support/BabelForge/BabelChrome/Modules
```

The editable module sources live in the sibling workspace:

```text
../babel-chrome-modules/src
```

Production module zips are generated into:

```text
../babel-chrome-modules/zip
```

## Manifest Contract

Every module has a root `manifest.json`. The host reads this manifest to discover:

- module identity, version, description, and PHP requirement;
- runtime entrypoint;
- custom `babelchrome://` routes;
- file type handlers;
- badges;
- menu items;
- permissions;
- optional capabilities such as `file-viewer`.

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

Markdown, OpenAPI, and JSON viewers use `babelforge/babelchrome-viewer-kit` for the common page header.

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

From the modules workspace:

```bash
./tools/dev2prod.sh markdown-viewer
```

From the BabelChrome workspace:

```bash
./tools/build-php-modules.sh
```

The production shipper keeps module runtime files, Composer dependencies, compiled public assets, templates, and manifests. It excludes development-only files such as tests, source assets, caches, and `ai/`.

Navigation: [README](README.md) | [Previous: Features](04-features.md)
