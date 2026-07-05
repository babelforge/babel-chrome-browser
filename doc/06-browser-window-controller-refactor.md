# Browser Window Controller Refactor

Navigation: [README](README.md) | [Previous: PHP Modules](05-php-modules.md) | [Next: Browser Source Layout](07-browser-source-layout.md)

This page documents the current `BrowserWindowController` split and the rules that keep the controller from becoming a single large implementation file again.

## Goal

`BrowserWindowController` must remain a UI orchestrator. Its responsibility is limited to:

- creating and owning the main window;
- wiring AppKit views, CEF callbacks, stores, action handlers, and services;
- coordinating tabs, groups, pages, and native browser views;
- routing user actions to focused collaborators;
- bridging AppKit and CEF events.

Business logic, persistence logic, file parsing, module update resolution, extension profile persistence, and reusable rendering logic must live in dedicated classes.

## Current Shape

The old `BrowserWindowController+*.inc.mm` fragments have been removed. The controller now delegates focused command groups to action handler classes under `src/Browser/Window/Actions`, while model, state, navigation, rendering, tabs, groups, and CEF helpers live in responsibility-specific directories under `src/Browser`.

```text
BrowserWindowController
    |__ AppKit/CEF orchestration
    |__ window, tab, group, browser-view coordination
    |__ delegates and callbacks
    |
    |__ Window/Actions
    |       |__ Address
    |       |__ Browser
    |       |__ DeveloperTools
    |       |__ DragDrop
    |       |__ Groups
    |       |__ InternalPages
    |       |__ Lifecycle
    |       |__ Navigation
    |
    |__ Focused collaborators
            |__ Address
            |__ CEF
            |__ DeveloperTools
            |__ DragDrop
            |__ Extensions
            |__ Groups
            |__ InternalPages
            |__ Modules
            |__ Navigation
            |__ State
            |__ Tabs
            |__ UI
            |__ Utilities
            |__ Window
```

The detailed source layout is documented in [Browser Source Layout](07-browser-source-layout.md).

## Action Handler Map

| Action handler directory | Responsibility |
| --- | --- |
| `Window/Actions/Address` | Selected tab address display, address field editing, browser metadata updates, status text, and omnibox suggestions. |
| `Window/Actions/Browser` | Browser attachment and common browser controls such as reload, back/forward, shortcut routing, and command validation. |
| `Window/Actions/DeveloperTools` | Developer Tools toggle, docking, visibility, layout requests, and keyboard/menu integration. |
| `Window/Actions/DragDrop` | Native local file drop bridge handling and forwarding to module-aware page tabs. |
| `Window/Actions/Groups` | Group and tab user actions, tab creation, close/reopen flows, drag-and-drop coordination, and group selection orchestration. |
| `Window/Actions/InternalPages` | Internal settings, history, extensions, module pages, and internal page navigation actions. |
| `Window/Actions/Lifecycle` | Startup, shutdown, session restore, main layout application, and persisted window/sidebar state coordination. |
| `Window/Actions/Navigation` | External URL routing, stable `babelchrome://...` runtime URL conversion, viewer routing, and runtime refresh behavior. |

Each action handler may coordinate UI side effects, but it must delegate reusable rules to lower-level collaborators.

## Extracted Collaborator Families

| Family | Responsibility |
| --- | --- |
| `Address` | Address bar display, navigation request normalization, link status display, local and Google suggestions. |
| `CEF` | CEF client, CEF browser attachment, and CEF metadata events. |
| `DeveloperTools` | Docking persistence, layout calculation, panel control, and remote debugging target resolution. |
| `DragDrop` | Local drop bridge script generation, payload construction, support resolution, session state, and diagnostics. |
| `Extensions` | Extension installation folders and Chromium profile extension state. |
| `Groups` | Group model collection, creation, selection, rename, move, and group-list UI coordination. |
| `InternalPages` | Internal page routing, data collection, HTML composition, page rendering, and internal page navigation handlers. |
| `Modules` | Module registry actions, module lifecycle dispatch, module navigation resolution, Project Launcher import, and module update checks. |
| `Navigation` | Browser navigation, command URL parsing, stable runtime URL handling, viewer source resolution, and refresh matching. |
| `State` | Browser settings, favicons, group sessions, window frame, and sidebar persistence. |
| `Tabs` | Tab models, tab creation, insertion policy, movement, selection lifecycle, live browser limits, closing, reopening, and tab UI layout helpers. |
| `UI` | Shared view classes, theme application, presentation formatting, string formatting, and pasteboard helpers. |
| `Utilities` | Small reusable helpers that do not belong to a browser domain family. |
| `Window` | Main window controller, private controller state, view construction, sidebar layout, and action handlers. |

## Rules For New Code

1. Do not add a new `.inc.mm` file.
2. Do not add a new `BrowserWindowController+...` category to avoid recreating fragment-style controller sprawl.
3. Keep `BrowserWindowController` focused on orchestration, AppKit/CEF callbacks, and collaborator wiring.
4. Put new user-command flows in a focused `Window/Actions/<Domain>` class when they need controller coordination.
5. Put reusable decisions, parsing, persistence, rendering, and calculations in the corresponding non-window collaborator family.
6. Do not add persistence format code to the controller or an action handler. Create or extend a store class under `State`.
7. Do not add large HTML generation to the controller or action handlers. Add it to an internal page renderer or a page-specific HTML builder.
8. Keep CEF/AppKit callbacks in the controller only when they coordinate UI state directly.
9. Prefer explicit dependencies through initializers or method parameters. Do not make extracted classes depend on controller ivars.
10. New Objective-C++ classes must have a matching `.h` and `.mm` pair and be added to `src/CMakeLists.txt`.
11. After each structural extraction, run `./tools/build-app.sh` and reinstall with `./tools/install-app.sh` before committing.

## Review Checklist

Before committing a controller refactor:

- `BrowserWindowController.mm` still reads as orchestration only.
- No action handler mixes unrelated domains.
- Any moved logic preserves the same startup/shutdown ordering as before.
- Internal pages still work from stable `babelchrome://...` URLs, not runtime-local URLs.
- Session restore still rebuilds window, sidebar, groups, tabs, and browsers in the intended order.
- `./tools/build-app.sh` succeeds.
- `/Applications/BabelChrome.app` is reinstalled when behavior or installed code changes.

## Navigation

- Previous: [PHP Modules](05-php-modules.md)
- Next: [Browser Source Layout](07-browser-source-layout.md)
- README: [README](README.md)
