# Cross-Compiling for Windows on Linux

This guide explains how to build and test Windows executables on Linux using xwin and c3c.

## Prerequisites

- [xwin](https://github.com/Jake-Shadle/xwin) - Downloads Windows SDK and CRT for cross-compilation
- [Wine](https://www.winehq.org/) - Runs Windows executables on Linux

## Setup

### 1. Download Windows SDK with xwin

```bash
# Download and unpack the SDK
xwin download
xwin unpack

# Create the final directory structure
xwin --accept-license splat --output ~/.xwin
```

### 2. Create merged lib directory

c3c expects all `.lib` files in a single directory. The xwin splat creates them in separate subdirectories, so we need to merge them with symlinks:

```bash
mkdir -p ~/.xwin/lib
cd ~/.xwin/lib
ln -sf ../sdk/lib/um/x86_64/* .
ln -sf ../sdk/lib/ucrt/x86_64/* .
ln -sf ../crt/lib/x86_64/* .
```

### 3. Configure project.json

Add a Windows target with the `winsdk` path (must be absolute, tilde expansion doesn't work):

```json
{
    "targets": {
        "test-win": {
            "type": "executable",
            "sources": ["./test/main.c3"],
            "target": "windows-x64",
            "winsdk": "/home/YOUR_USER/.xwin/lib",
            "dependencies": []
        }
    }
}
```

## Building and Running

```bash
# Build the Windows executable
c3c build test-win

# Run with Wine
wine build/test-win.exe
```

## Troubleshooting

### Library not found errors

If you see `lld-link: error: could not open 'kernel32.lib'`:
- Verify the symlinks were created in `~/.xwin/lib/`
- Ensure the `winsdk` path in project.json is absolute (not using `~`)

### Wine errors

The error `failed to create driver ... winebth` is a harmless Bluetooth driver warning and can be ignored.

For debugging Wine issues:
```bash
WINEDEBUG=warn+all wine build/test-win.exe
```
