# Browser Source Layout

Navigation: [README](README.md) | [Previous: Browser Window Controller Refactor](06-browser-window-controller-refactor.md)

This page documents the responsibility-based source layout under `src/Browser`.

## Top Level

```text
src/Browser
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

The top-level directory names describe the primary domain responsibility. Files should not be placed directly in these top-level directories when a more precise second-level directory exists.

## Address

```text
Address
    |__ Bar
    |__ Status
    |__ Suggestions
```

- `Bar`: address field display, layout, normalization, and navigation request resolution.
- `Status`: link-hover status bar behavior.
- `Suggestions`: local omnibox suggestions, Google Suggest integration, suggestion context building, and suggestion panel control.

## CEF

```text
CEF
    |__ Attachment
    |__ Client
    |__ Events
```

- `Attachment`: native CEF browser view attachment and detachment helpers.
- `Client`: the CEF client implementation.
- `Events`: browser metadata events surfaced from CEF to the native shell.

## DeveloperTools

```text
DeveloperTools
    |__ Docking
    |__ Layout
    |__ Panel
    |__ Targeting
```

- `Docking`: docking mode policy and persisted docking preference.
- `Layout`: DevTools/page frame calculations.
- `Panel`: DevTools panel control.
- `Targeting`: remote debugging target lookup and DevTools URL resolution.

## DragDrop

```text
DragDrop
    |__ Bridge
    |__ Logging
    |__ Payload
    |__ Session
```

- `Bridge`: JavaScript bridge source injected into drop-aware tabs.
- `Logging`: local drop diagnostics.
- `Payload`: native local file drop payload validation and JSON construction.
- `Session`: pending drop state, drop coordination, and module support checks.

## Extensions

```text
Extensions
    |__ Install
    |__ Profile
```

- `Install`: unpacked extension folder selection and registration helpers.
- `Profile`: Chromium profile extension state, enable/disable/remove behavior, and restart-pending profile changes.

## Groups

```text
Groups
    |__ Creation
    |__ Management
    |__ Model
    |__ UI
```

- `Creation`: native group construction.
- `Management`: group selection, move, and model-level group operations.
- `Model`: group collection lookup and helper rules.
- `UI`: group list layout and rename prompt behavior.

## InternalPages

```text
InternalPages
    |__ Extensions
    |__ History
    |__ Modules
    |__ Navigation
    |__ Rendering
    |__ Settings
```

- `Extensions`: extensions internal page data and rendering.
- `History`: history internal page data and rendering.
- `Modules`: PHP module internal page rendering and module settings pages.
- `Navigation`: internal page action parsing and internal navigation handlers.
- `Rendering`: shared HTML shell, assets, escaping, and common rendering helpers.
- `Settings`: main app settings page rendering.

## Modules

```text
Modules
    |__ Core
    |__ Lifecycle
    |__ Navigation
    |__ Projects
    |__ Updates
```

- `Core`: module action service and registry-level operations.
- `Lifecycle`: app lifecycle hook dispatch and lifecycle response parsing.
- `Navigation`: module route resolution and module-aware UI navigation.
- `Projects`: Project Launcher JSON import helpers.
- `Updates`: available module update checks and update metadata resolution.

## Navigation

```text
Navigation
    |__ Browser
    |__ Commands
    |__ Refresh
    |__ StableURLs
    |__ Viewer
```

- `Browser`: direct browser navigation coordination.
- `Commands`: `babelchrome://command/...` and compact command URL parsing.
- `Refresh`: runtime refresh tracking and tab matching.
- `StableURLs`: stable `babelchrome://...` URL parsing and runtime URL reloading.
- `Viewer`: viewer route resolution, viewer source resolution, and source-file actions.

## State

```text
State
    |__ Favicons
    |__ Sessions
    |__ Settings
```

- `Favicons`: favicon persistence and lookup.
- `Sessions`: group session and main window/sidebar persistence.
- `Settings`: persisted app settings.

## Tabs

```text
Tabs
    |__ Closing
    |__ Creation
    |__ Lifecycle
    |__ Model
    |__ Movement
    |__ Selection
    |__ UI
```

- `Closing`: selected-tab close, recently closed tab storage, restore planning, reopen flow, and default-page fallback.
- `Creation`: new tab construction, insertion, placement policy, and requested URL resolution.
- `Lifecycle`: session restoration, live CEF browser limit, and browser eviction policy.
- `Model`: tab collection, lookup, and metadata update helpers.
- `Movement`: tab drag sessions, tab reorder, tab move, and hover scheduling.
- `Selection`: selected-tab page lifecycle and adjacent-tab preload planning.
- `UI`: tab content attachment, tab strip layout, and tab URL matching helpers.

## UI

```text
UI
    |__ Formatting
    |__ Models
    |__ Pasteboard
    |__ Theme
    |__ Views
```

- `Formatting`: user-facing string and presentation formatting.
- `Models`: shared browser model definitions.
- `Pasteboard`: copy helpers for browser/link actions.
- `Theme`: theme model and theme application.
- `Views`: shared AppKit views and lightweight UI helper classes.

## Utilities

```text
Utilities
    |__ Application
    |__ HTML
```

- `Application`: app relaunch helpers.
- `HTML`: small HTML data URL helpers.

## Window

```text
Window
    |__ Actions
    |       |__ Address
    |       |__ Browser
    |       |__ DeveloperTools
    |       |__ DragDrop
    |       |__ Groups
    |       |__ InternalPages
    |       |__ Lifecycle
    |       |__ Navigation
    |__ Controller
    |__ Layout
```

- `Actions`: UI command handlers that coordinate the controller with focused collaborators.
- `Controller`: `BrowserWindowController` and its private state declaration.
- `Layout`: main window view construction and sidebar layout calculation.

## Placement Rules

1. Put a class in the directory that owns its primary responsibility, not where it is first called.
2. If a class exists only to coordinate a user command with controller state, place it under `Window/Actions/<Domain>`.
3. If a class can be tested or reasoned about without the controller, place it outside `Window`.
4. If a class reads or writes persisted state, place it under `State` unless the persisted format is owned by an external system such as Chromium extensions.
5. If a class builds reusable internal-page HTML, place it under `InternalPages`.
6. If a class performs stable URL parsing or source routing, place it under `Navigation`.
7. Do not create new top-level `src/Browser` families unless an existing family would be misleading.
8. Do not place files directly under `src/Browser/<Family>` when a second-level responsibility directory applies.

## Build Integration

Every `.h` and `.mm` file under `src/Browser` must be listed in `src/CMakeLists.txt`.

After moving or adding files:

```bash
./tools/build-app.sh
./tools/install-app.sh
```

## Navigation

- Previous: [Browser Window Controller Refactor](06-browser-window-controller-refactor.md)
- Next: none
- README: [README](README.md)
