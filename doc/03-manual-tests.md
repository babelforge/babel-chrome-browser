# Manual Tests

## Build Validation

```bash
./tools/build-app.sh
```

Expected result:

```text
** BUILD SUCCEEDED **
```

## Install Validation

```bash
./tools/install-app.sh
```

Expected result:

```text
/Applications/BabelChrome.app
```

## URL Validation

```bash
open -a BabelChrome
```

```bash
open -a BabelChrome "http://127.0.0.1:8772"
```

```bash
open -a BabelChrome "http://127.0.0.1:8770"
open -a BabelChrome "http://127.0.0.1:8771"
open -a BabelChrome "http://127.0.0.1:8772"
open -a BabelChrome "http://127.0.0.1:8773"
```

```bash
open -a BabelChrome "https://example.com"
```

```bash
open "babelchrome://open?group=Group%20n&url=http%3A%2F%2F127.0.0.1%3A8772"
```

```bash
open -a BabelChrome "babelchrome://command/group:Group n::|::url:http://127.0.0.1:8772"
```

```bash
./tools/babelchrome-open --print --group "Group n" "http://127.0.0.1:8772"
./tools/babelchrome-open --group "Group n" "http://127.0.0.1:8772"
```

Expected result:

- BabelChrome opens as a native app.
- URLs open as tabs in the embedded Chromium area.
- Plain HTTP and HTTPS URLs open in the `default` group.
- `babelchrome://open` URLs create or select the named group.
- compact `babelchrome://command/group:...::|::url:...` URLs create or select the named group.
- HTML files opened with `open -a BabelChrome ./file.html` open as direct `file://` tabs.
- Reopening an existing URL in the same group refocuses its tab instead of duplicating it.
- Rapid cold-start URL sequences return without LaunchServices `-1712` errors.
- The left panel remains visible and shows groups from top to bottom.
- Only the selected group's tabs are visible.
- Inactive tabs shrink when many tabs are opened.
- The selected tab remains wider than inactive tabs.
- No visible horizontal tab scrollbar is shown.
- Groups can be reordered by dragging them in the left panel and keep that order after restart.
- Tabs can be reordered by dragging them in the tab bar and keep that order after restart.
- Tabs can be moved to another group by dragging over a group until that group's tab list appears, then dropping on the group to append the tab.
- Tabs can be moved to another group at a specific position by dragging over the group until its tab list appears, then dropping into the visible tab bar at the desired position.
- The profile directory is created automatically.
- Group state is saved to `~/Library/Application Support/BabelForge/BabelChrome/groups.json`.

## Viewer Module Validation

Prerequisite: install and enable the Markdown, OpenAPI, and JSON viewer modules from `babelchrome://modules`. Without those modules, BabelChrome should show `No viewer installed for this file type` for viewer-only sources.

Expected result:

- Markdown and Mermaid files opened with `open -a BabelChrome ./file.md` or `open -a BabelChrome ./diagram.mmd` open through the local Symfony viewer service and render as HTML.
- Markdown links to relative Markdown files keep using the local viewer, preserve URL fragments, and can display local relative images.
- Markdown fenced Mermaid blocks render as diagrams without requiring a CDN.
- Standalone Mermaid files opened with `open -a BabelChrome ./diagram.mmd` render as Mermaid diagrams.
- Markdown pages with at least two headings show a table of contents.
- Markdown code blocks are syntax highlighted.
- Changing the Markdown theme from `babelchrome://settings` updates already opened Markdown tabs.
- `Cmd+R` on a Markdown tab refreshes the rendered viewer page with the current theme.
- Editing a local Markdown file on disk refreshes the rendered page automatically after the viewer detects the file timestamp change.
- Right-clicking a local Markdown page shows `Open Source File` and `Reveal in Finder`.
- Opening a missing local Markdown file shows a clear local viewer error page.
- A missing linked image displays an inline missing-image placeholder instead of silently disappearing.
- Remote Markdown URLs such as `open -a BabelChrome "https://example.com/README.md"` open through the local viewer service.
- Markdown and OpenAPI viewer tabs display and persist stable `babelchrome://markdown/...` or `babelchrome://openapi/...` URLs, not stale `127.0.0.1:<port>` URLs.
- OpenAPI-like files such as `open -a BabelChrome ./openapi.yaml` open through the local OpenAPI viewer and render with bundled Swagger UI.
- Multi-file OpenAPI examples under `src/ExtensionHost/resources/openapi-ref-sample/` render with their relative `$ref` schemas resolved.
- Editing a local OpenAPI `$ref` file refreshes the rendered OpenAPI page automatically after the viewer detects the referenced file timestamp change.

## Keyboard and Address Bar Validation

1. Launch BabelChrome.
2. Press `Cmd+N`.
3. Enter `https://example.com` in the address bar.
4. Press Return.
5. Press `Cmd+T`.
6. Press `Cmd+R`.
7. Press `Cmd+Left`.
8. Press `Cmd+Right`.
9. Press `Cmd+W`.
10. Press `Shift+Cmd+T`.
11. Type part of an open tab title or URL in the address bar.
12. Use `Down`, `Up`, and Return to select a suggestion.
13. Type another value in the address bar, then press `Esc`.
14. Enable `Local + Google` address suggestions from `babelchrome://settings`.
15. Type a common search query in the address bar.
16. Press `Cmd+Q`.

Expected result:

- `Cmd+N` opens a new tab.
- `Cmd+T` opens a new tab next to the selected tab.
- `Cmd+W` closes the selected tab.
- `Shift+Cmd+T` reopens the last closed tab.
- The address bar navigates the selected tab.
- The address bar shows local suggestions from open tabs and recently closed tabs.
- Open-tab suggestions focus the matching tab.
- `Esc` closes the suggestion panel and restores the selected tab URL.
- Google suggestions appear when `Local + Google` is enabled.
- `Cmd+R` reloads the selected tab.
- `Cmd+Left` and `Cmd+Right` navigate back and forward when history exists.
- `Cmd+Q` exits BabelChrome without requiring a forced kill.

## Internal Pages Validation

Open:

```text
babelchrome://settings
babelchrome://history
babelchrome://extensions
```

Expected result:

- settings opens and shows tab opening strategy choices;
- history opens from the URL or with `Cmd+Y`;
- history lists recently closed tabs with `Re-open` buttons;
- clicking `Re-open` restores that tab and removes it from the recently closed list;
- settings opens with `Cmd+,`;
- extensions opens with `Cmd+;` and lists profile extensions and unpacked extensions.

## Extensions Validation

1. Open `babelchrome://extensions`.
2. Search the Chrome Web Store.
3. Install an extension from the store.
4. Return to `babelchrome://extensions`.
5. Click `Disable` for the installed extension.
6. Restart BabelChrome.
7. Return to `babelchrome://extensions`.
8. Click `Enable`.
9. Restart BabelChrome.

Expected result:

- installed profile extensions are listed;
- disabled extensions remain listed with `Disabled after restart` until restart;
- disabling is effective after restarting BabelChrome;
- enabling shows `Enabled after restart` until restart;
- enabling restores the extension after restarting BabelChrome;
- disabled extension packages remain listed after restart without being loaded by Chromium;
- extensions are shown as missing if an older BabelChrome version already removed the package;
- `Remove` deletes active or disabled extensions from the profile listing.

## Navigation

Previous: [Architecture](02-architecture.md)  
Next: [Features](04-features.md)
README: [README](README.md)
