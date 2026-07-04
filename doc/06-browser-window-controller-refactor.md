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
            |__ MainWindowViewFactory
            |__ ExtensionProfileStore
            |__ ModuleUpdateService
            |__ ModulePageRenderer
            |__ ModuleActionService
            |__ ModuleUIActionCoordinator
            |__ BrowserSupportViews
            |__ RecentlyClosedTabStore
            |__ HistoryPageDataSource
            |__ InternalPageRenderer
            |__ HTMLDataURLBuilder
            |__ StableViewerURLResolver
            |__ NoViewerPageRenderer
            |__ StableServerURLResolver
            |__ LocalServiceURLClassifier
            |__ ProjectLifecycleResponseParser
            |__ ProjectLauncherJSONImporter
            |__ ModuleLifecycleDispatcher
            |__ ModuleNavigationURLResolver
            |__ RuntimeRefreshCoordinator
            |__ RuntimeRefreshTabMatcher
            |__ InternalNavigationActionParser
            |__ InternalModuleNavigationHandler
            |__ InternalSettingsNavigationHandler
            |__ BrowserSettingsStore
            |__ SettingsOptionRenderer
            |__ BrowserStringFormatter
            |__ BrowserPresentationFormatter
            |__ AddressNavigationNormalizer
            |__ AddressFieldLayoutCalculator
            |__ AddressFieldNavigationResolver
            |__ InternalPageAssetProvider
            |__ InternalPageTabClassifier
            |__ ViewerSourceResolver
            |__ AddressBarDisplayResolver
            |__ SidebarLayoutCalculator
            |__ AppSettingsPageRenderer
            |__ ModuleSettingsPageRenderer
            |__ HistoryPageRenderer
            |__ ExtensionsPageRenderer
            |__ ExtensionsPageDataSource
            |__ NewTabURLResolver
            |__ OmniboxLocalSuggestionBuilder
            |__ OmniboxSuggestionContextBuilder
            |__ GoogleSuggestClient
            |__ OmniboxSuggestionsController
            |__ BrowserGroupFactory
            |__ BrowserGroupCollection
            |__ BrowserGroupMoveCoordinator
            |__ BrowserTabCollection
            |__ BrowserTabInsertionCoordinator
            |__ BrowserTabMoveCoordinator
            |__ TabPlacementPolicy
            |__ LiveBrowserEvictionPolicy
            |__ LiveBrowserLimitEnforcer
            |__ ClosedTabRestorationPlanner
            |__ GroupListCoordinator
            |__ GroupRenameController
            |__ GroupSessionStore
            |__ TabDragCoordinator
            |__ LocalDropBridgeScriptBuilder
            |__ LocalDropCoordinator
            |__ LocalDropLogWriter
            |__ LocalDropPayloadBuilder
            |__ LocalDropSupportResolver
            |__ ExtensionFolderController
            |__ TabStripLayoutCalculator
            |__ TabContentViewAttacher
            |__ BrowserTabFactory
            |__ TabURLMatcher
            |__ AdjacentTabPreloadPlanner
            |__ ChromeCommandParser
            |__ DeveloperToolsDockingPolicy
            |__ DeveloperToolsDockingStore
            |__ DeveloperToolsLayoutCalculator
            |__ more focused collaborators as needed
```

## Fragment Map

| Fragment | Responsibility |
| --- | --- |
| `BrowserWindowController+AddressAndSuggestions.inc.mm` | Selected tab address display, address field editing, CEF browser title/URL/loading/favicons/status updates, and omnibox suggestions. Address input normalization is delegated to `BabelAddressNavigationNormalizer`; displayed-vs-actual address navigation resolution is delegated to `BabelAddressFieldNavigationResolver`; address badge/text-field frame calculation is delegated to `BabelAddressFieldLayoutCalculator`; window title, compact tab title, and badge color formatting are delegated to `BabelBrowserPresentationFormatter`; address display URL and viewer badge resolution are delegated to `BabelAddressBarDisplayResolver`; favicon persistence is delegated to `BabelFaviconStore`; local suggestion row collection and suggestion favicon lookup are delegated to `BabelOmniboxSuggestionContextBuilder`; local suggestion matching is delegated to `BabelOmniboxLocalSuggestionBuilder`; Google Suggest is delegated to `BabelGoogleSuggestClient`; suggestion panel state/rendering is delegated to `BabelOmniboxSuggestionsController`. |
| `BrowserWindowController+BrowserAttachment.inc.mm` | Native CEF browser view attachment, detachment, visibility, and page container placement. |
| `BrowserWindowController+BrowserControls.inc.mm` | Toolbar and browser control actions such as reload, navigation, tab shortcuts, and command validation. Developer Tools dock-mode resolution is delegated to `BabelDeveloperToolsDockingPolicy`; internal-page tab classification is delegated to `BabelInternalPageTabClassifier`; stable viewer source-file resolution is delegated to `BabelViewerSourceResolver`. |
| `BrowserWindowController+DeveloperToolsEmbedding.inc.mm` | Embedded DevTools creation, layout application, resizing, closing, and keyboard/menu integration. Docking preference persistence is delegated to `BabelDeveloperToolsDockingStore`; page and panel frame calculation is delegated to `BabelDeveloperToolsLayoutCalculator`. |
| `BrowserWindowController+GroupsAndTabs.inc.mm` | Group model mutations, group selection, group session restore/persistence, tab insertion/browser lifecycle, tab drag-and-drop, close/reopen behavior, and live browser limit orchestration. Native group construction is delegated to `BabelBrowserGroupFactory`; group lookup, generated names, and delete-selection fallback are delegated to `BabelBrowserGroupCollection`; group rename prompts and duplicate-name alerts are delegated to `BabelGroupRenameController`; group reorder mutations are delegated to `BabelBrowserGroupMoveCoordinator`; tab lookup, containing-group lookup, tab identifier lists, and parent-tab maps are delegated to `BabelBrowserTabCollection`; strategy-based tab insertion is delegated to `BabelBrowserTabInsertionCoordinator`; existing-tab move mutations are delegated to `BabelBrowserTabMoveCoordinator`; group list layout is delegated to `BabelGroupListCoordinator`; group session IO and restored state parsing are delegated to `BabelGroupSessionStore`; native tab construction is delegated to `BabelBrowserTabFactory`; tab content view attachment is delegated to `BabelTabContentViewAttacher`; URL matching is delegated to `BabelTabURLMatcher`; adjacent preloading/protection planning is delegated to `BabelAdjacentTabPreloadPlanner`; new-tab URL pair resolution is delegated to `BabelNewTabURLResolver`; new-tab placement is delegated to `BabelTabPlacementPolicy`; tab drag geometry is delegated to `BabelTabDragCoordinator`; live browser usage tracking is delegated to `BabelLiveBrowserEvictionPolicy`; live browser limit enforcement is delegated to `BabelLiveBrowserLimitEnforcer`; recently closed tabs are delegated to `BabelRecentlyClosedTabStore`; closed-tab restoration fallback decisions are delegated to `BabelClosedTabRestorationPlanner`. |
| `BrowserWindowController+InternalPages.inc.mm` | Internal page openers, routing, HTML loading, settings/history/extensions/module page value collection, action execution, and shared internal utilities. Extensions/modules/history query parsing is delegated to `BabelInternalNavigationActionParser`; module action execution and post-action destination selection are delegated to `BabelInternalModuleNavigationHandler`; settings query mutation is delegated to `BabelInternalSettingsNavigationHandler`; body rendering is delegated to page renderers and shared HTML shell rendering is delegated to `BabelInternalPageRenderer`; history row collection is delegated to `BabelHistoryPageDataSource`; extension row collection is delegated to `BabelExtensionsPageDataSource`; unpacked extension folder selection is delegated to `BabelExtensionFolderController`; Project Launcher JSON panel import is delegated to `BabelProjectLauncherJSONImporter`; HTML data URL encoding is delegated to `BabelHTMLDataURLBuilder`; query/path/shell string formatting is delegated to `BabelBrowserStringFormatter`; reusable internal-page icon HTML is delegated to `BabelInternalPageAssetProvider`; application restart relaunch scheduling is delegated to `BabelApplicationRelauncher`. |
| `BrowserWindowController+LocalDrop.inc.mm` | Native local drag-and-drop handling, drop bridge installation, and local path event forwarding to modules. Local drop bridge JavaScript source generation is delegated to `BabelLocalDropBridgeScriptBuilder`; pending local-drop expiry state is delegated to `BabelLocalDropCoordinator`; local-drop diagnostic file writes are delegated to `BabelLocalDropLogWriter`; native drop payload validation and JSON construction are delegated to `BabelLocalDropPayloadBuilder`; module manifest/route local-drop support resolution is delegated to `BabelLocalDropSupportResolver`. |
| `BrowserWindowController+URLRouting.inc.mm` | External URL opening, command URL execution, stable `babelchrome://...` URL conversion, and refresh handling for stable runtime URLs. Command URL parsing is delegated to `BabelChromeCommandParser`; stable server parsing is delegated to `BabelStableServerURLResolver`; stable viewer parsing is delegated to `BabelStableViewerURLResolver`; stable module route URL conversion is delegated to `BabelModuleNavigationURLResolver`; missing viewer error page rendering is delegated to `BabelNoViewerPageRenderer`; LocalServiceHost runtime URL classification is delegated to `BabelLocalServiceURLClassifier`; pending runtime refresh state is delegated to `BabelRuntimeRefreshCoordinator`; tab refresh matching rules are delegated to `BabelRuntimeRefreshTabMatcher`. |
| `BrowserWindowController+WindowLifecycle.inc.mm` | Startup/shutdown orchestration, prioritized session restore, module lifecycle calls, main layout application, and window/sidebar view resizing. Main AppKit view construction is delegated to `BabelMainWindowViewFactory`; module lifecycle dispatch and Project Launcher restore parsing are delegated to `BabelModuleLifecycleDispatcher`; window/sidebar persistence is delegated to `BabelWindowStateStore`; sidebar/right-panel frame calculation is delegated to `BabelSidebarLayoutCalculator`; tab item frame calculation is delegated to `BabelTabStripLayoutCalculator`. |

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

### `BabelMainWindowViewFactory`

`BabelMainWindowViewFactory` owns initial construction of the main AppKit view tree:

- root theme view, split view, sidebar, and right-side panels;
- titlebar tab strip and new-tab button;
- address bar controls, viewer badge, reload button, omnibox suggestions panel;
- pages panel and link status bar;
- static target/action wiring for the created controls.

The controller owns the returned views, applies runtime layout and colors, and coordinates models/CEF browsers. It must not rebuild the main view hierarchy inline.

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

- captures closed tab snapshots from live tab/group models;
- stores closed tab snapshots in insertion order;
- exposes immutable snapshots for history and address suggestions;
- pops a closed tab by index for history links and keyboard restoration.

The controller may decide when a tab should be captured and may reopen tabs from stored snapshots, but it must not create `BabelClosedTab` snapshots or own the mutable recently closed tab stack directly.

### `BabelClosedTabRestorationPlanner`

`BabelClosedTabRestorationPlanner` owns closed-tab restoration fallback decisions:

- resolves fallback group identifiers and names;
- resolves requested URL strings;
- resolves stable runtime navigation URLs;
- chooses the restored tab title fallback.

The controller may still pop recently closed snapshots, create missing native groups, create native tab views, select the restored tab, show the window, and save state, but it must not duplicate closed-tab restoration fallback logic inline.

### `BabelInternalPageRenderer`

`BabelInternalPageRenderer` owns the shared HTML document shell for BabelChrome internal pages:

- renders the common internal page HTML document;
- owns the common CSS and small JavaScript conventions for internal pages;
- resolves light/dark internal page classes from the current BabelChrome theme;
- provides shared HTML escaping.

The controller may provide page body HTML for now, but it must not own the common internal-page shell, theme CSS, or escaping implementation.

### `BabelOmniboxSuggestionContextBuilder`

`BabelOmniboxSuggestionContextBuilder` owns omnibox suggestion context preparation:

- builds local suggestion rows from open tabs while filtering internal pages;
- builds local suggestion rows from recently closed tabs in newest-first order;
- resolves suggestion favicons from exact URL origins or normalized title matches.

The controller may decide when suggestions are displayed and which suggestion is accepted, but it must not rebuild these row dictionaries or duplicate favicon-title normalization.

### `BabelStableViewerURLResolver`

`BabelStableViewerURLResolver` owns stable viewer URL parsing and display formatting:

- detects stable `babelchrome://<viewer>/file/...` and `babelchrome://<viewer>/url/...` URLs;
- decodes file and remote source URLs;
- resolves generic `babelchrome://viewer/...` URLs through enabled viewer modules;
- extracts stable viewer fragments;
- formats decoded source URLs for the address bar;
- encodes stable viewer path segments.

The controller may use the resolver to decide navigation and address display, but it must not manually parse stable viewer URL paths.

### `BabelNoViewerPageRenderer`

`BabelNoViewerPageRenderer` owns the HTML rendered when no enabled viewer module can handle a stable viewer source.

The controller may convert the rendered HTML into a data URL for CEF navigation, but it must not keep missing-viewer HTML templates inline.

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

### `BabelInternalNavigationActionParser`

`BabelInternalNavigationActionParser` owns internal page action parsing:

- Extensions page query actions such as search, add, remove, enable, disable, and restart;
- Modules page query actions such as install zip, configure update source, check updates, install updates, enable, disable, remove, details, and open route;
- History page reopen actions;
- multi-value module update selections.

The controller may still execute actions because they can involve AppKit panels, CEF navigation, alerts, and capability refreshes, but it must not manually scan these query item sets inline.

### `BabelInternalSettingsNavigationHandler`

`BabelInternalSettingsNavigationHandler` owns internal settings mutation rules:

- main Settings query handling for tab opening strategy, address suggestions, Markdown theme, app appearance theme, and long Cmd+Q;
- module Settings query handling for Markdown Viewer theme changes;
- mutation result flags that tell the controller which UI refreshes are required.

The controller may still reload Markdown viewer tabs, reapply theme colors, relayout groups/tabs, and reopen settings pages, but it must not directly encode settings query mutation rules.

### `BabelBrowserStringFormatter`

`BabelBrowserStringFormatter` owns small string formatting helpers shared by internal page actions:

- URL query escaping;
- URL path escaping;
- POSIX shell quoting for displayed commands.

The controller may call these helpers while building internal pages or command snippets, but it must not duplicate escaping rules inline.

### `BabelBrowserPresentationFormatter`

`BabelBrowserPresentationFormatter` owns reusable browser presentation formatting:

- main window title composition;
- compact tab titles;
- hex color parsing for address badges.

The controller may decide when titles or badges need refreshing, but it must not duplicate these formatting rules inline.

### `BabelAddressNavigationNormalizer`

`BabelAddressNavigationNormalizer` owns conversion from user-entered address text into a navigable URL string:

- empty input resolves to the configured default URL;
- text with an explicit scheme is preserved;
- host-like input is upgraded to `https://`;
- free text becomes a Google search URL.

The controller may decide when to normalize address input, but it must not duplicate address interpretation rules inline.

### `BabelInternalPageAssetProvider`

`BabelInternalPageAssetProvider` owns reusable internal-page icon HTML:

- renders the trash icon used by module and extension controls;
- loads SVG resources from the application bundle;
- normalizes SVG color behavior for internal-page buttons.

The controller may ask for HTML fragments, but it must not directly read bundle SVG resources or keep inline icon templates.

### `BabelInternalPageTabClassifier`

`BabelInternalPageTabClassifier` owns recognition of tabs that display native BabelChrome internal pages.

The controller may use the classifier for command validation and menu behavior, but it must not keep ad hoc internal-page URL comparisons.

### `BabelViewerSourceResolver`

`BabelViewerSourceResolver` owns stable viewer source-file resolution for browser control actions:

- detects stable viewer tabs;
- limits resolution to file-backed viewer sources;
- returns a file URL that can be opened by external applications.

The controller may use the result to execute native Open With actions, but it must not manually parse stable viewer URLs for this purpose.

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

### `BabelNewTabURLResolver`

`BabelNewTabURLResolver` owns new-tab URL pair resolution:

- resolves supported source URLs into stable viewer URLs;
- resolves stable BabelChrome URLs into runtime navigation URLs;
- keeps the user-facing requested URL separate from the runtime navigation URL;
- rejects new-tab opens when a stable viewer URL applies but cannot be navigated.

The controller may still choose the target group, create the native tab, update the address bar, and show the window, but it must not duplicate requested/navigation URL fallback logic inline.

### `BabelTabPlacementPolicy`

`BabelTabPlacementPolicy` owns new-tab insertion rules:

- append strategy;
- after-selected strategy;
- child-cluster strategy;
- descendant detection through parent tab identifiers.

The controller may still mutate the group tab array and build lightweight identifier maps, but it must not implement tab placement strategy logic directly.

### `BabelBrowserTabInsertionCoordinator`

`BabelBrowserTabInsertionCoordinator` owns strategy-based tab insertion:

- reads current tab identifiers through `BabelBrowserTabCollection`;
- asks `BabelTabPlacementPolicy` whether to append or calculate an insertion index;
- mutates the destination group's tab array at the chosen location.

The controller may still create tab views and select the inserted tab, but it must not implement tab placement mutation rules inline.

### `BabelBrowserTabMoveCoordinator`

`BabelBrowserTabMoveCoordinator` owns existing-tab move mutations:

- moves tabs inside the same group;
- moves tabs across groups;
- adjusts same-group insertion indexes through `BabelTabDragCoordinator`;
- updates destination group selected tab identifiers after cross-group moves;
- chooses a fallback selected tab identifier when the moved tab leaves its source group.

The controller may still own drag state, hover group selection, AppKit layout refresh, browser focus, and persistence, but it must not mutate tab arrays for completed tab moves inline.

### `BabelBrowserGroupFactory`

`BabelBrowserGroupFactory` owns native browser group construction:

- creates `BabelBrowserGroup` model objects;
- creates the matching `BabelGroupItemView`;
- wires group item selection, rename, delete, drag, and drag-end actions to the controller target.

The controller may decide when a group should be inserted into the ordered group list, but it must not rebuild group item views or action wiring inline.

### `BabelBrowserGroupCollection`

`BabelBrowserGroupCollection` owns pure ordered group collection helpers:

- group lookup by identifier;
- group lookup by display name;
- next generated manual group name;
- fallback group selection after deleting a group.

The controller may still mutate the group array and persist state, but it must not duplicate these lookup and naming loops inline.

### `BabelBrowserGroupMoveCoordinator`

`BabelBrowserGroupMoveCoordinator` owns ordered group move mutations:

- finds the current index for a dragged group;
- adjusts insertion indexes when the group moves forward in the same array;
- clamps the final target index to the group collection bounds;
- mutates the ordered group collection only when the order actually changes.

The controller may still own AppKit drag events, group-list coordinate conversion, layout refresh, and persistence, but it must not perform group reorder `remove`/`insert` mutations inline.

### `BabelBrowserTabCollection`

`BabelBrowserTabCollection` owns pure tab collection helpers:

- tab lookup by identifier inside one group;
- tab lookup by identifier across ordered groups;
- containing-group lookup for a tab;
- ordered tab identifier extraction;
- parent tab identifier maps used by tab placement.

The controller may still mutate tab arrays and coordinate AppKit/CEF side effects, but it must not duplicate tab collection lookup or indexing loops inline.

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
- validating persisted group/tab dictionaries into `BabelRestoredGroupState` and `BabelRestoredTabState`;
- resolving persisted selected group identifiers with fallbacks;
- serializing groups and tabs into the persisted JSON shape;
- writing the state file under the configured application support path.

The controller may still create native groups, tabs, host views, and CEF browser views during restore, but it must not manually build, validate, or write the persisted JSON session shape.

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

### `BabelBrowserTabFactory`

`BabelBrowserTabFactory` owns native tab object construction:

- tab identifiers, URL metadata, and initial title fallback;
- page container creation and local-drop callback wiring;
- embedded Developer Tools panel, toolbar, resize handle, and host view creation;
- tab item view creation, favicon lookup, and action target wiring.

The controller may decide when and where a tab is inserted, but it must not rebuild native tab view trees inline.

### `BabelTabURLMatcher`

`BabelTabURLMatcher` owns URL equivalence checks for existing tabs:

- exact current/requested URL matching;
- trailing slash normalization;
- root URL matching for the same scheme, host, and port.

The controller may use the matcher to find an existing tab, but it must not duplicate URL normalization or root matching rules.

### `BabelAdjacentTabPreloadPlanner`

`BabelAdjacentTabPreloadPlanner` owns adjacent tab preload planning:

- previous/next visible tab selection around the active tab;
- protected live browser identifier calculation for the selected tab, adjacent tabs, and tabs with visible Developer Tools.

The controller may schedule delayed browser creation and perform CEF browser eviction, but it must not keep adjacent-tab selection or protection loops inline.

### `BabelChromeCommandParser`

`BabelChromeCommandParser` owns BabelChrome command URL parsing:

- query-based `babelchrome://open?group=...&url=...` style commands;
- compact `babelchrome:group:...::|::url:...` and hierarchical command syntax;
- default group and default URL fallback resolution.

The controller may execute parsed commands by opening tabs, but it must not parse command payload separators or query items directly.

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

### `BabelDeveloperToolsDockingStore`

`BabelDeveloperToolsDockingStore` owns embedded Developer Tools docking preferences:

- restoring persisted dock mode with allowed-mode validation;
- persisting dock mode;
- restoring persisted size ratio;
- clamping and persisting size ratio.

The controller may still map toolbar button tags to dock modes and apply AppKit/CEF layout, but it must not read or write these DevTools defaults directly.

### `BabelDeveloperToolsLayoutCalculator`

`BabelDeveloperToolsLayoutCalculator` owns embedded Developer Tools frame calculation:

- splitting the page area between the inspected browser and the DevTools panel;
- calculating toolbar, resize-handle, and embedded DevTools browser frames;
- preserving the same dock-mode sizing constraints independently from AppKit view mutation.

The controller may still apply calculated frames to concrete views and maintain subview ordering, but it must not keep the DevTools sizing math inline.

### `BabelDeveloperToolsDockingPolicy`

`BabelDeveloperToolsDockingPolicy` owns embedded Developer Tools docking rules:

- mapping toolbar button tags to dock-mode values;
- exposing the allowed dock-mode set;
- identifying dock modes that resize along the vertical axis.

The controller may still react to toolbar button actions and persist the selected mode through `BabelDeveloperToolsDockingStore`, but it must not duplicate dock-mode mapping logic.

### `BabelBrowserSettingsStore`

`BabelBrowserSettingsStore` owns persisted browser-level settings and option validation:

- tab opening strategy;
- address suggestions mode;
- Markdown viewer theme;
- long Cmd+Q behavior;
- supported value validation for these settings.

The controller may route settings URLs and refresh affected UI, but it must not directly read/write these settings in `NSUserDefaults`.

### `BabelSidebarLayoutCalculator`

`BabelSidebarLayoutCalculator` owns left-panel geometry:

- minimum expanded sidebar width based on header controls and rendered title width;
- sidebar, resize-handle, and right-content frames;
- collapse/expand button, add-group button, title, and groups-list frames.

The controller may still hide/show controls, configure icons/tooltips, and place AppKit subviews, but it must not keep sidebar frame math inline.

### `BabelTabStripLayoutCalculator`

`BabelTabStripLayoutCalculator` owns tab-strip item geometry:

- active and inactive tab width selection;
- shrink-to-fit behavior when many tabs are open;
- ordered tab item frames for the current selected tab index.

The controller may still choose accent colors and assign frames to concrete tab item views, but it must not keep the tab-width algorithm inline.

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

### `BabelInternalModuleNavigationHandler`

`BabelInternalModuleNavigationHandler` owns internal Modules page action execution:

- installs selected module updates;
- installs module zip files through the module UI coordinator;
- updates module source configuration;
- enables, disables, and removes modules;
- returns a small destination result for the controller to render the correct page.

The controller may still render Modules, Module Updates, Details, or open-module destinations. It must not keep the full module-action `if` tree inline.

### `BabelAddressFieldNavigationResolver`

`BabelAddressFieldNavigationResolver` owns the pure rule that maps the address field text back to the real navigation URL:

- keeps stable viewer display text editable while preserving the underlying requested URL;
- returns the typed value unchanged when the user edited the field;
- avoids duplicating displayed-vs-actual URL comparisons in the controller.

The controller may still collect the selected tab, displayed URL, and actual URL inputs. It must not reimplement the comparison rule inline.

### `BabelExtensionFolderController`

`BabelExtensionFolderController` owns unpacked extension folder selection:

- opens the native directory picker;
- validates the selected folder contains `manifest.json`;
- shows the invalid-folder alert;
- persists valid unpacked extension paths through `BabelExtensionProfileStore`.

The controller may refresh the Extensions page after the action. It must not own unpacked extension folder picker validation inline.

### `BabelLiveBrowserLimitEnforcer`

`BabelLiveBrowserLimitEnforcer` owns the decision loop for live browser eviction:

- asks `BabelAdjacentTabPreloadPlanner` which tabs are protected;
- asks `BabelLiveBrowserEvictionPolicy` which live browsers are evictable;
- calls back into the controller only to perform the actual CEF browser close.

The controller may still own the CEF close side effect. It must not own the live-browser eviction loop.

### `BabelModuleLifecycleDispatcher`

`BabelModuleLifecycleDispatcher` owns module lifecycle hook dispatch:

- sends `app.did-start` asynchronously;
- parses restored Project Launcher server identifiers through `BabelProjectLifecycleResponseParser`;
- sends `app.will-quit` synchronously during shutdown;
- logs lifecycle failures consistently.

The controller may still reload server tabs after restored projects are reported. It must not call `LocalServiceHost` directly for lifecycle hooks.

### `BabelModuleNavigationURLResolver`

`BabelModuleNavigationURLResolver` owns stable module URL conversion:

- resolves `babelchrome://modules/<module>/<route>` URLs;
- resolves custom module route URLs through `BabelModuleActionService`;
- returns the current runtime-local module URL from `LocalServiceHost`.

The controller may still decide when a stable URL should be resolved. It must not parse stable module path components inline.

### `BabelProjectLauncherJSONImporter`

`BabelProjectLauncherJSONImporter` owns the Project Launcher JSON import picker:

- opens the native JSON file picker;
- validates the selected extension;
- shows the invalid-project alert;
- builds the Project Launcher import URL.

The controller may still choose the destination group and tab. It must not own JSON picker validation inline.

### `BabelTabContentViewAttacher`

`BabelTabContentViewAttacher` owns tab content view attachment:

- attaches the page host view to the pages panel;
- attaches the developer tools panel view to the pages panel;
- centralizes this repeated wiring for restored, new, internal, and reopened tabs.

The controller may still decide when a tab should be created or restored. It must not duplicate content view attachment calls.

## Extraction Candidates

### Internal Navigation Action Routing

`BrowserWindowController+InternalPages.inc.mm` remains large because it still owns internal URL action routing. The next clean extraction should not be another renderer. It should be an action router that can receive an internal URL, resolve the requested action, and return a small command/result object for the controller to execute.

Good boundaries:

- settings mutations;
- module management actions;
- extension management actions;
- history reopen actions;
- project launcher import actions.

The controller should keep AppKit panels and CEF navigation execution, but it should not keep the full internal URL query routing tree inline.

### Group And Tab Session Orchestration

`BrowserWindowController+GroupsAndTabs.inc.mm` still mixes group mutations, tab mutations, session restore, and browser lifecycle scheduling. Further extraction should happen by behavior:

- group CRUD and rename validation;
- tab close/reopen orchestration;
- session restore sequencing;
- browser creation/preload scheduling;
- live browser limit enforcement.

The controller should remain the owner of visible selection and AppKit/CEF side effects, but it should stop owning pure ordering and lifecycle decisions.

### Address And Suggestion Coordination

`BrowserWindowController+AddressAndSuggestions.inc.mm` still coordinates several workflows. The low-risk extractions are:

- tab metadata update application after CEF title/URL/loading callbacks;
- link-hover status bar formatting;
- favicon download result handling.

The controller should keep field delegate callbacks, but it should not accumulate unrelated CEF metadata update rules.

### Window Lifecycle UI Construction

`BrowserWindowController+WindowLifecycle.inc.mm` still builds a large amount of AppKit structure. Good next extractions:

- main window view tree factory;
- toolbar/address row factory;
- sidebar header factory;
- startup restore phase coordinator.

The controller should wire callbacks and hold references, but repeated AppKit construction details should move behind factories.

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

1. `InternalNavigationActionRouter`: reduce `InternalPages` without moving UI side effects into the service.
2. `GroupTabSessionOrchestrator`: reduce `GroupsAndTabs` by separating restore and mutation decisions from AppKit/CEF execution.
3. `MainWindowViewFactory`: reduce `WindowLifecycle` by moving AppKit construction details out of the controller.
4. `BrowserMetadataUpdateCoordinator`: reduce `AddressAndSuggestions` by separating CEF metadata application from field editing.

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
