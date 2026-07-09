# Architecture

Navigation: [Previous: Installation](01-installation.md) | [README](README.md) | [Next: Manual Tests](03-manual-tests.md)

## Responsibility

BabelChrome owns only the local browser shell for BabelForge. It does not own BabelForge service hosting, task management, or project orchestration.

## Native Layers

- `main_mac.mm` creates the custom `NSApplication`, installs the delegate before CEF starts, runs a temporary AppKit event loop to collect early URL events, synchronizes profile extension packages, then initializes CEF.
- `ProfileExtensionStartupSynchronizer` applies persisted profile extension enable or disable decisions before Chromium starts, so CEF sees the expected package state at startup.
- `ApplicationDelegate` receives AppKit URL events, handles direct `kAEGetURL` Apple Events, and routes new-tab, close-tab, or quit actions to the browser window.
- `MainMenuBuilder` owns the native application menu construction and keeps menu wiring out of the delegate.
- `BrowserWindowController` owns the split view, groups list, address bar, tab strip layout, browser lifecycle orchestration, and high-level tab commands.
- `BrowserModels` contains the native tab, group, and closed-tab state objects shared by the window controller and browser client.
- `BrowserViews` contains the reusable AppKit controls used by the browser shell, including tab items, group items, browser host views, resize handles, and hand-cursor buttons.
- `BrowserClient` receives CEF callbacks for titles, address changes, browser creation, browser close, and load errors.
- `LocalServiceHost` starts and stops the loopback extension service used by installed modules and optional document viewers.
- `Configuration` centralizes application name and profile path.

## Profile

CEF uses this isolated profile directory:

```text
~/Library/Application Support/BabelForge/BabelChrome/Profile
```

This keeps BabelChrome state separate from personal Google Chrome profiles.

CEF is configured with persistent `cache_path` and `root_cache_path` values. BabelChrome also passes Chromium an explicit HTTP disk cache directory:

```text
~/Library/Application Support/BabelForge/BabelChrome/Profile/Default/Cache
```

The HTTP disk cache is capped at 512 MB and the media disk cache is capped at 256 MB. This improves reload speed when servers allow cache reuse. It does not preserve live JavaScript state, scroll state, in-memory page state, or an already rendered page across application restarts.

## Groups State

Native group and tab metadata is persisted separately from the CEF profile:

```text
~/Library/Application Support/BabelForge/BabelChrome/groups.json
```

The persisted state stores group IDs, group names, selected group, selected tabs, tab titles, current URLs, and requested URLs. Requested URLs are kept so repeated command openings can refocus an existing tab even after CEF redirects it.

At startup, BabelChrome restores the native session structure first: groups, tabs, selected group, selected tab, titles, and URLs. During this reconstruction it does not create CEF browser views. As soon as reconstruction is complete, the restored active tab starts its CEF browser, and adjacent preloading starts after that through the normal delayed preload path.

The main window state, left panel state, Developer Tools dock settings, tab opening strategy, unpacked extension paths, and disabled profile extension identifiers are stored in `NSUserDefaults`.

## URL Flow

1. macOS sends URLs through AppKit URL callbacks or `kAEGetURL` Apple Events.
2. `ApplicationDelegate` queues URLs until the browser window is ready.
3. `main_mac.mm` runs a temporary pre-CEF `NSApplication` event loop so rapid cold-start `open -a` calls can return before Chromium initialization begins.
4. Each startup URL event resets a short quiet timer; when the queue has been quiet long enough, the delegate stops the temporary AppKit loop.
5. Plain HTTP or HTTPS URLs are routed to the `default` group unless an enabled viewer module declares support for their path extension.
6. `babelchrome://open?group=...&url=...` URLs create or select the named group, then create or refocus the matching tab.
7. `babelchrome://command/group:...::|::url:...` compact command URLs provide a shell-friendly alternative for grouped openings.
8. CEF browser child views are created immediately for explicit selected tabs, while keyboard tab cycling and adjacent-tab preloading are delayed and cancellable.

## ExtensionHost And Viewers

BabelChrome can route supported document URLs through a local loopback ExtensionHost instead of sending them directly to CEF. Viewer support comes from installed and enabled modules. The fresh module contract supports `static-web`, `process-web`, and `process-runtime`; current PHP-based viewers are packaged as `process-web` modules that start their own PHP front controller. The native app itself does not bundle Markdown, OpenAPI, JSON rendering logic, or module-specific server logic.

`LocalServiceHost` is the native process manager. It starts the ExtensionHost on `127.0.0.1` with a random port and a per-process token. The ExtensionHost is a Symfony application copied into the application resources and served through PHP's built-in server. The native host passes a writable state directory under Application Support so Symfony cache, logs, source registrations, and installed module state are not written inside `/Applications/BabelChrome.app`.

This Symfony ExtensionHost is a transitional browser implementation detail, not the public module contract. New modules must not declare `php-web` or `php-class`; PHP, if needed, is a module-owned process dependency validated through readiness.

For `process-web` modules, the ExtensionHost allocates a second local port, starts the module command from the installed module directory, waits for the declared readiness URL, and proxies declared module routes to that process. This keeps the user-facing URL stable while allowing the runtime port to change on each app launch.

For `process-runtime` modules, the ExtensionHost runs a module-owned command without allocating a port. On-demand commands receive a JSON payload on stdin and can return either plain stdout or JSON stdout. Long-running process-runtime instances are stopped when the module is disabled, removed, updated, or when BabelChrome quits.

Viewer-backed tabs are represented by stable BabelChrome URLs. External integrations should prefer the generic viewer dispatcher:

```text
babelchrome://viewer/file/<encoded-local-path>
babelchrome://viewer/url/<encoded-source-url>
```

BabelChrome resolves these URLs through enabled module manifests. If no enabled module handles the source, it displays a local `No viewer installed for this file type` page while preserving the stable address.

Module-specific routes can also exist when a module declares them. The current viewer modules expose routes such as:

```text
babelchrome://markdown/file/<encoded-path>
babelchrome://markdown/url/<encoded-url>
babelchrome://openapi/file/<encoded-path>
babelchrome://openapi/url/<encoded-url>
babelchrome://json/file/<encoded-path>
babelchrome://json/url/<encoded-url>
```

Those module-specific URLs are owned by the installed modules. They remain useful for direct module pages and backward compatibility, but the generic `babelchrome://viewer/...` form is the stable integration point for other applications.

The loopback URL `http://127.0.0.1:<port>/...` is only a runtime navigation URL. It is regenerated from the stable source URL when the app starts or when the tab is opened, so a previous random port is never required after restart.

The native shell asks `LocalServiceHost` which enabled viewer module can handle a source URL through manifest capabilities instead of keeping hardcoded Markdown, OpenAPI, or JSON extension lists in Objective-C++. Matching is driven by manifest fields such as `fileTypes`, `file-type-handler.fileTypes`, and `fileNameContains`.

Example routing rules provided by the current viewer modules:

- `file://.../*.md`, `file://.../*.markdown`, `file://.../*.mmd`, and `file://.../*.mermaid` open through the Markdown viewer;
- `http://.../*.md`, `https://.../*.md`, and equivalent Markdown extensions can open through the Markdown viewer;
- `file://.../openapi.yaml`, `file://.../swagger.yaml`, and equivalent YAML, YML, or JSON OpenAPI names open through the OpenAPI viewer;
- regular JSON files open through the JSON viewer when the JSON viewer module is installed and no more specific OpenAPI viewer match applies;
- HTML files remain normal Chromium `file://` pages.

Viewer modules own their rendering implementation. The current Markdown viewer renders with `league/commonmark`, the OpenAPI viewer renders with bundled Swagger UI, and the JSON viewer renders with bundled `andypf/json-viewer`. The shared viewer header is provided by `babelforge/babel-chrome-viewer-kit`, not by the native browser.

Viewer links are resolved according to their source. Relative links from a local Markdown file are resolved from the source file directory. Relative Markdown-like links are routed back through the installed viewer when supported, while images and other local assets are served through module or ExtensionHost asset endpoints. Relative links from a remote Markdown URL are resolved from the remote URL. Absolute HTTP and HTTPS links remain normal web navigations unless their extension is explicitly routed to an enabled viewer module.

## Browser Lifecycle

The selected tab creates its CEF browser immediately after explicit user actions. This keeps direct tab clicks, new tabs, and command-opened URLs responsive. The initial restored tab is selected natively during startup, then its CEF browser is created immediately after session reconstruction.

Keyboard tab cycling uses a short cancellable debounce before creating the selected tab browser. Holding `Ctrl+Tab` or `Shift+Ctrl+Tab` can move across many native tabs without instantiating every traversed CEF browser.

After the selected tab is stable, BabelChrome preloads the adjacent tabs in the selected group. The previous neighbor is scheduled first, then the next neighbor, and the preload sequence is cancelled when selection changes. This keeps nearby tab switches fast while avoiding eager creation of every restored tab.

BabelChrome keeps at most eight live page browsers by default. The selected tab, adjacent tabs, and tabs with visible Developer Tools are protected. Older page browsers are evicted using least-recently-used order while preserving their native tab metadata, so returning to an evicted tab recreates its CEF browser.

Tab dragging is controller-tracked rather than pasteboard-based. While a tab is dragged, hovering over a group in the left panel for a short delay selects that group and reveals its tab strip. Dropping on the group appends the dragged tab to the group. Dropping into the revealed tab strip inserts it at the calculated tab position.

## Tab Layout

The window uses a transparent macOS titlebar with the native tab strip placed in the titlebar area. The application content below the titlebar is split into two root panels:

```text
Window
|__ Transparent Titlebar Area
|   |__ Native traffic lights
|   |__ Tabs Bar Panel
|       |__ Selected Group Tabs
|           |__ Tab 1
|           |__ Tab 2
|           |__ New Tab Button
|__ Split Content Area
    |__ Left Panel
    |   |__ BabelForge placeholder
    |   |__ Collapse or expand button
    |   |__ Groups List
    |       |__ Group 1
    |       |__ Group 2
    |       |__ Group 3
    |__ Right Panel
        |__ Address Bar Panel
        |   |__ URL Label
        |   |__ URL Text Field
        |__ Pages Panel
            |__ Selected Tab Page
                |__ Developer Tools Panel View, when visible
                |__ CEF Browser Host View
```

The groups list is native AppKit and is laid out from top to bottom in the left panel. Selecting a group hides every other group's tab controls and pages, then shows only that group's tabs.

The tab strip is native AppKit. Each tab is a custom `NSControl` styled as a compact Safari-like tab. Tabs are laid out directly inside the transparent titlebar area, without a visible horizontal scrollbar. Each tab reserves room for a favicon, then displays the title and a right-side close control. The selected tab keeps a normal readable width, while inactive tabs shrink to fit the available width. Close controls are hidden on narrow inactive tabs.

CEF reports favicon URL changes through `OnFaviconURLChange`. BabelChrome downloads the favicon through `CefBrowserHost::DownloadImage`, converts it to an `NSImage`, stores it on the native tab, and caches it by the current URL origin for restored tabs and address suggestions. The cache is persisted in `~/Library/Application Support/BabelForge/BabelChrome/favicons.json`.

`NSSplitViewDelegate` enforces a stable left panel width, so opening many tabs cannot push the panel out of view. Selecting tab `n` makes page `n` visible and updates the address bar with the selected tab URL.

When the left panel is collapsed, group rows render compact initials with at most two letters. The collapse state is persisted.

## Internal Pages

Internal pages are exposed through `babelchrome://` URLs:

- `babelchrome://settings`;
- `babelchrome://history`;
- `babelchrome://extensions`;
- `babelchrome://modules`.

These pages are rendered as generated HTML in normal browser tabs. They use internal navigation URLs for actions such as changing tab opening strategy, searching the Chrome Web Store, adding an unpacked extension folder, disabling an extension, enabling an extension, or removing an extension.

## Extensions

Profile extensions installed by Chromium are discovered from:

```text
~/Library/Application Support/BabelForge/BabelChrome/Profile/Default/Extensions
```

Disable and Enable actions update BabelChrome's own disabled-extension list, update the regular Chromium profile preferences, and mark the change as pending until restart. BabelChrome does not pass profile extensions through `--disable-extensions-except`, because that switch can make Chrome Web Store extension packages disappear from the profile under CEF.

BabelChrome stores disabled profile extension packages under its application support directory. Before CEF starts, disabled packages are copied to that storage and removed from `Default/Extensions`, while enabled packages are restored to `Default/Extensions` when necessary. BabelChrome also repairs the older disabled-extension implementation by moving any extension directories left under `Default/Disabled Extensions` back to `Default/Extensions` when possible.

Unpacked extensions are persisted as folder paths in `NSUserDefaults` and passed to Chromium at startup through the `--load-extension` command-line switch.

## Developer Tools

Developer Tools are opened through CEF for the selected tab. BabelChrome embeds the DevTools browser view inside a native panel attached to the selected page.

The panel supports:

- left, right, top, and bottom docking;
- persisted dock mode;
- resizing from the border touching the inspected page;
- closing from the native DevTools panel toolbar.

## User Commands

- `Cmd+N` opens a new tab with the configured default page.
- `Cmd+T` opens a new tab next to the active tab with the configured default page.
- `Cmd+W` closes the selected tab.
- `Shift+Cmd+T` reopens the most recently closed tab.
- `Ctrl+Tab` selects the next tab.
- `Shift+Ctrl+Tab` selects the previous tab.
- `Cmd+R` reloads the selected tab.
- `Cmd+Left` navigates back in the selected tab.
- `Cmd+Right` navigates forward in the selected tab.
- `Cmd+Y` opens history.
- `Cmd+,` opens settings.
- `Cmd+;` opens extensions.
- `Cmd+Option+J` opens Developer Tools.
- Entering text in the address bar navigates the selected tab.
- `Cmd+Q` requests an orderly CEF shutdown and exits the CEF message loop even if a browser close callback is delayed. When the long Cmd+Q setting is enabled, the shortcut must be held for 2 seconds before the quit request is accepted.

## Shell Helper

The helper prints or opens command URLs without requiring callers to manually percent-encode values:

```bash
./tools/babelchrome-open --print --group "Group n" "http://127.0.0.1:8772"
./tools/babelchrome-open --group "Group n" "http://127.0.0.1:8772"
```

Navigation: [Previous: Installation](01-installation.md) | [README](README.md) | [Next: Manual Tests](03-manual-tests.md)
