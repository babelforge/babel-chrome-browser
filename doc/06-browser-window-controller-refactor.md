# Browser Window Controller Refactor

Navigation: [README](README.md) | [Previous: PHP Modules](05-php-modules.md)

This page documents the current `BrowserWindowController` split, the responsibility of each included fragment, and the rules that must be followed before adding new code to the controller.

## Goal

`BrowserWindowController` must remain a UI orchestrator. Its long-term responsibility is limited to:

- creating and owning the main window;
- wiring AppKit views, CEF callbacks, stores, and services;
- coordinating tabs, groups, pages, and native browser views;
- routing user actions to focused collaborators;
- bridging AppKit and CEF events.

Business logic, persistence logic, file parsing, module update resolution, extension profile persistence, and reusable rendering logic must move into dedicated classes.

## Current Shape

The `.inc.mm` files are temporary refactor boundaries. They are still included into `BrowserWindowController.mm`, so they share the same private ivars and constants. This keeps behavior stable while the controller is decomposed into real collaborators step by step.

The intended direction is:

```text
BrowserWindowController
    |__ AppKit/CEF orchestration
    |__ window, tab, group, browser-view coordination
    |__ delegates and callbacks
    |
    |__ Services and stores
            |__ FaviconStore
            |__ WindowStateStore
            |__ ExtensionProfileStore
            |__ ModuleUpdateService
            |__ ModulePageRenderer
            |__ ModuleActionService
            |__ ModuleUIActionCoordinator
            |__ BrowserSupportViews
            |__ RecentlyClosedTabStore
            |__ InternalPageRenderer
            |__ StableViewerURLResolver
            |__ StableServerURLResolver
            |__ RuntimeRefreshCoordinator
            |__ BrowserSettingsStore
            |__ SettingsOptionRenderer
            |__ AppSettingsPageRenderer
            |__ ModuleSettingsPageRenderer
            |__ HistoryPageRenderer
            |__ ExtensionsPageRenderer
            |__ OmniboxLocalSuggestionBuilder
            |__ GoogleSuggestClient
            |__ OmniboxSuggestionsController
            |__ TabPlacementPolicy
            |__ LiveBrowserEvictionPolicy
            |__ GroupListCoordinator
            |__ GroupSessionStore
            |__ TabDragCoordinator
            |__ LocalDropBridgeScriptBuilder
            |__ LocalDropCoordinator
            |__ more focused collaborators as needed
```

## Fragment Map

| Fragment | Responsibility |
| --- | --- |
| `BrowserWindowController+AddressFieldEditing.inc.mm` | Address field focus, submit, text editing, Escape behavior, and address entry state. |
| `BrowserWindowController+BrowserAttachment.inc.mm` | Native CEF browser view attachment, detachment, visibility, and page container placement. |
| `BrowserWindowController+BrowserControls.inc.mm` | Toolbar and browser control actions such as reload, navigation, tab shortcuts, and command validation. |
| `BrowserWindowController+BrowserUpdatesAndFavicons.inc.mm` | CEF browser title, URL, loading, favicon, status updates, and browser-client capability refresh. Favicon persistence is delegated to `BabelFaviconStore`. |
| `BrowserWindowController+DeveloperToolsEmbedding.inc.mm` | Embedded DevTools creation, docking mode, resizing, closing, and keyboard/menu integration. |
| `BrowserWindowController+ExtensionActions.inc.mm` | Extension install, remove, enable, disable, restart, and page action handlers. |
| `BrowserWindowController+GroupsSession.inc.mm` | Group model mutations, group selection, group restore orchestration, and default group placement for module-created tabs. Group list layout/drop-index calculations are delegated to `BabelGroupListCoordinator`; group session file IO and JSON serialization are delegated to `BabelGroupSessionStore`. |
| `BrowserWindowController+InterfaceBuilding.inc.mm` | Main AppKit interface construction and initial view hierarchy wiring. |
| `BrowserWindowController+InternalNavigationRouter.inc.mm` | Routing for `babelchrome://settings`, `babelchrome://modules`, `babelchrome://extensions`, `babelchrome://history`, related internal URLs, and stable-server same-tab navigation requests. |
| `BrowserWindowController+InternalPageLoading.inc.mm` | Loading rendered internal HTML into the selected browser tab. |
| `BrowserWindowController+InternalPageOpeners.inc.mm` | Convenience methods that open built-in internal pages from menu items, buttons, shortcuts, or module routes. Module page methods collect snapshots/update data and delegate body rendering to `BabelModulePageRenderer`. |
| `BrowserWindowController+InternalUtilities.inc.mm` | Shared internal-page helpers, URL/path escaping, shell quoting, icon loading, restart launching, and compatibility wrappers for internal page rendering. Shared HTML shell rendering is delegated to `BabelInternalPageRenderer`. |
| `BrowserWindowController+LayoutWindowLifecycle.inc.mm` | Window lifecycle, main layout frames, sidebar layout, and view resizing. Window/sidebar persistence is delegated to `BabelWindowStateStore`. |
| `BrowserWindowController+LocalDrop.inc.mm` | Native local drag-and-drop handling, drop bridge installation, and local path event forwarding to modules. Local drop bridge JavaScript source generation is delegated to `BabelLocalDropBridgeScriptBuilder`; pending local-drop expiry state is delegated to `BabelLocalDropCoordinator`. |
| `BrowserWindowController+OmniboxSuggestions.inc.mm` | Address suggestion orchestration, Google Suggest debounce/generation, favicon lookup, and selected suggestion actions. Local suggestion matching/deduplication is delegated to `BabelOmniboxLocalSuggestionBuilder`; Google Suggest HTTP/cache/parsing is delegated to `BabelGoogleSuggestClient`; suggestion list state and AppKit row rendering are delegated to `BabelOmniboxSuggestionsController`. |
| `BrowserWindowController+RuntimeRefreshRouting.inc.mm` | Refresh handling for stable URLs that map to runtime-local service URLs. Stable server identifier parsing is delegated to `BabelStableServerURLResolver`; pending runtime refresh state is delegated to `BabelRuntimeRefreshCoordinator`. |
| `BrowserWindowController+SelectionAddressBar.inc.mm` | Selected tab state, address bar display value, badges, and address display formatting. |
| `BrowserWindowController+SessionLifecycle.inc.mm` | Startup/shutdown orchestration, prioritized session restore, and module lifecycle calls. |
| `BrowserWindowController+SettingsOptions.inc.mm` | Compatibility wrappers for app settings option HTML. Actual option rendering is delegated to `BabelSettingsOptionRenderer`, and settings value persistence/validation is delegated to `BabelBrowserSettingsStore`. |
| `BrowserWindowController+SettingsPages.inc.mm` | Main Settings value collection, module settings value collection, and view-model collection for History and Extensions. Main Settings rendering is delegated to `BabelAppSettingsPageRenderer`; module Settings rendering is delegated to `BabelModuleSettingsPageRenderer`; History page body rendering is delegated to `BabelHistoryPageRenderer`; Extensions page body rendering is delegated to `BabelExtensionsPageRenderer`. |
| `BrowserWindowController+StableURLRouting.inc.mm` | Stable `babelchrome://...` URL conversion to runtime service URLs. Stable server URL parsing and internal query handling are delegated to `BabelStableServerURLResolver`. |
| `BrowserWindowController+TabBrowserCore.inc.mm` | Tab creation, browser creation, selected tab browser lifecycle, tab model lookup, and live browser limit orchestration. New-tab insertion policy is delegated to `BabelTabPlacementPolicy`; live-browser LRU and eviction-state policy is delegated to `BabelLiveBrowserEvictionPolicy`. |
| `BrowserWindowController+TabDragAndClosed.inc.mm` | Tab drag-and-drop orchestration, cross-group moves, close behavior, and recently closed tab reopening orchestration. Drag hit-testing and insertion-index calculations are delegated to `BabelTabDragCoordinator`; recently closed tab stack ownership is delegated to `BabelRecentlyClosedTabStore`. |
| `BrowserWindowController+URLOpening.inc.mm` | External URL opening, command URL handling, new tab placement, and open requests from macOS or CEF. |

## Already Extracted Classes

### `BabelFaviconStore`

`BabelFaviconStore` owns favicon persistence and lookup:

- loads and saves `favicons.json`;
- computes normalized URL origin keys;
- resolves favicons for exact URL origins;
- resolves suggestion favicons by matching normalized host names.

The controller may ask for favicon lookup, but it must not recreate origin-key or JSON persistence logic.

### `BabelExtensionProfileStore`

`BabelExtensionProfileStore` owns Chromium profile extension state:

- reads and writes configured unpacked extension paths;
- discovers profile-installed extensions and localized extension names;
- reads and writes Chromium profile `Preferences` and `Secure Preferences`;
- tracks disabled profile extensions and restart-pending state in `NSUserDefaults`;
- removes profile extension packages, backups, disabled packages, and profile references;
- restores disabled extension packages moved by older BabelChrome versions.

The controller may open panels, show alerts, render extension pages, and route user actions, but it must not manipulate Chromium extension profile paths or preferences directly.

### `BabelWindowStateStore`

`BabelWindowStateStore` owns main window and sidebar persistence:

- reads and writes the collapsed sidebar state;
- reads and writes the expanded sidebar width;
- restores the main window frame on the best available screen;
- persists frame coordinates relative to the screen visible frame;
- restores zoom only when the stored frame matches the visible-frame zoom shape.

The controller may compute UI constraints such as the minimum sidebar width, but it must not serialize window frames or directly read/write window/sidebar defaults.

### `BrowserSupportViews`

`BrowserSupportViews` owns small stable AppKit helpers that used to live inside the window controller translation unit:

- `BabelMainWindow`;
- `BabelThemeRootView`;
- `BabelBadgeLabel`;
- `BabelOmniboxSuggestionRowView`;
- `BabelReloadIgnoreCacheCallback`.

The controller may instantiate these helpers, but it must not define view/helper classes in an included `.inc.mm` fragment.

### `BabelRecentlyClosedTabStore`

`BabelRecentlyClosedTabStore` owns the recently closed tab stack:

- stores closed tab snapshots in insertion order;
- exposes immutable snapshots for history and address suggestions;
- pops a closed tab by index for history links and keyboard restoration.

The controller may create `BabelClosedTab` snapshots and reopen tabs from them, but it must not own the mutable recently closed tab stack directly.

### `BabelInternalPageRenderer`

`BabelInternalPageRenderer` owns the shared HTML document shell for BabelChrome internal pages:

- renders the common internal page HTML document;
- owns the common CSS and small JavaScript conventions for internal pages;
- resolves light/dark internal page classes from the current BabelChrome theme;
- provides shared HTML escaping.

The controller may provide page body HTML for now, but it must not own the common internal-page shell, theme CSS, or escaping implementation.

### `BabelStableViewerURLResolver`

`BabelStableViewerURLResolver` owns stable viewer URL parsing and display formatting:

- detects stable `babelchrome://<viewer>/file/...` and `babelchrome://<viewer>/url/...` URLs;
- decodes file and remote source URLs;
- resolves generic `babelchrome://viewer/...` URLs through enabled viewer modules;
- extracts stable viewer fragments;
- formats decoded source URLs for the address bar;
- encodes stable viewer path segments.

The controller may use the resolver to decide navigation and address display, but it must not manually parse stable viewer URL paths.

### `BabelStableServerURLResolver`

`BabelStableServerURLResolver` owns stable Project Launcher server URL parsing:

- detects stable BabelChrome URLs and stable server URLs;
- detects internal server start requests;
- extracts internal refresh URL requests;
- removes internal start/refresh query parameters;
- extracts stable server project identifiers;
- builds stable server reload URLs from runtime-local paths.

The controller may decide when to navigate or reload actual tabs, but it must not manually parse `babelchrome://server/...` paths or internal server query parameters.

### `BabelRuntimeRefreshCoordinator`

`BabelRuntimeRefreshCoordinator` owns pending stable refresh URL state keyed by runtime CEF browser identifier:

- enqueues stable URLs that must be refreshed after a runtime action completes;
- consumes pending refresh URLs once the target browser reaches a non-module runtime URL;
- keeps the mutable pending-refresh map out of `BrowserWindowController`.

The controller may still decide which tabs to reload and when a runtime URL is eligible, but it must not store pending refresh arrays directly.

### `BabelOmniboxLocalSuggestionBuilder`

`BabelOmniboxLocalSuggestionBuilder` owns local omnibox suggestion matching:

- open tab matching;
- recently closed tab matching;
- local suggestion deduplication;
- maximum result count enforcement.

The controller may collect tab row view models, add favicons, and render AppKit rows, but it must not implement local suggestion matching loops directly.

### `BabelGoogleSuggestClient`

`BabelGoogleSuggestClient` owns Google Suggest integration:

- query URL construction;
- network request execution;
- JSON response parsing;
- result de-duplication;
- query result caching;
- Google Search URL construction.

The controller may debounce calls and reject stale generations, but it must not own Google Suggest HTTP, cache, or parsing logic.

### `BabelOmniboxSuggestionsController`

`BabelOmniboxSuggestionsController` owns omnibox suggestion UI state:

- current suggestion dictionaries;
- selected suggestion index;
- row rendering into the suggestions panel;
- highlight refresh;
- show/hide panel state.

The controller may add favicon-enriched suggestions and execute selected suggestion actions, but it must not own the mutable suggestions array or row rendering loop directly.

### `BabelTabPlacementPolicy`

`BabelTabPlacementPolicy` owns new-tab insertion rules:

- append strategy;
- after-selected strategy;
- child-cluster strategy;
- descendant detection through parent tab identifiers.

The controller may still mutate the group tab array and build lightweight identifier maps, but it must not implement tab placement strategy logic directly.

### `BabelLiveBrowserEvictionPolicy`

`BabelLiveBrowserEvictionPolicy` owns live page-browser eviction policy state:

- recently used tab identifier ordering;
- in-flight eviction tracking;
- live browser tab filtering that excludes in-flight evictions;
- least-recently-used evictable tab selection.

The controller may still decide which tabs are protected by current UI state and may still perform the CEF `CloseBrowser` call, but it must not own LRU arrays or eviction marker sets directly.

### `BabelGroupSessionStore`

`BabelGroupSessionStore` owns persisted group and tab session state:

- reading the group session JSON data;
- parsing invalid or missing state into an empty state;
- resolving persisted selected group identifiers with fallbacks;
- serializing groups and tabs into the persisted JSON shape;
- writing the state file under the configured application support path.

The controller may still create native groups, tabs, host views, and CEF browser views during restore, but it must not manually build or write the persisted JSON session file.

### `BabelGroupListCoordinator`

`BabelGroupListCoordinator` owns simple group-list presentation rules:

- resolving the accent color assigned to a group from its order;
- applying group selector row frames;
- applying collapsed/expanded group row state;
- computing drag insertion index from a group-list Y coordinate.

The controller may still create group item views, wire their target/actions, mutate group order, and save state, but it must not duplicate group-list row geometry or palette indexing logic.

### `BabelTabDragCoordinator`

`BabelTabDragCoordinator` owns tab drag hit-testing and index calculations:

- resolving the group under a group-list point;
- computing tab-strip insertion index from an X coordinate;
- adjusting insertion indexes when moving an existing tab within the same list.

The controller may still track the currently dragged tab, schedule hover group selection, mutate groups/tabs, select moved tabs, and save state, but it must not duplicate drag insertion math directly.

### `BabelLocalDropBridgeScriptBuilder`

`BabelLocalDropBridgeScriptBuilder` owns the JavaScript source injected into drop-aware pages:

- optional native payload assignment;
- one-time bridge installation guard;
- local file dragover/drop event interception;
- dispatching the `babelchrome:local-drop` custom event.

The controller may still decide when a page is drop-aware and execute JavaScript through CEF, but it must not embed the full bridge script inline.

### `BabelLocalDropCoordinator`

`BabelLocalDropCoordinator` owns pending native local-drop state:

- marking browser identifiers that have just received a local file drag;
- expiring stale pending drop markers;
- clearing markers after file-navigation suppression decisions.

The controller may still translate CEF browsers to identifiers and log decisions, but it must not own the pending-drop dictionary directly.

### `BabelBrowserSettingsStore`

`BabelBrowserSettingsStore` owns persisted browser-level settings and option validation:

- tab opening strategy;
- address suggestions mode;
- Markdown viewer theme;
- long Cmd+Q behavior;
- supported value validation for these settings.

The controller may route settings URLs and refresh affected UI, but it must not directly read/write these settings in `NSUserDefaults`.

### `BabelSettingsOptionRenderer`

`BabelSettingsOptionRenderer` owns reusable settings option HTML:

- tab opening strategy controls;
- address suggestions mode controls;
- application appearance controls;
- long Cmd+Q controls;
- Markdown viewer theme controls.

The controller may choose which settings blocks appear on a page, but it must not concatenate option-control HTML directly.

### `BabelAppSettingsPageRenderer`

`BabelAppSettingsPageRenderer` owns the main `babelchrome://settings` page body:

- Settings page action links;
- General settings definition list;
- composition of reusable option controls through `BabelSettingsOptionRenderer`.

The controller may collect current setting values, but it must not concatenate the main Settings page body directly.

### `BabelModuleSettingsPageRenderer`

`BabelModuleSettingsPageRenderer` owns module Settings page body rendering:

- Markdown Viewer settings body;
- generic fallback body for modules without native settings;
- navigation back to `babelchrome://modules`;
- composition of reusable module option controls through `BabelSettingsOptionRenderer`.

The controller may normalize module identifiers and collect module display names, but it must not concatenate module Settings page bodies directly.

### `BabelHistoryPageRenderer`

`BabelHistoryPageRenderer` owns History page body rendering:

- open tab rows;
- recently closed tab rows;
- recently closed tab reopen links;
- History-specific escaping.

The controller may collect tab and recently closed tab view models, but it must not concatenate the History page HTML directly.

### `BabelExtensionsPageRenderer`

`BabelExtensionsPageRenderer` owns Extensions page body rendering:

- Chrome profile extension rows;
- unpacked extension rows;
- enable, disable, restart, and remove action links;
- extension page navigation back to Settings.

The controller may collect extension view models and ask `BabelExtensionProfileStore` for status values, but it must not concatenate the Extensions page HTML directly.

### `BabelModuleUpdateService`

`BabelModuleUpdateService` owns module update source and artifact resolution:

- stores and reads the remote update URL;
- stores and reads the local update folder path;
- resolves a remote `modules-release-manifest.json` URL;
- scans a local folder for module zip files;
- caches local zip metadata by path, file modification time, and size;
- extracts module manifests from zip files;
- compares release versions;
- builds release-module lookup tables;
- resolves update zip paths from local folders or remote manifests.

The controller may ask the service for update data and render the module update page. It must not parse update manifests or inspect zip files directly.

### `BabelModulePageRenderer`

`BabelModulePageRenderer` owns module-specific internal page body rendering:

- installed modules list;
- module details page;
- module updates page;
- module action links and capability badges;
- module update checkbox form markup.

The controller still wraps these bodies with the shared internal page shell until the broader `InternalPageRenderer` extraction is done.

### `BabelModuleActionService`

`BabelModuleActionService` owns module registry actions that go through `LocalServiceHost`:

- route matching for enabled module routes;
- install or update module zip;
- enable or disable module;
- remove module.

The controller may use this service for module lookups and registry mutations. It must not call `LocalServiceHost` directly for module install, enable, disable, remove, or route matching.

### `BabelModuleUIActionCoordinator`

`BabelModuleUIActionCoordinator` owns native UI flows around module management:

- module zip selection panel;
- module removal confirmation;
- module action alert rendering;
- module update source prompts;
- selected module update installation orchestration.

The controller may refresh browser capabilities and reopen internal pages after the coordinator reports a successful module change. It must not implement native module panels or module action alert text directly.

## Extraction Candidates

### Broader Internal Page Rendering

Continue moving page-specific HTML generation into renderer classes. Good next targets:

- settings page HTML;
- modules page HTML;
- module detail page HTML;
- module updates page HTML;
- extensions page HTML;
- history page HTML.

The controller should provide view models and receive rendered HTML. It should not concatenate large page-specific HTML strings directly.

### `WindowStateStore`

Move persisted window and sidebar state into a store:

- window screen name;
- window frame relative to visible screen bounds;
- zoom state;
- sidebar collapsed state;
- expanded sidebar width;
- long quit preference may remain in general settings unless a broader settings store is added.

The controller should apply state to AppKit objects, but should not know the serialized format.

## Rules For New Code

1. Do not add a new `.inc.mm` file unless it is a temporary migration boundary for a known extraction.
2. Do not add persistence format code to the controller. Create or extend a store class.
3. Do not add large HTML string generation to the controller. Add it to an internal page renderer or a view model helper.
4. Do not let a fragment exceed roughly 500 lines. If it approaches that size, split it or extract a class.
5. Do not let a fragment mix unrelated responsibilities. A file named for modules must not also handle extensions or window layout.
6. Keep CEF/AppKit callbacks in the controller only when they coordinate UI state directly.
7. Prefer immutable view-model dictionaries or small Objective-C model objects when passing data to renderers.
8. Keep extracted classes independent from `BrowserWindowController` ivars. Inject explicit dependencies through initializers or method parameters.
9. New extracted classes must have a matching `.h` and `.mm` pair and be added to `src/CMakeLists.txt`.
10. After each extraction, run `./tools/build-app.sh` and install with `./tools/install-app.sh` before committing.

## Refactor Order

Recommended order from lowest risk to higher impact:

1. `WindowStateStore`: isolated persistence but sensitive because startup restoration order matters.
2. `InternalPageRenderer`: high payoff, but it touches many internal pages and should be done page family by page family.
3. Tab/group services: defer until the current UI orchestration is stable enough to avoid regressions.

## Review Checklist

Before committing a controller refactor:

- `BrowserWindowController.mm` still reads as orchestration only.
- No fragment grows beyond the documented soft limit without a reason.
- Any moved logic has the same startup/shutdown ordering as before.
- Internal pages still work from stable `babelchrome://...` URLs, not runtime-local URLs.
- Session restore still rebuilds window, sidebar, groups, tabs, and browsers in the intended order.
- `./tools/build-app.sh` succeeds.
- `/Applications/BabelChrome.app` is reinstalled when behavior changes.

## Navigation

Previous: [PHP Modules](05-php-modules.md)  
Next: none  
README: [README](README.md)
