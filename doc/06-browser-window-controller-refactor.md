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
            |__ InternalPageRenderer
            |__ more focused collaborators as needed
```

## Fragment Map

| Fragment | Responsibility |
| --- | --- |
| `BrowserWindowController+AddressFieldEditing.inc.mm` | Address field focus, submit, text editing, Escape behavior, and address entry state. |
| `BrowserWindowController+BrowserAttachment.inc.mm` | Native CEF browser view attachment, detachment, visibility, and page container placement. |
| `BrowserWindowController+BrowserControls.inc.mm` | Toolbar and browser control actions such as reload, navigation, tab shortcuts, and command validation. |
| `BrowserWindowController+BrowserUpdatesAndFavicons.inc.mm` | CEF browser title, URL, loading, favicon, and status updates. Favicon persistence is delegated to `BabelFaviconStore`. |
| `BrowserWindowController+DeveloperToolsEmbedding.inc.mm` | Embedded DevTools creation, docking mode, resizing, closing, and keyboard/menu integration. |
| `BrowserWindowController+ExtensionActions.inc.mm` | Extension install, remove, enable, disable, restart, and page action handlers. |
| `BrowserWindowController+GroupsSession.inc.mm` | Group model mutations, group persistence, group selection, group list refresh, and group restore data. |
| `BrowserWindowController+InterfaceBuilding.inc.mm` | Main AppKit interface construction and initial view hierarchy wiring. |
| `BrowserWindowController+InternalNavigationRouter.inc.mm` | Routing for `babelchrome://settings`, `babelchrome://modules`, `babelchrome://extensions`, `babelchrome://history`, and related internal URLs. |
| `BrowserWindowController+InternalPageLoading.inc.mm` | Loading rendered internal HTML into the selected browser tab. |
| `BrowserWindowController+InternalPageOpeners.inc.mm` | Convenience methods that open built-in internal pages from menu items, buttons, or shortcuts. |
| `BrowserWindowController+InternalUtilities.inc.mm` | Shared internal-page helpers, escaping, formatting, and small HTML utilities. Candidate for extraction into renderer/view helpers. |
| `BrowserWindowController+LayoutWindowLifecycle.inc.mm` | Window lifecycle, main layout frames, sidebar layout, window persistence, and view resizing. Candidate for `WindowStateStore` plus layout helpers. |
| `BrowserWindowController+LocalDrop.inc.mm` | Native local drag-and-drop handling, drop bridge installation, and local path event forwarding to modules. |
| `BrowserWindowController+ModuleActions.inc.mm` | Module install panel, remove confirmation, action alerts, file-type refresh, and UI action coordination. Registry calls and route matching are delegated to `BabelModuleActionService`. |
| `BrowserWindowController+ModuleGroupRouting.inc.mm` | Module manifest group routing, especially default group placement for module-created tabs. |
| `BrowserWindowController+ModulePages.inc.mm` | Collects module snapshots and update data, then delegates module page body rendering to `BabelModulePageRenderer`. |
| `BrowserWindowController+ModuleUpdateActions.inc.mm` | Module update prompts, selected update installation action dispatch, and LocalServiceHost install coordination. Source preferences, source discovery, zip parsing, and zip resolution are delegated to `BabelModuleUpdateService`. |
| `BrowserWindowController+OmniboxSuggestions.inc.mm` | Address suggestion state, Google Suggest integration, local suggestion rendering, keyboard navigation, and favicon lookup. |
| `BrowserWindowController+RuntimeRefreshRouting.inc.mm` | Refresh handling for stable URLs that map to runtime-local service URLs. |
| `BrowserWindowController+SelectionAddressBar.inc.mm` | Selected tab state, address bar display value, badges, and address display formatting. |
| `BrowserWindowController+SessionLifecycle.inc.mm` | Startup/shutdown orchestration, prioritized session restore, and module lifecycle calls. |
| `BrowserWindowController+SettingsOptions.inc.mm` | App setting values, parsing, persistence, and option-specific action handling. |
| `BrowserWindowController+SettingsPages.inc.mm` | App settings HTML and module settings shell rendering. Candidate for `InternalPageRenderer`. |
| `BrowserWindowController+StableURLRouting.inc.mm` | Stable `babelchrome://...` URL conversion to runtime service URLs. |
| `BrowserWindowController+StableViewerDisplay.inc.mm` | Address bar display and badge metadata for stable viewer URLs. |
| `BrowserWindowController+SupportViews.inc.mm` | Small AppKit helper views/classes used by the window controller. Stable helpers should move into regular view classes when they grow. |
| `BrowserWindowController+TabBrowserCore.inc.mm` | Tab creation, browser creation, selected tab browser lifecycle, tab model lookup, and live browser limits. |
| `BrowserWindowController+TabDragAndClosed.inc.mm` | Tab drag-and-drop, cross-group moves, close behavior, and recently closed tabs. |
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

The controller may ask the service for update data, open source configuration prompts, install selected zip paths through `LocalServiceHost`, and render the module update page. It must not parse update manifests or inspect zip files directly.

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

The controller remains responsible for native panels, confirmation dialogs, alerts, and browser capability refresh after successful actions.

## Extraction Candidates

### `InternalPageRenderer`

Move HTML generation for internal pages into a renderer layer. Good first targets:

- settings page HTML;
- modules page HTML;
- module detail page HTML;
- module updates page HTML;
- extensions page HTML;
- history page HTML.

The controller should provide view models and receive rendered HTML. It should not concatenate large HTML strings directly.

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
