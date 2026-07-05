# Installation

Navigation: [README](README.md) | [Next: Architecture](02-architecture.md)

## Requirements

- macOS on x86_64.
- Xcode command-line tools.
- CMake.
- Network access for the first CEF download.

## Build

```bash
./tools/build-app.sh
```

The build output is:

```text
build-xcode/src/Release/BabelChrome.app
```

## Install

```bash
./tools/install-app.sh
```

The installed app is:

```text
/Applications/BabelChrome.app
```

## CEF Binary

The project uses:

```text
CEF 149.0.2+ged5b3fd+chromium-149.0.7827.53 macosx64
```

Downloaded CEF files are stored under `var/` and are not committed.

Navigation: [README](README.md) | [Next: Architecture](02-architecture.md)
